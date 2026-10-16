{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.terminal.tmux.smartWindowNaming.enable {
    programs.tmux.plugins = lib.mkBefore [ pkgs.tmuxPlugins.tmux-window-name ];
  };
}
