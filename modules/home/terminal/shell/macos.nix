{ config, lib, ... }:
let
  cfg = config.my.terminal.shell;
in
{
  config = lib.mkIf cfg.integrations.macos.enable {
    home.shellAliases = {
      o = "open";
      reveal = "open -R ";
    };
  };
}
