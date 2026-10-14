{ config, lib, ... }:
{
  config = lib.mkIf config.my.git.lazygit.enable {
    programs.lazygit.enable = true;
  };
}
