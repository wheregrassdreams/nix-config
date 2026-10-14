{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.my.tools.enable && config.my.tools.media) {
    home.packages = with pkgs; [
      ffmpeg
      imagemagick
      resvg
    ];
  };
}
