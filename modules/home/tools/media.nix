{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.my.tools.media) {
    home.packages = with pkgs; [
      ffmpeg
      imagemagick
      resvg
    ];
  };
}
