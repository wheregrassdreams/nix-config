{ config, lib, ... }:
{
  config = lib.mkIf config.my.terminal.shell.integrations.macos.enable {
    home.shellAliases = {
      o = "open";
      reveal = "open -R ";
    };
  };
}
