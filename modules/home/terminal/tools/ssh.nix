{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.terminal.tools;
in
{
  home.packages = lib.optionals (!cfg.minimal) [
    pkgs.sshpass
  ];
}
