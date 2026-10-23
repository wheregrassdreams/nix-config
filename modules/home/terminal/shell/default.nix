{ inputs, mylib, ... }:
{
  imports = [
    inputs.nix-index-database.homeModules.nix-index
  ]
  ++ mylib.importAll ./.;
}
