{ lib, ... }:
{
  options.my.terminal = {
    enable = lib.mkEnableOption "terminal environment";
    tmux = {
      enable = lib.mkEnableOption "tmux";
      inputMethod.command = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional command used to switch input methods from tmux.";
      };
    };
  };
}
