{ config, lib, ... }:
let
  cfg = config.my.desktop.input.mouseScroll;
in
{
  config = lib.mkIf cfg.enable {
    my.homebrew.casks = [ "mos" ];
  };
}
