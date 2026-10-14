{ lib, ... }:
{
  options.my.development = {
    enable = lib.mkEnableOption "development environment";
    lua.enable = lib.mkEnableOption "Lua development tools";
    nix.enable = lib.mkEnableOption "Nix development tools";
    go.enable = lib.mkEnableOption "Go development tools";
    javascript.enable = lib.mkEnableOption "JavaScript development tools";
    rust.enable = lib.mkEnableOption "Rust development tools";
    clang = {
      enable = lib.mkEnableOption "C and C++ development tools";
      opengl.enable = lib.mkEnableOption "OpenGL development environment" // { default = true; };
    };
    haskell.enable = lib.mkEnableOption "Haskell development tools";
    python = {
      enable = lib.mkEnableOption "Python development tools";
      suite = lib.mkOption {
        type = lib.types.enum [ "minimal" "full" ];
        default = "minimal";
        description = "Python package set to install.";
      };
    };
  };
}
