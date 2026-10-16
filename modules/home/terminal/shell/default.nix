{ inputs, repoLib, ... }:
{
  imports = [
    inputs.nix-index-database.homeModules.nix-index
  ]
  ++ repoLib.importAll ./.;
}
