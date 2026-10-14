{ lib, ... }:
{
  options.my.desktop.editor = {
    zed.enable = lib.mkEnableOption "Zed editor";
  };
}
