{ config, lib, ... }:
{
  config = lib.mkIf config.my.gui.terminal.kitty.enable {
    my.homebrew.casks = [ "kitty" ];
  };
}
