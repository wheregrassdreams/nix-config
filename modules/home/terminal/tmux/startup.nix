{
  config,
  lib,
  pkgs,
  ...
}:
let
  tmux = lib.getExe config.programs.tmux.package;
  tmuxConfig = "${config.xdg.configHome}/tmux/tmux.conf";
  startTmux = pkgs.writeShellApplication {
    name = "start-tmux-server";
    # LaunchAgent does not inherit the interactive shell's PATH. Keep tmux in
    # the server environment so run-shell scripts can invoke the tmux CLI.
    runtimeInputs = [ config.programs.tmux.package ];
    text = ''
      if ${tmux} info >/dev/null 2>&1; then
        ${tmux} source-file ${lib.escapeShellArg tmuxConfig}
      else
        ${tmux} -f ${lib.escapeShellArg tmuxConfig} start-server
      fi
    '';
  };
in
{
  config = lib.mkIf pkgs.stdenv.isDarwin {
    launchd.agents.tmux = {
      enable = true;
      config = {
        Label = "org.nix-config.tmux";
        ProgramArguments = [ (lib.getExe startTmux) ];
        ProcessType = "Background";
        RunAtLoad = true;
      };
    };
  };
}
