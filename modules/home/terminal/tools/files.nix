{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.terminal.tools;
  trash = import ./lib/trash-command.nix { inherit pkgs; };
in
{
  home.packages = lib.optionals (!cfg.minimal) [
    trash
    pkgs.unstable.rclone
  ];
}
