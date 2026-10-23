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
  brewTmux = "${config.my.homebrew.brewPrefix}/bin/tmux";
  tmuxPackage =
    if isDarwin then
      pkgs.writeShellScriptBin "tmux" ''exec ${lib.escapeShellArg brewTmux} "$@"''
    else
      pkgs.tmux;
  tmux = lib.getExe tmuxPackage;
in
{
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
      set-environment -g PATH ${lib.escapeShellArg "${config.home.profileDirectory}/bin:${config.my.homebrew.brewPrefix}/bin:${config.my.homebrew.brewPrefix}/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"}
      source-file -F "#{@tmux-config-root}/tmux.conf"
      # Continuum schedules automatic saves through this status format.
      set-option -ag status-right "#{continuum_save_status}"
    '';
  };

  home.activation.reconcileQuickpaneTmuxServers = lib.hm.dag.entryAfter [ "reloadTmux" ] ''
    if ${tmux} has-session 2>/dev/null; then
      ${tmuxConfig}/bin/quickpane-reconcile-all "$(${tmux} display-message -p '#{socket_path}')"
    fi
  '';
}
