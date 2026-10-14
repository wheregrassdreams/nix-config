{
  lib,
  pkgs,
  repoLib,
  ...
}:
{
  imports = [
    ./options.nix
  ]
  ++ lib.optionals pkgs.stdenv.isDarwin [ ../../homebrew ]
  ++ repoLib.importAll ./.;
}
