{ lib, ... }:
{
  options.my.desktop.input = {
    keyboardMapping.enable = lib.mkEnableOption "keyboard mapping";
    mouseScroll.enable = lib.mkEnableOption "mouse scrolling enhancements";
  };
}
