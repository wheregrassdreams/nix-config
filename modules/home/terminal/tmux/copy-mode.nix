{ lib, ... }:
let
  copyModeBindings = [
    {
      key = "v";
      command = "send -X begin-selection";
    }
    {
      key = "V";
      command = "send -X select-line";
    }
    {
      key = "C-v";
      command = "send -X rectangle-toggle";
    }
    {
      key = "q";
      command = "send -X cancel";
    }
    {
      key = "Escape";
      command = "if-shell -F '#{selection_active}' 'send -X clear-selection' 'send -X cancel'";
    }
    {
      key = "C-[";
      command = "if-shell -F '#{selection_active}' 'send -X clear-selection' 'send -X cancel'";
    }
    {
      key = "/";
      command = ''command-prompt -i -p "Search down" "send -X search-forward-incremental \\\"%%%\\\""'';
    }
    {
      key = "?";
      command = ''command-prompt -i -p "Search up" "send -X search-backward-incremental \\\"%%%\\\""'';
    }
    {
      key = "n";
      command = "send -X search-again";
    }
    {
      key = "N";
      command = "send -X search-reverse";
    }
  ];
  render = binding: "bind -T copy-mode-vi ${binding.key} ${binding.command}";
  keys = map (binding: binding.key) copyModeBindings;
in
{
  config = {
    assertions = [
      {
        assertion = builtins.length keys == builtins.length (lib.unique keys);
        message = "tmux copy-mode bindings contain duplicate keys";
      }
    ];

    programs.tmux.extraConfig = lib.mkAfter ''
      # Use tmux's native buffer and OSC 52 clipboard integration.
      set -g @flash-copy-mode-vi-keys 's'
      bind -T copy-mode-vi y send -X copy-selection-and-cancel
      ${lib.concatMapStringsSep "\n" render copyModeBindings}

      # Keep mouse selections visible and copy them into tmux's buffer.
      # Vi and emacs copy-mode tables are separate.
      bind -T copy-mode-vi MouseUp1Pane send -X clear-selection
      bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-selection-no-clear
      bind -T copy-mode MouseUp1Pane send -X clear-selection
      bind -T copy-mode MouseDragEnd1Pane send -X copy-selection-no-clear

      # Refresh copy mode as pane output changes; pause refresh while a
      # selection is active and resume it when the selection clears.
      set-hook -g pane-mode-entered[copy-mode-refresh] 'if-shell -F "#{==:#{pane_mode},copy-mode}" { send-keys -X refresh-on }'

      set-option -g set-clipboard on
    '';
  };
}
