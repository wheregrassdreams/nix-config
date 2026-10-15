{ lib, ... }:
{
  options.my.dev.langs.c.opengl.enable = lib.mkEnableOption "OpenGL development environment" // {
    default = true;
  };
}
