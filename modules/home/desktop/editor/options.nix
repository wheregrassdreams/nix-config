{ config, lib, ... }:
let
  cfg = config.my.desktop.editor;
in
{
  options.my.desktop.editor = {
    default = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "zed"
          "vscode"
        ]
      );
      default = null;
      description = "Application key for source and structured text files";
    };
    zed.enable = lib.mkEnableOption "Zed editor";
    vscode.enable = lib.mkEnableOption "Visual Studio Code";
  };

  config.assertions = [
    {
      assertion = cfg.default == null || cfg.${cfg.default}.enable;
      message = "my.desktop.editor.default must refer to an enabled editor";
    }
  ];
}
