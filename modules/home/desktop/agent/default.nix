{
  mylib,
  ...
}:
{
  imports = [
    (mylib.assertPlatform {
      package = "desktop.agent";
      platforms = [ "darwin" ];
    })
  ] ++ mylib.importAll ./.;
}
