{ lib, ... }:
{
  options.my.desktop.launcher = {
    raycast.enable = lib.mkEnableOption "Raycast launcher";
  };
}
