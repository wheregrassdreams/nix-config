{ config, lib, ... }:
{
  config = lib.mkIf config.my.desktop.menuBar.ice.enable {
    my.homebrew.casks = [ "jordanbaird-ice" ];
  };
}
