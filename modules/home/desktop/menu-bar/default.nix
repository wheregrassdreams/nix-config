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
  ++ [
    (repoLib.assertPlatform {
      package = "desktop.menu-bar";
      platforms = [ "darwin" ];
    })
  ]
  ++ lib.optionals pkgs.stdenv.isDarwin (repoLib.importAll ./.);
}
