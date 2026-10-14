{ config, lib, ... }:
{
  config = lib.mkIf config.my.ai.opencode.desktop.enable {
    my.homebrew.casks = [ "opencode-desktop" ];
  };
}
