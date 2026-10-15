{ repoLib, ... }:
{
  imports = [
    ../../homebrew
    (repoLib.assertPlatform {
      package = "desktop.password";
      platforms = [ "darwin" ];
    })
  ] ++ repoLib.importAll ./.;
}
