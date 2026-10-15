{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.langs.c;
in
{
  imports = [ ./options.nix ];

  config.home.packages =
    with pkgs;
    [
      clang-tools
      llvmPackages.clang
      cmake
    ]
    ++ lib.optionals cfg.opengl.enable [ glfw ];
}
