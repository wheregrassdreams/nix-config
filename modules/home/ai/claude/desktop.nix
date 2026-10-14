{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.ai.claude.desktop.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "claude" ];
  };
}
