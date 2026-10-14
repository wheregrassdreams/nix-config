{ repoLib, ... }:
{
  imports = [ ./options.nix ] ++ repoLib.importAll ./.;
}
