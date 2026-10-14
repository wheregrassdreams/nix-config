{
  config,
  lib,
  pkgs,
  repoLib,
  ...
}:
let
  cfg = config.my.desktop.terminal.ghostty;
in
{
  imports = [
    (repoLib.assertPlatform {
      package = "desktop.terminal.ghostty";
      platforms = [ "darwin" ];
      when = [
        "my"
        "desktop"
        "terminal"
        "ghostty"
        "enable"
      ];
    })
  ];

  config = lib.mkIf cfg.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "ghostty" ];
    xdg.configFile."ghostty/config".source = ./ghostty/config;
    xdg.configFile."ghostty/shaders".source = ./ghostty/shaders;
  };
}
