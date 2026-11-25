{ lib, ... }:
{
  options.my.ai.fork-pane = {
    enable = lib.mkEnableOption "fork-pane, which opens a forked agent session in a Rex or tmux pane";
  };
}
