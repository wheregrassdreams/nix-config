{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = lib.optionals (!config.my.terminal.tools.minimal) [ pkgs.sshpass ];
}
