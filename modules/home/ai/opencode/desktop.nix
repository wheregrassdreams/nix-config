{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.ai.opencode.desktop.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "opencode-desktop" ];
  };
}
