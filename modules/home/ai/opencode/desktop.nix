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
      package = "ai.opencode.desktop";
      platforms = [ "darwin" ];
      when = [
        "my"
        "ai"
        "opencode"
        "desktop"
        "enable"
      ];
    })
  ];

  config = lib.mkIf config.my.ai.opencode.desktop.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "opencode-desktop" ];
  };
}
