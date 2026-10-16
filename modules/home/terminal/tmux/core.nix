{
  config,
  lib,
  pkgs,
  ...
}:
let
  inputMethod = config.my.terminal.tmux.inputMethod;
  interceptPrefix =
    inputMethod.command != null
    && lib.any (event: event.type == "prefix") (lib.attrValues inputMethod.events);
in
{
  config = {
    my.paths.exported."terminal.tmux.resurrect" = "${config.xdg.dataHome}/tmux/resurrect";

    programs.tmux = {
      enable = true;
      baseIndex = 1;
      clock24 = true;
      tmuxp.enable = true;
      historyLimit = 10000;
      keyMode = "vi";
      mouse = true;
      # The input-method consumer intercepts prefix when enabled so it can
      # reset the input method before entering tmux's prefix table.
      prefix = if interceptPrefix then "None" else inputMethod.prefixKey;
      shell = "${pkgs.zsh}/bin/zsh";
      terminal = "tmux-256color";
      escapeTime = 10;
      plugins = with pkgs; [
        {
          plugin = tmuxPlugins.resurrect;
          extraConfig = ''
            set -g @resurrect-dir "${config.xdg.dataHome}/tmux/resurrect"
            set -g @resurrect-strategy-nvim 'session'
            set -g @resurrect-capture-pane-contents 'on'
          '';
        }
        tmuxPlugins.dotbar
        {
          plugin = tmuxPlugins.continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            # Continuum's macOS boot helper opens Terminal.app. A local
            # launchd agent starts the configured server silently instead.
            set -g @continuum-boot 'off'
            set -g @continuum-save-interval '15'
          '';
        }
        tmuxPlugins.vim-tmux-navigator
      ];
      extraConfig = ''
        bind ',' run-shell 'tmux source-file ${config.xdg.configHome}/tmux/tmux.conf \; display-message -d 800 "config reloaded"'
        set -g allow-passthrough on
        set -g renumber-windows on
        set -g set-clipboard on
        set -g focus-events on
      '';
    };
  };
}
