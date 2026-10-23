{
  config,
  isDarwin,
  lib,
  pkgs,
  tmuxConfig,
  ...
}:
let
  tmuxConfigRoot = "${tmuxConfig}/libexec/tmux-config";
  tmuxConfigFile = "${config.xdg.configHome}/tmux/tmux.conf";
  brewTmux = "${config.my.homebrew.brewPrefix}/bin/tmux";
  tmuxPackage =
    if isDarwin then
      pkgs.writeShellScriptBin "tmux" ''exec ${lib.escapeShellArg brewTmux} "$@"''
    else
      pkgs.tmux;
  tmux = lib.getExe tmuxPackage;
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
  setGlobalEnvironment = lib.concatMapStringsSep "\n" (name: ''
    ${tmux} set-environment -g ${name} "''${${name}-}"
  '') sessionVariables;
  startTmux = pkgs.writeShellApplication {
    name = "start-tmux-server";
    text = ''
      if ${tmux} info >/dev/null 2>&1; then
        ${tmux} source-file ${lib.escapeShellArg tmuxConfigFile}
      else
        ${tmux} -f ${lib.escapeShellArg tmuxConfigFile} start-server
      fi
    '';
  };
in
{
  my.paths.exported."staging.tmux-config.resurrect" = "${config.xdg.dataHome}/tmux/resurrect";

  home.packages = [
    tmuxConfig
    pkgs.unstable.fzf
  ];

  programs.zsh.initContent = lib.mkAfter ''
    source ${tmuxConfigRoot}/shell/prompt-cursor.zsh
  '';

  programs.tmux = {
    package = tmuxPackage;
    extraConfig = lib.mkAfter ''
      set-option -g @tmux-config-root ${lib.escapeShellArg tmuxConfigRoot}
      set -g update-environment "${lib.concatStringsSep " " sessionVariables}"
      set-environment -g PATH ${lib.escapeShellArg "${config.home.profileDirectory}/bin:${config.my.homebrew.brewPrefix}/bin:${config.my.homebrew.brewPrefix}/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"}
      source-file -F "#{@tmux-config-root}/tmux.conf"
      # Continuum schedules automatic saves through this status format.
      set-option -ag status-right "#{continuum_save_status}"
    '';
  };

  home.activation.reloadStagingTmux = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if ${tmux} has-session 2>/dev/null; then
      echo "Reloading tmux configuration from ${tmuxConfigFile}" >&2
      ${setGlobalEnvironment}
      ${tmux} source-file ${lib.escapeShellArg tmuxConfigFile}
      if ! ${tmux} list-keys -T prefix h 2>/dev/null | ${pkgs.gnugrep}/bin/grep -Fq 'select-pane -L'; then
        echo "tmux configuration reload did not install the expected prefix+h binding" >&2
        exit 1
      fi
      echo "tmux configuration reloaded" >&2
    else
      echo "Skipping tmux configuration reload: no accessible tmux session" >&2
    fi
  '';

  home.activation.reconcileQuickpaneTmuxServers = lib.hm.dag.entryAfter [ "reloadStagingTmux" ] ''
    if ${tmux} has-session 2>/dev/null; then
      ${tmuxConfig}/bin/quickpane-reconcile-all "$(${tmux} display-message -p '#{socket_path}')"
    fi
  '';

  launchd.agents.tmux = lib.mkIf isDarwin {
    enable = true;
    config = {
      Label = "org.nix-config.tmux";
      ProgramArguments = [ (lib.getExe startTmux) ];
      ProcessType = "Background";
      RunAtLoad = true;
    };
  };
}
