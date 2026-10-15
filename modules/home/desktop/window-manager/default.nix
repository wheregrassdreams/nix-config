{
  lib,
  isDarwin,
  repoLib,
  ...
}:
{
  imports = [
    (repoLib.assertPlatform {
      package = "desktop.window-manager";
      platforms = [ "darwin" ];
    })
  ] ++ lib.optionals isDarwin (repoLib.importAll ./.);
}
