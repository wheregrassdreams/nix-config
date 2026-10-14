{ config, lib, ... }:
{
  config = lib.mkIf (config.my.terminal.enable && config.my.terminal.tmux.enable) {
    programs.tmux.extraConfig = lib.mkAfter ''
      bind b run-shell "tmux setw -g status \$(tmux show -g -w status | grep -q off && echo on || echo off)"
    '';
  };
}
