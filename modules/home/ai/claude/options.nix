{ lib, ... }:
{
  options.my.ai.claude = {
    cli.enable = lib.mkEnableOption "Claude Code command-line agent";
    desktop.enable = lib.mkEnableOption "Claude desktop app";
  };
}
