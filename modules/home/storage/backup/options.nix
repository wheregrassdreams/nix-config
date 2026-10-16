{ lib, ... }:
let
  classes = [
    "critical"
    "valuable"
    "rebuildable"
  ];
  scheduleType = lib.types.submodule (
    { ... }:
    {
      options = {
        kind = lib.mkOption {
          type = lib.types.enum [
            "daily"
            "weekly"
          ];
          default = "daily";
        };
        time = lib.mkOption {
          type = lib.types.strMatching "([01][0-9]|2[0-3]):[0-5][0-9]";
          default = "02:00";
        };
        weekday = lib.mkOption {
          type = lib.types.enum [
            "sunday"
            "monday"
            "tuesday"
            "wednesday"
            "thursday"
            "friday"
            "saturday"
          ];
          default = "sunday";
        };
      };
    }
  );
  retentionType = lib.types.submodule {
    options = {
      daily = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
      };
      weekly = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
      };
      monthly = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
      };
    };
  };
  policyType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        repository = lib.mkOption { type = lib.types.str; };
        schedule = lib.mkOption {
          type = scheduleType;
          default = {
            kind = if name == "rebuildable" then "weekly" else "daily";
          };
        };
        retention = lib.mkOption {
          type = retentionType;
          default = {
            daily =
              if name == "critical" then
                14
              else if name == "valuable" then
                7
              else
                0;
            weekly = if name == "rebuildable" then 4 else 8;
            monthly =
              if name == "critical" then
                12
              else if name == "valuable" then
                6
              else
                2;
          };
        };
      };
    }
  );
  repositoryType = lib.types.submodule {
    options = {
      target = lib.mkOption { type = lib.types.str; };
      repositoryPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional backend-relative repository path; by default host ID and repository ID are appended to the target prefix.";
      };
      initIfMissing = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Initialize this Restic repository on its first scheduled backup when Restic reports that it does not exist.";
      };
      passwordFile = lib.mkOption {
        type = lib.types.str;
        description = "Restic repository encryption password file, normally a SOPS secret path.";
      };
      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Environment file for backend credentials, such as S3 credentials.";
      };
      rcloneConfigFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Rclone configuration file containing the target ID as its remote name.";
      };
    };
  };
  datasetType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this dataset participates in scheduled backup jobs.";
      };
      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Paths owned by this capability and registered for backup.";
      };
      class = lib.mkOption {
        type = lib.types.enum classes;
        default = "valuable";
      };
    };
  };
in
{
  options.my.storage.backup = {
    repositories = lib.mkOption {
      type = lib.types.attrsOf repositoryType;
      default = { };
    };
    policies = lib.mkOption {
      type = lib.types.attrsOf policyType;
      default = { };
    };
    datasets = lib.mkOption {
      type = lib.types.attrsOf datasetType;
      default = { };
    };
  };
}
