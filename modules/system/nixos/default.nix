{ mylib, ... }:
{
  imports = [
    ../shared
    # ../services/nixos.nix is paused for reevaluation.
  ]
  ++ mylib.importAll ./.;
}
