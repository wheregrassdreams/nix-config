{ repoLib, ... }:
{
  imports = [
    ./options.nix
    ../identity
  ]
  ++ repoLib.importAll ./.;
}
