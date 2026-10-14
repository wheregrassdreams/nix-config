{
  lib,
  pkgs,
  repoLib,
  ...
}:
{
  imports = lib.optionals pkgs.stdenv.isDarwin [ ../../homebrew ] ++ repoLib.importAll ./.;
}
