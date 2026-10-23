{
  config,
  isDarwin,
  lib,
  pkgs,
  reprise,
  outPath,
  ...
}:
let
  cfg = config.my.staging.reprise;
  remote = cfg.remote.resolved;
  remoteArgs =
    if remote == null then
      ""
    else if remote.kind == "gitea" then
      "--remote-kind gitea --remote-ssh-host ${lib.escapeShellArg remote.sshHost} --gitea-api-url ${lib.escapeShellArg remote.giteaApiUrl} --gitea-organization ${lib.escapeShellArg remote.giteaOrganization} --gitea-token-file ${lib.escapeShellArg remote.giteaTokenFile} --host-id ${lib.escapeShellArg cfg.hostId}"
    else if remote.kind == "giteaPreprovisioned" then
      "--remote-kind giteaPreprovisioned --remote-ssh-host ${lib.escapeShellArg remote.sshHost} --gitea-repository ${lib.escapeShellArg remote.giteaRepository} --host-id ${lib.escapeShellArg cfg.hostId}"
    else
      "--remote-kind sshBare --remote-ssh-host ${lib.escapeShellArg remote.sshHost} --remote-root ${lib.escapeShellArg remote.root} --host-id ${lib.escapeShellArg cfg.hostId}";
  projectScanNotify = pkgs.writeShellApplication {
    name = "project-scan-notify";
    runtimeInputs = [ pkgs.git ];
    text = ''
      exec ${reprise}/bin/reprise audit
    '';
  };
  repriseSnapshot = pkgs.writeShellApplication {
    name = "reprise-snapshot";
    runtimeInputs = [
      pkgs.git
      pkgs.openssh
    ];
    text = ''
      exec ${reprise}/bin/reprise snapshot --snapshot-root ${lib.escapeShellArg cfg.snapshotDirectory} --retention-days ${toString cfg.retentionDays} ${remoteArgs} "$@"
    '';
  };
  repriseGiteaPolicy = pkgs.writeShellApplication {
    name = "reprise-gitea-policy";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${outPath}/gitea-policy/reconcile_gitea_snapshot_policy.py --policy-file ${outPath}/gitea-policy/gitea-static-snapshot-policy.json "$@"
    '';
  };
  serviceEnvironment = {
    NIX_CONFIG_PATH_PROJECTS = cfg.projectsPath;
    PROJECTS_INACTIVE_AFTER_DAYS = toString cfg.inactiveAfterDays;
    PROJECT_SNAPSHOT_REMOTE_SSH_HOST = if remote == null then "" else remote.sshHost;
    PROJECT_SNAPSHOT_REMOTE_ROOT = if remote == null then "" else remote.root;
    PROJECT_SNAPSHOT_REMOTE_KIND = if remote == null then "" else remote.kind;
    PROJECT_SNAPSHOT_GITEA_API_URL = if remote == null then "" else remote.giteaApiUrl;
    PROJECT_SNAPSHOT_GITEA_ORGANIZATION = if remote == null then "" else remote.giteaOrganization;
    PROJECT_SNAPSHOT_GITEA_TOKEN_FILE = if remote == null then "" else remote.giteaTokenFile;
    PROJECT_SNAPSHOT_GITEA_REPOSITORY = if remote == null then "" else remote.giteaRepository;
    PROJECT_SNAPSHOT_HOST_ID = cfg.hostId;
    XDG_DATA_HOME = cfg.xdgDataHome;
    XDG_STATE_HOME = cfg.xdgStateHome;
    PATH = "${pkgs.git}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
  };
in
{
  imports = [ ./options.nix ];

  config = {
    home.packages = [
      reprise
      repriseGiteaPolicy
    ];
  }
  // lib.optionalAttrs isDarwin {
    launchd.agents.reprise-daemon = {
      enable = true;
      config = {
        Label = "org.nix-config.reprise-daemon";
        ProgramArguments = [
          "${reprise}/bin/reprise"
          "daemon"
        ];
        ProcessType = "Background";
        RunAtLoad = true;
        KeepAlive = true;
        EnvironmentVariables = serviceEnvironment;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/reprise-daemon.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/reprise-daemon-error.log";
      };
    };

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
        EnvironmentVariables = serviceEnvironment;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/nix-config-projects-scan.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/nix-config-projects-scan-error.log";
      };
    };

    launchd.agents.projects-snapshot = {
      enable = true;
      config = {
        Label = "org.nix-config.projects-snapshot";
        ProgramArguments = [ "${repriseSnapshot}/bin/reprise-snapshot" ];
        ProcessType = "Background";
        StartInterval = 3600;
        EnvironmentVariables = serviceEnvironment;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/nix-config-projects-snapshot.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/nix-config-projects-snapshot-error.log";
      };
    };

  }
  // lib.optionalAttrs (!isDarwin) {
    systemd.user.services.reprise-daemon = {
      Unit.Description = "Local reprise command daemon";
      Service = {
        Type = "simple";
        ExecStart = "${reprise}/bin/reprise daemon";
        Restart = "on-failure";
        RestartSec = 2;
        Environment = lib.mapAttrsToList (name: value: "${name}=${value}") serviceEnvironment;
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.services.reprise-snapshot = {
      Unit.Description = "Capture and publish Git project snapshots";
      Service = {
        Type = "oneshot";
        ExecStart = "${repriseSnapshot}/bin/reprise-snapshot";
        Environment = lib.mapAttrsToList (name: value: "${name}=${value}") serviceEnvironment;
      };
    };
    systemd.user.timers.reprise-snapshot = {
      Unit.Description = "Capture Git project snapshots hourly";
      Timer = {
        OnCalendar = "hourly";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
