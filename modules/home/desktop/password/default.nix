{ mylib, ... }:
{
  imports = [
    ../../homebrew
    (mylib.assertPlatform {
      package = "desktop.password";
      platforms = [ "darwin" ];
    })
  ] ++ mylib.importAll ./.;
}
