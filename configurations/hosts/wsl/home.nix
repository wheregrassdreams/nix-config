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
    username = identity.username;
  };

  my = {
    inherit identity;
    paths.personal.windows = "/mnt/c";

    shell = {
      zsh.enable = true;
      prompt.enable = true;
    };
    tools = {
      core = true;
      direnv = true;
      query = true;
      network = true;
      workflow = true;
      interactive = true;
      television = true;
      media = false;
    };
    git = {
      lazygit.enable = true;
      github.enable = true;
    };
    development = {
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

  # WSLg provides Wayland, while zsh-system-clipboard otherwise prefers the
  # X11 path whenever DISPLAY is present. Windows handles URL and file opening.
  home = {
    packages = [
      pkgs.wl-clipboard
      pkgs.wslu
      (windowsOpen "open")
      (windowsOpen "xdg-open")
    ];
    sessionVariables = {
      BROWSER = "wslview";
      ZSH_SYSTEM_CLIPBOARD_USE_WL_CLIPBOARD = "1";
    };
  };

  # home.sessionVariables is skipped when an inherited shell has already
  # sourced a previous Home Manager generation. Zsh loads this before plugins.
  programs.zsh.envExtra = lib.mkAfter ''
    export ZSH_SYSTEM_CLIPBOARD_USE_WL_CLIPBOARD=1
  '';
}
