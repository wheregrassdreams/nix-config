{
  config,
  lib,
  pkgs,
  ...
}:
let
  picker = pkgs.writeShellApplication {
    name = "tmux-picker";
    runtimeInputs = [
      config.programs.tmux.package
      pkgs.fzf
      pkgs.coreutils
    ];
    text = builtins.readFile ./scripts/picker.sh;
  };
in
{
  config = {
    programs.tmux.extraConfig = lib.mkAfter ''
      bind f run-shell ${picker}/bin/tmux-picker
    '';
  };
}
