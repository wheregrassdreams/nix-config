{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.ai.dsh-tui;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.dsh
      (pkgs.writeShellApplication {
        name = "dsh-tui";
        runtimeInputs = [ pkgs.dsh ];
        text = ''
          exec dsh --profile dsh-tui "$@"
        '';
      })
    ];
  };
}
