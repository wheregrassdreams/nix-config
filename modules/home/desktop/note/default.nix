{ repoLib, ... }:
{
  imports = [
    ../../homebrew
    (repoLib.assertPlatform {
      package = "desktop.note";
      platforms = [ "darwin" ];
    })
  ] ++ repoLib.importAll ./.;
}
