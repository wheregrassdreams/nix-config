{ config, lib, ... }: {
  config = lib.mkIf config.my.gui.menuBar.ice.enable {
    my.homebrew.casks = [ "jordanbaird-ice" ];
  };
}
