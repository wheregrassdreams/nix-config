{
  config,
  hostName,
  lib,
  ...
}:
{
  options.my.staging.reprise = {
    projectsPath = lib.mkOption {
      type = lib.types.str;
      default = config.my.paths.personal.projects;
      description = "Local projects directory used by Reprise.";
    };
    inactiveAfterDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 90;
      description = "Days without activity before a repository is flagged for review.";
    };
    snapshotDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/project-snapshots";
      description = "Local snapshot store path.";
    };
    retentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Snapshot retention period.";
    };
    hostId = lib.mkOption {
      type = lib.types.str;
      default = hostName;
      description = "Host identifier used in remote snapshot metadata.";
    };
    xdgDataHome = lib.mkOption {
      type = lib.types.str;
      default = config.xdg.dataHome;
      description = "XDG data directory used by Reprise.";
    };
    xdgStateHome = lib.mkOption {
      type = lib.types.str;
      default = config.xdg.stateHome;
      description = "XDG state directory used by Reprise.";
    };
    remote = {
      target = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Name of the declared storage target used for snapshots.";
      };
      resolved = lib.mkOption {
        default = null;
        description = "Resolved Git destination supplied by the nix-config bridge.";
        type = lib.types.nullOr (
          lib.types.submodule {
            options = {
              kind = lib.mkOption {
                type = lib.types.enum [
                  "sshBare"
                  "gitea"
                  "giteaPreprovisioned"
                ];
              };
              sshHost = lib.mkOption { type = lib.types.str; };
              root = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
              giteaApiUrl = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
              giteaOrganization = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
              giteaTokenFile = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
              giteaRepository = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
            };
          }
        );
      };
    };
  };
}
