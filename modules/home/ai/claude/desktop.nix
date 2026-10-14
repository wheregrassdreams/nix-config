{ config, lib, ... }:
{
  config = lib.mkIf config.my.ai.claude.desktop.enable {
    my.homebrew.casks = [ "claude" ];
  };
}
