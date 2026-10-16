{ config, lib, ... }:
let
  cfg = config.my.desktop.terminal;
in
{
  options.my.desktop.terminal = {
    default = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "ghostty"
          "kitty"
        ]
      );
      default = null;
      description = "Application key for the default terminal";
    };
    ghostty.enable = lib.mkEnableOption "Ghostty";
    kitty.enable = lib.mkEnableOption "Kitty";
  };

  config.assertions = [
    {
      assertion = cfg.default == null || cfg.${cfg.default}.enable;
      message = "my.desktop.terminal.default must refer to an enabled terminal";
    }
  ];
}
