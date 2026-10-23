{ lib, ... }:
{
  options.my.dev.tools.nh.enable = lib.mkEnableOption "the nh Nix helper CLI";
}
