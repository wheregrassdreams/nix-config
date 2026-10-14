{
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
      zsh.enable = true;
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
    dev.langs = {
      nix.enable = true;
      python.enable = true;
      python.suite = "minimal";
      clang.enable = true;
      clang.opengl.enable = false;
      javascript.enable = false;
      go.enable = false;
      rust.enable = false;
    };
  };

  # home.sessionVariables is skipped when an inherited shell has already
  # sourced a previous Home Manager generation. Zsh loads this before plugins.
  programs.zsh.envExtra = lib.mkAfter ''
    export ZSH_SYSTEM_CLIPBOARD_USE_WL_CLIPBOARD=1
  '';
}
