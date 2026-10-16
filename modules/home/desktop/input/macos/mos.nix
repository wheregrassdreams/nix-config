{ config, lib, ... }:
let
  cfg = config.my.desktop.input.mouseScroll;
in
{
  config = lib.mkIf cfg.enable {
    my.homebrew.casks = [ "mos" ];

    # MacOS 上方向滚轮和平滑滚动
    targets.darwin.defaults."com.caldis.Mos" = {
      smooth = true;
      smoothVertical = true;
      smoothHorizontal = true;
      smoothSimTrackpad = false;
      deadZone = 1.0;

      reverse = true;
      reverseVertical = true;
      reverseHorizontal = true;

      step = 33.6;
      speed = 2.7;
      duration = 4.35;
      precision = 1.0;

      block = {
        type = "keyboard";
        code = 55;
      };
      dash = {
        type = "keyboard";
        code = 58;
      };
      toggle = {
        type = "keyboard";
        code = 56;
      };

      allowlist = false;
      applications = [ ];
      hideStatusItem = true;
      updateCheckOnAppStart = false;
      updateIncludingBetaVersion = false;
    };
  };
}
