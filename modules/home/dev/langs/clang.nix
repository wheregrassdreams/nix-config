{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.langs;
in
{
  config = lib.mkIf cfg.clang.enable {
    home.packages =
      with pkgs;
      [
        clang-tools
        llvmPackages.clang
        cmake
      ]
      ++ lib.optionals cfg.clang.opengl.enable [ glfw ];
  };
}
