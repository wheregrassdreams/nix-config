{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.dev.langs.lua.enable {
    home.packages = with pkgs; [
      lua
      luarocks
    ];
  };
}
