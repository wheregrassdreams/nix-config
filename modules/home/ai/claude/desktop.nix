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

  config = lib.mkIf config.my.ai.claude.desktop.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "claude" ];
  };
}
