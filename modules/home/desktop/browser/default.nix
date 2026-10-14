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
      package = "desktop.browser";
      platforms = [ "darwin" ];
    })
  ]
  ++ lib.optionals isDarwin (repoLib.importAll ./.);
}
