{ repoLib, ... }:
{
  imports = [ ../../homebrew/options.nix ] ++ repoLib.importAll ./.;
}
