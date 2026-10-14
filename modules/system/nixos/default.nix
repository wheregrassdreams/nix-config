{ repoLib, ... }:
{
  imports = [
    ../shared
    ../services/nixos.nix
    ../../home/ssh/options.nix
  ]
  ++ repoLib.importAll ./.;
}
