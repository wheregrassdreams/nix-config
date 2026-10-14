{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.desktop.menuBar.ice.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "jordanbaird-ice" ];
  };
}
