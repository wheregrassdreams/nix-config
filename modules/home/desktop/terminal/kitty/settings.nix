{
  config,
  lib,
  pkgs,
  repoLib,
  ...
}:
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

  config = lib.mkIf config.my.desktop.terminal.kitty.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "kitty" ];
  };
}
