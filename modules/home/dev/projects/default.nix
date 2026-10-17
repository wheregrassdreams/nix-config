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
  cfg = config.my.dev.projects;
  paths = config.my.paths;
  remote = import ../../storage/remote/lib/targets.nix { inherit lib; };
  clients = import ../../storage/remote/lib/clients.nix { inherit lib pkgs; };
  target =
    if cfg.snapshots.remote.target == null then
      null
    else
      remote.find config cfg.snapshots.remote.target;
  gitClient = clients.git target;
  gitTarget = if gitClient.sshHost == null then null else gitClient;
  remoteArgs =
    if gitTarget == null then
      ""
    else if target.provisioner.kind == "gitea" then
      "--remote-kind gitea --remote-ssh-host ${lib.escapeShellArg gitTarget.sshHost} --gitea-api-url ${lib.escapeShellArg target.provisioner.gitea.apiUrl} --gitea-organization ${lib.escapeShellArg target.provisioner.gitea.organization} --gitea-token-file ${lib.escapeShellArg target.provisioner.gitea.tokenFile} --host-id ${lib.escapeShellArg hostName} --project-id-overrides ${lib.escapeShellArg (builtins.toJSON cfg.snapshots.remote.projectIdOverrides)}"
    else
      "--remote-kind sshBare --remote-ssh-host ${lib.escapeShellArg gitTarget.sshHost} --remote-root ${lib.escapeShellArg gitTarget.root} --host-id ${lib.escapeShellArg hostName} --project-id-overrides ${lib.escapeShellArg (builtins.toJSON cfg.snapshots.remote.projectIdOverrides)}";
  projectTools =
    (pkgs.buildGoModule.override {
      go = pkgs.unstable.go_1_27;
    })
      {
        pname = "project-tools";
        version = "0.1.0";
        src = lib.cleanSourceWith {
          src = ./lib/project-tools;
          name = "project-tools-source";
        };
        vendorHash = "sha256-Xj1JlySW9SE406mL3nFUEYBL5A7RvDMnaIb+CNbwkeo=";
        subPackages = [ "." ];
        nativeCheckInputs = [ pkgs.git ];
        postInstall = ''
          mv $out/bin/nix-config-projects $out/bin/project-tools
        '';
      };
  projectScan = pkgs.writeShellApplication {
    name = "project-scan";
    runtimeInputs = [ pkgs.git ];
    text = ''
      exec ${projectTools}/bin/project-tools scan "$@"
    '';
  };
  projectScanNotify = pkgs.writeShellApplication {
    name = "project-scan-notify";
    runtimeInputs = [ pkgs.git ];
    text = ''
      exec ${projectTools}/bin/project-tools audit
    '';
  };
  projectSnapshot = pkgs.writeShellApplication {
    name = "project-snapshot";
    runtimeInputs = gitClient.runtimeInputs;
    text = ''
      exec ${projectTools}/bin/project-tools snapshot --snapshot-root ${lib.escapeShellArg cfg.snapshots.directory} --retention-days ${toString cfg.snapshots.retentionDays} ${remoteArgs} "$@"
    '';
  };
  launchdEnvironment = {
    NIX_CONFIG_PATH_PROJECTS = paths.personal.projects;
    PROJECTS_INACTIVE_AFTER_DAYS = toString cfg.inactiveAfterDays;
    PROJECT_SNAPSHOT_REMOTE_SSH_HOST = if gitTarget == null then "" else gitTarget.sshHost;
    PROJECT_SNAPSHOT_REMOTE_ROOT = if gitTarget == null || gitTarget.root == null then "" else gitTarget.root;
    PROJECT_SNAPSHOT_REMOTE_KIND = if gitTarget == null then "" else target.provisioner.kind;
    PROJECT_SNAPSHOT_GITEA_API_URL = if gitTarget == null || target.provisioner.kind != "gitea" then "" else target.provisioner.gitea.apiUrl;
    PROJECT_SNAPSHOT_GITEA_ORGANIZATION = if gitTarget == null || target.provisioner.kind != "gitea" then "" else target.provisioner.gitea.organization;
    PROJECT_SNAPSHOT_GITEA_TOKEN_FILE = if gitTarget == null || target.provisioner.kind != "gitea" then "" else target.provisioner.gitea.tokenFile;
    PROJECT_SNAPSHOT_HOST_ID = hostName;
    PROJECT_SNAPSHOT_PROJECT_ID_OVERRIDES_JSON = builtins.toJSON cfg.snapshots.remote.projectIdOverrides;
    XDG_DATA_HOME = config.xdg.dataHome;
    XDG_STATE_HOME = config.xdg.stateHome;
    PATH = "${pkgs.git}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
  };
in
{
  imports =
    lib.optionals (!isDarwin) [ ./options.nix ]
    ++ [
      (repoLib.assertPlatform {
        package = "dev.projects";
        platforms = [ "darwin" ];
      })
    ]
    ++ lib.optionals isDarwin (repoLib.importAll ./.);

  config = lib.mkIf isDarwin {
    home.packages = [
      projectScan
      projectSnapshot
    ];

    my.paths.exported."dev.projects.snapshots" = cfg.snapshots.directory;

    assertions = [
      {
        assertion = cfg.snapshots.remote.target == null || target != null;
        message = "my.dev.projects.snapshots.remote.target must name a declared my.storage.remote.targets entry.";
      }
      {
        assertion = cfg.snapshots.remote.target == null || gitTarget != null;
        message = "my.dev.projects snapshots require a Git remote target.";
      }
      {
        assertion = cfg.snapshots.remote.target == null || builtins.elem target.provisioner.kind [ "sshBare" "gitea" ];
        message = "my.dev.projects requires provisioner.kind = \"sshBare\" or \"gitea\" for automatic repository creation.";
      }
    ];

    launchd.agents.projects-scan = {
      enable = true;
      config = {
        Label = "org.nix-config.projects-scan";
        ProgramArguments = [ "${projectScanNotify}/bin/project-scan-notify" ];
        ProcessType = "Background";
        StartCalendarInterval = [
          {
            Weekday = 1;
            Hour = 9;
            Minute = 15;
          }
        ];
        EnvironmentVariables = launchdEnvironment;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/nix-config-projects-scan.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/nix-config-projects-scan-error.log";
      };
    };

    launchd.agents.projects-snapshot = {
      enable = true;
      config = {
        Label = "org.nix-config.projects-snapshot";
        ProgramArguments = [ "${projectSnapshot}/bin/project-snapshot" ];
        ProcessType = "Background";
        StartInterval = 21600;
        EnvironmentVariables = launchdEnvironment;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/nix-config-projects-snapshot.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/nix-config-projects-snapshot-error.log";
      };
    };
  };
}
