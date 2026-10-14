{ inputs, repoLib, ... }:
{
  imports = [
    ./options.nix
    inputs.nix-index-database.homeModules.nix-index
  ]
  ++ repoLib.importAll ./.;
}
