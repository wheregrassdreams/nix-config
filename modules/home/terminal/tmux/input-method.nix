{ config, lib, ... }:
let
  inputMethod = config.my.terminal.tmux.inputMethod.command;
in
{
  config = lib.mkIf (config.my.terminal.enable && config.my.terminal.tmux.enable) {
    programs.tmux.extraConfig = lib.mkAfter (
      lib.optionalString (inputMethod != null) ''
        set -g @tmux-input-method-command '${inputMethod}'
        set -g @tmux-input-method-layout 'com.apple.keylayout.ABC'
      ''
    );
  };
}
