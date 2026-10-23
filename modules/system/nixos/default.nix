{ mylib, ... }:
{
  imports = [
    ../shared
    ../services/nixos.nix
  ]
  ++ mylib.importAll ./.;
}
