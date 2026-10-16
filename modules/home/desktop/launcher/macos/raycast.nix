{ config, lib, ... }:
let
  cfg = config.my.desktop.launcher.raycast;
in
{
  config = lib.mkIf cfg.enable {
    my.homebrew.casks = [ "raycast" ];
  };
}
