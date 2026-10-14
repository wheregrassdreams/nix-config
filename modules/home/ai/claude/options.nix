{ lib, ... }:
{
  options.my.ai.claude = {
    cli = {
      enable = lib.mkEnableOption "Claude Code command-line agent";
      packageChannel = lib.mkOption {
        type = lib.types.enum [
          "stable"
          "latest"
        ];
        default = "stable";
        description = "Package source for Claude Code; latest uses the daily-updated agent package set.";
      };
    };
    desktop.enable = lib.mkEnableOption "Claude desktop app";
  };
}
