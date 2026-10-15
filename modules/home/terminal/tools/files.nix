{
  config,
  lib,
  pkgs,
  ...
}:
let
  trash = import ./lib/trash-command.nix { inherit pkgs; };
in
{
  home.packages = lib.optionals (!config.my.terminal.tools.minimal) [
    trash
    pkgs.unstable.rclone
  ];
}
