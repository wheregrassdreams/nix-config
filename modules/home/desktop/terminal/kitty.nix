{ config, lib, ... }:
{
  config = lib.mkIf config.my.desktop.terminal.kitty.enable {
    my.homebrew.casks = [ "kitty" ];
  };
}
