{ lib, ... }:
{
  options.my.terminal.tmux.inputMethod.command = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Optional command used to switch input methods from tmux.";
  };
}
