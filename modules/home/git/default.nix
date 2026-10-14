{ repoLib, ... }:
{
  imports = [
    ../identity
  ]
  ++ repoLib.importAll ./.;
}
