{ repoLib, ... }:
{
  imports = [
    ../shared
    ../services/nixos.nix
  ]
  ++ repoLib.importAll ./.;
}
