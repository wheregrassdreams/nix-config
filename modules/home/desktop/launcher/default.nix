{
  lib,
  isDarwin,
  mylib,
  ...
}:
{
  imports = [
    (mylib.assertPlatform {
      package = "desktop.launcher";
      platforms = [
        "darwin"
        "linux"
      ];
    })
  ]
  ++ lib.optionals isDarwin [
    ../../homebrew
    ./macos/_raycast.nix
    ./macos/_vicinae.nix
  ]
  ++ lib.optionals (!isDarwin) [ ./linux/_vicinae.nix ]
  ++ mylib.importAll ./.;
}
