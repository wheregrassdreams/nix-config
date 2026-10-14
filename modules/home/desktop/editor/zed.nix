{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.desktop.editor.zed;
in
{
  config = lib.mkIf cfg.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "zed" ];

    xdg.configFile."zed/keymap.json".source = ../../../../resources/zed/keymap.json;
  };
}
