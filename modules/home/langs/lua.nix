{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.development.lua.enable {
    home.packages = with pkgs; [
      lua
      luarocks
    ];
  };
}
