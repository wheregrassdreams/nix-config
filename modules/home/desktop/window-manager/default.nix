{
  lib,
  isDarwin,
  mylib,
  ...
}:
{
  imports = [
    (mylib.assertPlatform {
      package = "desktop.window-manager";
      platforms = [ "darwin" ];
    })
  ] ++ lib.optionals isDarwin (mylib.importAll ./.);
}
