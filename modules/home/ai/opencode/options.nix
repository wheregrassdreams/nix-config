{ lib, ... }:
{
  options.my.ai.opencode = {
    cli = {
      enable = lib.mkEnableOption "OpenCode command-line agent";
      packageChannel = lib.mkOption {
        type = lib.types.enum [
          "stable"
          "latest"
        ];
        default = "stable";
        description = "Package source for OpenCode; latest uses the daily-updated agent package set.";
      };
    };
    desktop.enable = lib.mkEnableOption "OpenCode desktop app";
  };
}
