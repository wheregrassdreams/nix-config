{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.development;
in
{
  config = lib.mkIf (cfg.enable && cfg.clang.enable) {
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
