{ lib, ... }:
{
  options.my.staging.reprise = {
    projectsPath = lib.mkOption {
      type = lib.types.str;
      description = "Resolved local projects directory supplied by the host integration.";
    };
    inactiveAfterDays = lib.mkOption {
      type = lib.types.ints.positive;
      description = "Days without activity before a repository is flagged for review.";
    };
    snapshotDirectory = lib.mkOption {
      type = lib.types.str;
      description = "Local snapshot store path supplied by the host integration.";
    };
    retentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      description = "Snapshot retention period supplied by the host integration.";
    };
    hostId = lib.mkOption {
      type = lib.types.str;
      description = "Host identifier used in remote snapshot metadata.";
    };
    xdgDataHome = lib.mkOption {
      type = lib.types.str;
      description = "Resolved XDG data directory supplied by the host integration.";
    };
    xdgStateHome = lib.mkOption {
      type = lib.types.str;
      description = "Resolved XDG state directory supplied by the host integration.";
    };
    remote = lib.mkOption {
      default = null;
      description = "Resolved Git snapshot destination supplied by the host integration.";
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
}
