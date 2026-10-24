{
  config,
  lib,
  pkgs,
  ...
}:
let
  finder = pkgs.writeShellApplication {
    name = "tmux-window-finder";
    runtimeInputs = [
      config.programs.tmux.package
      pkgs.fzf
      pkgs.coreutils
    ];
    text = builtins.readFile ./scripts/finder.sh;
  };
in
{
  config = {
    programs.tmux.extraConfig = lib.mkAfter ''
      bind f run-shell ${finder}/bin/tmux-window-finder
    '';
  };
}
