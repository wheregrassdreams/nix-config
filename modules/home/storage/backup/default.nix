{
  config,
  hostName,
  isDarwin,
  lib,
  pkgs,
  repoLib,
  ...
}:
let
  cfg = config.my.storage.backup;
  remote = import ../remote/lib/targets.nix { inherit lib; };
  clients = import ../remote/lib/clients.nix { inherit lib pkgs; };
  classes = [
    "critical"
    "valuable"
    "rebuildable"
  ];
  datasetsFor =
    class: lib.filterAttrs (_: dataset: dataset.enable && dataset.class == class) cfg.datasets;
  pathsFor = class: lib.concatMap (dataset: dataset.paths) (builtins.attrValues (datasetsFor class));
  repositoryPathFor =
    name: repository:
    let
      target = remote.find config repository.target;
      webdav = remote.backend target "webdav";
      client = clients.restic {
        targetId = repository.target;
        inherit target hostName;
        repositoryName = name;
        inherit (repository)
          repositoryPath
          passwordFile
          environmentFile
          rcloneConfigFile
          ;
      };
    in
    { inherit target webdav; } // client;
  repositoryEnvironment = name: repository: (repositoryPathFor name repository).environment;
  configuredPolicies = lib.filterAttrs (
    class: policy: pathsFor class != [ ] && builtins.hasAttr policy.repository cfg.repositories
  ) cfg.policies;
  makeRunner = import ./lib/runner.nix {
    inherit
      hostName
      isDarwin
      lib
      pathsFor
      pkgs
      repositoryEnvironment
      repositoryPathFor
      ;
  };
  runners = lib.mapAttrs (
    class: policy: makeRunner class policy cfg.repositories.${policy.repository}
  ) configuredPolicies;
  scheduleParts = import ./lib/schedule.nix { inherit lib; };
  commands = import ./lib/commands.nix {
    inherit
      classes
      hostName
      lib
      pkgs
      repositoryEnvironment
      repositoryPathFor
      ;
    repositories = cfg.repositories;
  };
in
{
  imports =
    repoLib.importAll ./.
    ++ lib.optionals isDarwin [
      (repoLib.assertPlatform {
        package = "storage.backup";
        platforms = [ "darwin" ];
      })
    ];

  config = {
    assertions =
      lib.concatMap (class: [
        {
          assertion = datasetsFor class == { } || builtins.hasAttr class cfg.policies;
          message = "my.storage.backup.datasets using class '${class}' require my.storage.backup.policies.${class}.";
        }
      ]) classes
      ++ lib.concatMap (
        name:
        let
          repository = cfg.repositories.${name};
          target = remote.find config repository.target;
        in
        [
          {
            assertion = target != null;
            message = "my.storage.backup.repositories.${name} references missing remote target '${repository.target}'.";
          }
          {
            assertion = target != null && (target.backend.s3 != null || target.backend.webdav != null);
            message = "my.storage.backup.repositories.${name} requires an S3 or WebDAV target.";
          }
          {
            assertion = target == null || target.backend.webdav == null || repository.rcloneConfigFile != null;
            message = "my.storage.backup.repositories.${name} using WebDAV requires rcloneConfigFile.";
          }
          {
            assertion =
              repository.repositoryPath == null
              || (
                repository.repositoryPath != ""
                && !(lib.hasPrefix "/" repository.repositoryPath)
                && !(remote.hasParentSegment repository.repositoryPath)
              );
            message = "my.storage.backup.repositories.${name}.repositoryPath must be relative to its target.";
          }
        ]
      ) (builtins.attrNames cfg.repositories)
      ++ lib.concatMap (
        class:
        let
          policy = cfg.policies.${class};
        in
        [
          {
            assertion = builtins.elem class classes;
            message = "my.storage.backup.policies.${class} must be critical, valuable, or rebuildable.";
          }
          {
            assertion = builtins.hasAttr policy.repository cfg.repositories;
            message = "my.storage.backup.policies.${class} references missing repository '${policy.repository}'.";
          }
          {
            assertion = policy.retention.daily + policy.retention.weekly + policy.retention.monthly > 0;
            message = "my.storage.backup.policies.${class} must retain at least one snapshot.";
          }
        ]
      ) (builtins.attrNames cfg.policies);

    home.packages = [
      commands.backupStatus
    ]
    ++ lib.optionals (cfg.repositories != { }) (
      [
        pkgs.restic
        commands.backupInit
        commands.backupCheck
        commands.backupSnapshots
        commands.backupRestore
      ]
      ++ commands.repositoryRuntimeInputs
    );
  }
  // lib.optionalAttrs isDarwin {
    launchd.agents = lib.mapAttrs' (
      class: policy:
      let
        schedule = scheduleParts policy.schedule;
      in
      lib.nameValuePair "backup-${class}" {
        enable = true;
        config = {
          Label = "org.nix-config.backup-${class}";
          ProgramArguments = [ "${runners.${class}}/bin/backup-run-${class}" ];
          ProcessType = "Background";
          StartCalendarInterval = [ schedule.launchd ];
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/nix-config-backup-${class}.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/nix-config-backup-${class}-error.log";
        };
      }
    ) configuredPolicies;
  }
  // lib.optionalAttrs (!isDarwin) {
    systemd.user.services = lib.mapAttrs' (
      class: _:
      lib.nameValuePair "backup-${class}" {
        Unit.Description = "Nix-managed ${class} data backup";
        Service = {
          Type = "oneshot";
          ExecStart = "${runners.${class}}/bin/backup-run-${class}";
        };
      }
    ) configuredPolicies;
    systemd.user.timers = lib.mapAttrs' (
      class: policy:
      let
        schedule = scheduleParts policy.schedule;
      in
      lib.nameValuePair "backup-${class}" {
        Unit.Description = "Schedule Nix-managed ${class} data backup";
        Timer = {
          OnCalendar = schedule.systemd;
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      }
    ) configuredPolicies;
  };
}
