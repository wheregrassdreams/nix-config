{
  lib,
  pkgs,
  repoLib,
  ...
}:
{
  imports =
    lib.optionals pkgs.stdenv.isDarwin [ ../../homebrew ]
    ++ [
      (repoLib.assertPlatform {
        package = "desktop.workspace";
        platforms = [ "darwin" ];
      })
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin (repoLib.importAll ./.);
}
