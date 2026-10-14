{ repoLib, ... }:
{
  imports = [
    ../shared
  ]
  ++ repoLib.importAll ./.;
}
