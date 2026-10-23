{
  config,
  lib,
  pkgs,
  mylib,
  ...
}:
let
  cfg = config.my.ai.opencode.desktop;
in
{
  imports = [
    (mylib.assertPlatform {
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

  config = lib.mkIf cfg.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "opencode-desktop" ];
  };
}
