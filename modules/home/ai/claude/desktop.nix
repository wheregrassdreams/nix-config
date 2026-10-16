{
  config,
  lib,
  pkgs,
  repoLib,
  ...
}:
let
  cfg = config.my.ai.claude.desktop;
in
{
  imports = [
    (repoLib.assertPlatform {
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

  config = lib.mkIf cfg {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "claude" ];
  };
}
