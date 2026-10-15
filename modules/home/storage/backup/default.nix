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
  datasetsFor = class: lib.filterAttrs (_: dataset: dataset.class == class) cfg.datasets;
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
    {
      inherit target webdav;
      inherit (client) repository environment runtimeInputs;
    };
  repositoryEnvironment =
    name: repository:
    let
      resolved = repositoryPathFor name repository;
    in
    ''
      ${resolved.environment}
    '';
  makeRunner =
    class: policy: repository:
    let
      resolved = repositoryPathFor policy.repository repository;
      retentionArgs = lib.concatStringsSep " " (
        lib.filter (value: value != "") [
          (lib.optionalString (policy.retention.daily > 0) "--keep-daily ${toString policy.retention.daily}")
          (lib.optionalString (
            policy.retention.weekly > 0
          ) "--keep-weekly ${toString policy.retention.weekly}")
          (lib.optionalString (
            policy.retention.monthly > 0
          ) "--keep-monthly ${toString policy.retention.monthly}")
        ]
      );
      paths = lib.escapeShellArgs (pathsFor class);
      initIfMissing = lib.optionalString repository.initIfMissing ''
        ensure_repository() {
          local status
          if restic cat config >/dev/null 2>&1; then
            return 0
          else
            status=$?
          fi

          if [ "$status" -ne 10 ]; then
            echo "could not check Restic repository (exit $status); refusing to initialize" >&2
            return "$status"
          fi

          if restic init; then
            return 0
          fi

          # Another scheduled/manual run may have initialized it concurrently.
          if restic cat config >/dev/null 2>&1; then
            return 0
          fi

          echo "Restic repository initialization failed" >&2
          return 1
        }
        ensure_repository
      '';
      notifyFailure =
        if isDarwin then
          ''
            if [ -x /usr/bin/osascript ]; then
              /usr/bin/osascript -e 'display notification "Backup failed; inspect the job log." with title "Nix backup"' >/dev/null 2>&1 || true
            fi
          ''
        else
          ''
            if command -v notify-send >/dev/null 2>&1; then notify-send "Nix backup" "Backup failed; inspect the user journal." || true; fi
          '';
    in
    pkgs.writeShellApplication {
      name = "backup-run-${class}";
      runtimeInputs = resolved.runtimeInputs ++ lib.optionals (!isDarwin) [ pkgs.libnotify ];
      text = ''
        notify_failure() {
          ${notifyFailure}
        }
        trap 'status=$?; notify_failure; exit "$status"' ERR
        ${repositoryEnvironment policy.repository repository}
        ${initIfMissing}
        restic backup --host ${lib.escapeShellArg hostName} --tag ${lib.escapeShellArg "class:${class}"} -- ${paths}
        restic forget ${retentionArgs} --prune
        restic check
      '';
    };
  scheduleParts =
    schedule:
    let
      timeParts = lib.splitString ":" schedule.time;
      hour = lib.toInt (builtins.elemAt timeParts 0);
      minute = lib.toInt (builtins.elemAt timeParts 1);
      weekday =
        {
          sunday = 0;
          monday = 1;
          tuesday = 2;
          wednesday = 3;
          thursday = 4;
          friday = 5;
          saturday = 6;
        }
        .${schedule.weekday};
      systemdWeekday =
        {
          sunday = "Sun";
          monday = "Mon";
          tuesday = "Tue";
          wednesday = "Wed";
          thursday = "Thu";
          friday = "Fri";
          saturday = "Sat";
        }
        .${schedule.weekday};
    in
    {
      launchd = { inherit hour minute weekday; };
      systemd =
        if schedule.kind == "daily" then
          "*-*-* ${schedule.time}:00"
        else
          "${systemdWeekday} *-*-* ${schedule.time}:00";
    };
  activePolicies = lib.filterAttrs (
    class: policy: pathsFor class != [ ] && builtins.hasAttr policy.repository cfg.repositories
  ) cfg.policies;
  runners = lib.mapAttrs (
    class: policy: makeRunner class policy cfg.repositories.${policy.repository}
  ) activePolicies;
  repositoryRuntimeInputs = lib.unique (
    lib.concatLists (
      lib.mapAttrsToList (
        name: repository: (repositoryPathFor name repository).runtimeInputs
      ) cfg.repositories
    )
  );
  checkCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: repository: ''
      ${lib.escapeShellArg name})
        ${repositoryEnvironment name repository}
        exec restic check
        ;;
    '') cfg.repositories
  );
  initCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: repository: ''
      ${lib.escapeShellArg name})
        ${repositoryEnvironment name repository}
        exec restic init
        ;;
    '') cfg.repositories
  );
  restoreCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: repository: ''
      ${lib.escapeShellArg name})
        ${repositoryEnvironment name repository}
        shift
        snapshot=latest
        if [ "$#" -gt 0 ] && [ "$1" != "--target" ]; then snapshot=$1; shift; fi
        target="''${XDG_DATA_HOME:-$HOME/.local/share}/backup-restore/${name}/$(date +%Y%m%dT%H%M%S)"
        if [ "$#" -ge 2 ] && [ "$1" = "--target" ]; then target=$2; shift 2; fi
        if [ "$#" -ne 0 ]; then echo "usage: backup-restore ${name} [snapshot] [--target PATH]" >&2; exit 2; fi
        mkdir -p -- "$target"
        restic restore "$snapshot" --target "$target"
        printf 'Restored into staging directory: %s\n' "$target"
        ;;
    '') cfg.repositories
  );
  backupCheck = pkgs.writeShellApplication {
    name = "backup-check";
    runtimeInputs = [ pkgs.restic ] ++ repositoryRuntimeInputs;
    text = ''
      repository=''${1:-}
      if [ -z "$repository" ]; then echo "usage: backup-check REPOSITORY" >&2; exit 2; fi
      case "$repository" in
        ${checkCases}
        *) echo "unknown backup repository: $repository" >&2; exit 2 ;;
      esac
    '';
  };
  backupInit = pkgs.writeShellApplication {
    name = "backup-init";
    runtimeInputs = [ pkgs.restic ] ++ repositoryRuntimeInputs;
    text = ''
      repository=''${1:-}
      if [ -z "$repository" ]; then echo "usage: backup-init REPOSITORY" >&2; exit 2; fi
      case "$repository" in
        ${initCases}
        *) echo "unknown backup repository: $repository" >&2; exit 2 ;;
      esac
    '';
  };
  backupRestore = pkgs.writeShellApplication {
    name = "backup-restore";
    runtimeInputs = [
      pkgs.restic
      pkgs.coreutils
    ]
    ++ repositoryRuntimeInputs;
    text = ''
      repository=''${1:-}
      if [ -z "$repository" ]; then echo "usage: backup-restore REPOSITORY [SNAPSHOT] [--target PATH]" >&2; exit 2; fi
      case "$repository" in
        ${restoreCases}
        *) echo "unknown backup repository: $repository" >&2; exit 2 ;;
      esac
    '';
  };
in
{
  imports = [
    ./options.nix
  ]
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
          assertion =
            !(cfg.datasets != { } && datasetsFor class != { }) || builtins.hasAttr class cfg.policies;
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

    home.packages = lib.optionals (cfg.repositories != { }) (
      [
        pkgs.restic
        backupInit
        backupCheck
        backupRestore
      ]
      ++ repositoryRuntimeInputs
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
    ) activePolicies;
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
    ) activePolicies;

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
    ) activePolicies;
  };
}
