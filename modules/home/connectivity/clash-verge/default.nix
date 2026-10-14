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
      package = "connectivity.clash-verge";
      platforms = [ "darwin" ];
    })
  ]
  ++ lib.optionals isDarwin (repoLib.importAll ./.);
}
