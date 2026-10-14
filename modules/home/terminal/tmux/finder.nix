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
      pkgs.tmux
      pkgs.fzf
      pkgs.coreutils
    ];
    text = builtins.readFile ./scripts/finder.sh;
  };
in
{
  config = lib.mkIf (config.my.terminal.enable && config.my.terminal.tmux.enable) {
    programs.tmux.extraConfig = lib.mkAfter ''
      bind f run-shell ${finder}/bin/tmux-window-finder
    '';
  };
}
