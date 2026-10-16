{ repoLib, ... }:
{
  imports = [
    ../core
  ]
  ++ repoLib.importAll ./.;
}
