{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.my.terminal.tools.media.enable && !config.my.terminal.tools.minimal) {
    home.packages = with pkgs; [
      ffmpeg
      imagemagick
      resvg
    ];
  };
}
