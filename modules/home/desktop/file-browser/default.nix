{
  lib,
  pkgs,
  repoLib,
  ...
}:
{
  imports = [
    ./options.nix
    (repoLib.assertPlatform {
      package = "desktop.file-browser";
      platforms = [ "darwin" ];
    })
  ]
  ++ lib.optionals pkgs.stdenv.isDarwin (repoLib.importAll ./.);
}
