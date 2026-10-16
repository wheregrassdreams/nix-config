{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.terminal.tools;
  paths = config.my.paths;
  denoCache = "${paths.xdg.cache}/deno";
in
{
  config = lib.mkIf (cfg.media.enable && !cfg.minimal) {
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
