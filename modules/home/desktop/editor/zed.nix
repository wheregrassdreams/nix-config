{
  config,
  lib,
  pkgs,
  repoLib,
  ...
}:
let
  cfg = config.my.desktop.editor.zed;
in
{
  imports = [
    (repoLib.assertPlatform {
      package = "desktop.editor.zed";
      platforms = [ "darwin" ];
      when = [
        "my"
        "desktop"
        "editor"
        "zed"
        "enable"
      ];
    })
  ];

  config = lib.mkIf cfg.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "zed" ];

    xdg.configFile."zed/keymap.json".source = ../../../../resources/zed/keymap.json;
  };
}
