{
  repoLib,
  ...
}:
{
  imports = [
    (repoLib.assertPlatform {
      package = "desktop.agent";
      platforms = [ "darwin" ];
    })
  ] ++ repoLib.importAll ./.;
}
