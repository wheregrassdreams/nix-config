{
  config,
  lib,
  pkgs,
  ...
}:
let
  denoCache = "${config.my.paths.xdg.cache}/deno";
in
{
  config = lib.mkIf (config.my.terminal.tools.media.enable && !config.my.terminal.tools.minimal) {
    my.paths.exported."terminal.tools.deno-cache" = denoCache;
    home.sessionVariables.DENO_DIR = denoCache;

    home.packages = with pkgs; [
      unstable.ffmpeg
      imagemagick
      resvg
      unstable.deno
      unstable.yt-dlp
    ];
  };
}
