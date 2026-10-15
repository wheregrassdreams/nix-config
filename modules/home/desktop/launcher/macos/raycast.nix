{ config, lib, ... }:
{
  config = lib.mkIf config.my.desktop.launcher.raycast.enable {
    my.homebrew.casks = [ "raycast" ];
  };
}
