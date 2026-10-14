{ repoLib, ... }:
{
  imports = [
    ./options.nix
    ../shared
  ]
  ++ repoLib.importAll ./.;
}
