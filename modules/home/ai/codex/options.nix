{ lib, ... }:
{
  options.my.ai.codex.cli.enable = lib.mkEnableOption "Codex command-line agent";
}
