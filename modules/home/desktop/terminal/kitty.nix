{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.desktop.terminal.kitty.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "kitty" ];
  };
}
