{
  lib,
  pkgs,
  ...
}:
let
  plugin = pkgs.tmuxPlugins.tmux-prompt-cursor;
in
{
  config = {
    programs.tmux.plugins = lib.mkAfter [ plugin ];

    # Load after the shell package's ZLE/keymap setup, and only in tmux panes.
    programs.zsh.initContent = lib.mkAfter ''
      if [[ -n "''${TMUX-}" ]]; then
        source ${plugin}/share/zsh/tmux-prompt-cursor.zsh
      fi
    '';
  };
}
