{ lib, ... }:
{
  options.my.terminal.tools = {
    minimal = lib.mkEnableOption "a reduced set of everyday terminal tools";
    television.enable = lib.mkEnableOption "Television interactive search";
    media.enable = lib.mkEnableOption "media command-line tools";
  };
}
