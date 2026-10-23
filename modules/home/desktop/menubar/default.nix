{
  lib,
  isDarwin,
  mylib,
  ...
}:
{
  imports =
    lib.optionals isDarwin [ ../../homebrew ]
    ++ [
      (mylib.assertPlatform {
        package = "desktop.menubar";
        platforms = [ "darwin" ];
      })
    ]
    ++ lib.optionals isDarwin (mylib.importAll ./.);
}
