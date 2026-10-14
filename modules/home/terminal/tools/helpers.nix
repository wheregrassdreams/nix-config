{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = lib.optionals (!config.my.terminal.tools.minimal) [
    pkgs.sttr
    pkgs.tldr
    pkgs.nur.repos.charmbracelet.gum
  ];
}
