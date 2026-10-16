{
  lib,
  isDarwin,
  repoLib,
  ...
}:
{
  imports =
    lib.optionals (!isDarwin) [ ./options.nix ]
    ++ lib.optionals isDarwin [ ../../homebrew ]
    ++ [
      (repoLib.assertPlatform {
        package = "desktop.files";
        platforms = [ "darwin" ];
      })
    ]
    ++ lib.optionals isDarwin (repoLib.importAll ./.);
}
