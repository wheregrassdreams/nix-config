{
  config,
  lib,
  pkgs,
  repoLib,
  ...
}:
let
  cfg = config.my.desktop.terminal.kitty;
in
{
  imports = [
    (repoLib.assertPlatform {
      package = "desktop.terminal.kitty";
      platforms = [ "darwin" ];
      when = [
        "my"
        "desktop"
        "terminal"
        "kitty"
        "enable"
      ];
    })
  ];

  config = lib.mkIf cfg {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "kitty" ];
  };
}
