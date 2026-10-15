{ config, lib, ... }:
{
  config = lib.mkIf config.my.desktop.input.mouseScroll.enable {
    my.homebrew.casks = [ "mos" ];
  };
}
