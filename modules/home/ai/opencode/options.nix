{ lib, ... }:
{
  options.my.ai.opencode = {
    cli.enable = lib.mkEnableOption "OpenCode command-line agent";
    desktop.enable = lib.mkEnableOption "OpenCode desktop app";
  };
}
