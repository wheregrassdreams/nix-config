{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.system.darwin.dock;
in
{
  config = lib.mkIf cfg.enable (import ./lib/dock-implementation.nix { inherit cfg lib pkgs; });
}
