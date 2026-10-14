{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.desktop.terminal.ghostty;
in
{
  config = lib.mkIf cfg.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "ghostty" ];
    xdg.configFile."ghostty/config".source = ./ghostty/config;
    xdg.configFile."ghostty/shaders".source = ./ghostty/shaders;
  };
}
