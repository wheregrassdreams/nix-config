{ config, lib, ... }:
{
  config = lib.mkIf config.my.shell.integrations.macos.enable {
    home.shellAliases = {
      o = "open";
      reveal = "open -R ";
    };
  };
}
