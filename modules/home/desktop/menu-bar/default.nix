{ repoLib, ... }:
{
  imports = [
    ./options.nix
    ../../homebrew/options.nix
  ]
  ++ repoLib.importAll ./.;
}
