{ lib, ... }:
{
  options.my.ai.codex.cli = {
    enable = lib.mkEnableOption "Codex command-line agent";
    packageChannel = lib.mkOption {
      type = lib.types.enum [
        "stable"
        "latest"
      ];
      default = "latest";
      description = "Package source for Codex; latest uses the daily-updated agent package set.";
    };
  };
}
