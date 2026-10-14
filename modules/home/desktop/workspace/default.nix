{
  lib,
  isDarwin,
  repoLib,
  ...
}:
{
  imports =
    lib.optionals isDarwin [ ../../homebrew ]
    ++ [
      (repoLib.assertPlatform {
        package = "desktop.workspace";
        platforms = [ "darwin" ];
      })
    ]
    ++ lib.optionals isDarwin (repoLib.importAll ./.);
}
