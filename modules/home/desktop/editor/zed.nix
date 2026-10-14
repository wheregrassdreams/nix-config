{ config, lib, ... }:
let
  cfg = config.my.desktop.editor.zed;
in
{
  config = lib.mkIf cfg.enable {
    my.homebrew.casks = [ "zed" ];

    xdg.configFile."zed/keymap.json".source = ../../../../resources/zed/keymap.json;
  };
}
