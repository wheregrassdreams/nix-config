{ repoLib, ... }:
{
  imports = [
    ../shared
    ../services/nixos.nix
    ./options.nix
  ]
  ++ repoLib.importAll ./.;
}
