{
  config,
  lib,
  pkgs,
  ...
}:
let
  tmux = "${pkgs.tmux}/bin/tmux";
  configFile = "${config.xdg.configHome}/tmux/tmux.conf";
  sessionVariables = [
    "PATH"
    "NIX_PROFILES"
    "NIX_PATH"
    "XDG_CONFIG_HOME"
    "XDG_DATA_HOME"
    "XDG_CACHE_HOME"
    "XDG_STATE_HOME"
    "SSH_AUTH_SOCK"
    "DISPLAY"
    "TERM"
    "TERM_PROGRAM"
  ];
  updateEnvironment = lib.concatStringsSep " " sessionVariables;
  setGlobalEnvironment = lib.concatMapStringsSep "\n" (name: ''
    ${tmux} set-environment -g ${name} "''${${name}-}"
  '') sessionVariables;
in
{
  config = {
    programs.tmux.extraConfig = lib.mkAfter ''
      set -g update-environment "${updateEnvironment}"
    '';

    home.activation.reloadTmux = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if ${tmux} has-session 2>/dev/null; then
        echo "Reloading tmux configuration from ${configFile}" >&2
        ${setGlobalEnvironment}
        ${tmux} source-file ${lib.escapeShellArg configFile}
        if ! ${tmux} list-keys -T prefix h 2>/dev/null | ${pkgs.gnugrep}/bin/grep -Fq 'select-pane -L'; then
          echo "tmux configuration reload did not install the expected prefix+h binding" >&2
          exit 1
        fi
        echo "tmux configuration reloaded and verified" >&2
      else
        echo "Skipping tmux configuration reload: no accessible tmux session" >&2
      fi
    '';
  };
}
