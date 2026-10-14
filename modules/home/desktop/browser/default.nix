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
      package = "desktop.browser";
      platforms = [ "darwin" ];
    })
  ]
  ++ lib.optionals pkgs.stdenv.isDarwin (repoLib.importAll ./.);
}
