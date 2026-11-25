{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.ai.fork-pane;

  forkPane = pkgs.writeShellApplication {
    name = "fork-pane";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      tmux
    ];
    text = builtins.readFile ./scripts/fork-pane;
  };

  codexForkHook = pkgs.writeShellApplication {
    name = "codex-fork-hook";
    runtimeInputs = [
      forkPane
      pkgs.jq
    ];
    text = builtins.readFile ./scripts/codex-fork-hook;
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      forkPane
      codexForkHook
    ];
  };
}
