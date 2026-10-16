{ config, lib, ... }:
let
  cfg = config.my.git.lazygit;
in
{
  config = lib.mkIf cfg.enable {
    programs.lazygit.enable = true;
  };
}
