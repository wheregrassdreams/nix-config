{
  config,
  lib,
  pkgs,
  repoLib,
  ...
}:
let
  cfg = config.my.desktop.terminal.ghostty;
  tmux = lib.getExe pkgs.tmux;
  tmuxConfig = "${config.xdg.configHome}/tmux/tmux.conf";
in
{
  imports = [
    (repoLib.assertPlatform {
      package = "desktop.terminal.ghostty";
      platforms = [ "darwin" ];
      when = [
        "my"
        "desktop"
        "terminal"
        "ghostty"
        "enable"
      ];
    })
  ];

  config = lib.mkIf cfg.enable {
    my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "ghostty" ];
    xdg.configFile."ghostty/config".text = ''
      ${builtins.readFile ./config}
      initial-command = ${tmux} -f ${lib.escapeShellArg tmuxConfig} attach-session || ${tmux} -f ${lib.escapeShellArg tmuxConfig} new-session
    '';
    xdg.configFile."ghostty/shaders".source = ./shaders;
  };
}
