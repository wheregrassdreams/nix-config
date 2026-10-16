{
  config,
  lib,
  pkgs,
  repoLib,
  ...
}:
let
  cfg = config.my.ai.opencode.desktop;
in
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

  config = lib.mkIf cfg {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "opencode-desktop" ];
  };
}
