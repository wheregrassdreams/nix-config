{
  config,
  lib,
  pkgs,
  mylib,
  ...
}:
let
  cfg = config.my.ai.claude.desktop;
in
{
  imports = [
    (mylib.assertPlatform {
      package = "ai.claude.desktop";
      platforms = [ "darwin" ];
      when = [
        "my"
        "ai"
        "claude"
        "desktop"
        "enable"
      ];
    })
  ];

  config = lib.mkIf cfg.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "claude" ];
  };
}
