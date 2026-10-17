{ config, lib, ... }:
{
  options.my.dev.projects = {
    inactiveAfterDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 90;
      description = "Days without file or commit activity before a repository is flagged for review.";
    };

    snapshots = {
      directory = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.dataHome}/project-snapshots";
        description = "Local Git snapshot store, outside the projects tree.";
      };

      retentionDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 30;
        description = "How long automated project snapshots are retained.";
      };

      remote = {
        target = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Registered Git target for off-device project snapshots.";
        };
        projectIdOverrides = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Stable project IDs keyed by normalized local repository path.";
        };
      };
    };
  };
}
