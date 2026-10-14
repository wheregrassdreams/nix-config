{ config, lib, ... }@ctx:
let
  cfg = config.my.terminal;
  module = import ./tmux/default.nix;
  tmux = if builtins.isFunction module then module (ctx // { feature = cfg.tmux; }) else module;
  terminfoModule = import ./terminfo.nix;
  terminfo = if builtins.isFunction terminfoModule then terminfoModule ctx else terminfoModule;
in
{
  imports = [ ./options.nix ];
  config = lib.mkMerge [
    (lib.mkIf cfg.enable (terminfo.config or terminfo))
    (lib.mkIf (cfg.enable && cfg.tmux.enable) (tmux.config or tmux))
  ];
}
