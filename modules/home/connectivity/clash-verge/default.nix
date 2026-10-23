{
  lib,
  isDarwin,
  mylib,
  ...
}:
{
  imports =
    lib.optionals (!isDarwin) [ ./options.nix ]
    ++ lib.optionals isDarwin [ ../../homebrew ]
    ++ [
      (mylib.assertPlatform {
        package = "connectivity.clash-verge";
        platforms = [ "darwin" ];
      })
    ]
    ++ lib.optionals isDarwin (mylib.importAll ./.);
}
