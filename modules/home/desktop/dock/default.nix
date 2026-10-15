{
  lib,
  isDarwin,
  repoLib,
  ...
}:
{
  imports = [
    ./options.nix
  ]
  ++ lib.optionals isDarwin [ ../../homebrew ]
  ++ [
    (repoLib.assertPlatform {
      package = "desktop.dock";
      platforms = [ "darwin" ];
    })
  ]
  ++ lib.optionals isDarwin (repoLib.importAll ./.);
}
