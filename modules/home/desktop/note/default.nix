{ mylib, ... }:
{
  imports = [
    ../../homebrew
    (mylib.assertPlatform {
      package = "desktop.note";
      platforms = [ "darwin" ];
    })
  ] ++ mylib.importAll ./.;
}
