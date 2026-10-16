{
  flake,
  identity,
  lib,
  pkgs,
  ...
}:
let
  windowsOpen =
    name:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.wslu ];
      text = ''
        if [ "$#" -eq 1 ] && [ -e "$1" ]; then
          explorer.exe "$(wslpath -w -a "$1")" >/dev/null 2>&1 &
          exit 0
        fi

        exec wslview "$@"
      '';
    };
in
{
  imports = [
    flake.homeModules.core
    flake.homeModules.terminal
    flake.homeModules.git
    flake.homeModules."terminal.shell"
    flake.homeModules."terminal.tmux"
    flake.homeModules."terminal.tools"
    flake.homeModules."dev.kubernetes"
    flake.homeModules."dev.ci"
    flake.homeModules."dev.tools"
    flake.homeModules."dev.langs.c"
    flake.homeModules."dev.langs.nix"
    flake.homeModules."dev.langs.python"
    flake.homeModules."storage.remote"
    flake.homeModules."connectivity.ssh"
    flake.homeModules."connectivity.tailscale"
    flake.homeModules.services
  ];

  home = {
    stateVersion = "25.11";
    enableNixpkgsReleaseCheck = false;
    sessionVariables = {
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      BROWSER = "wslview";
      ZSH_SYSTEM_CLIPBOARD_USE_WL_CLIPBOARD = "1";
    };
    packages = [
      pkgs.wl-clipboard
      pkgs.wslu
      (windowsOpen "open")
      (windowsOpen "xdg-open")
    ];
  };

  my = {
    inherit identity;
    paths.personal.windows = "/mnt/c";

    terminal.shell = {
      prompt.enable = true;
      atuin.enable = true;
      direnv.enable = true;
    };
    terminal.tools = {
      television.enable = true;
    };
    git = {
      lazygit.enable = true;
      github.enable = true;
    };
    dev.langs.c.opengl.enable = false;
  };

  # home.sessionVariables is skipped when an inherited shell has already
  # sourced a previous Home Manager generation. Zsh loads this before plugins.
  programs.zsh.envExtra = lib.mkAfter ''
    export ZSH_SYSTEM_CLIPBOARD_USE_WL_CLIPBOARD=1
  '';
}
