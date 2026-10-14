{ config, lib, ... }:
let
  cfg = config.my.terminal.shell;
in
{
  config = lib.mkIf cfg.atuin.enable {
    assertions = [
      {
        assertion = cfg.zsh.enable;
        message = "my.terminal.shell.atuin.enable requires my.terminal.shell.zsh.enable";
      }
    ];

    # Home Manager loads Atuin after fzf, so Atuin owns Ctrl-R while fzf keeps
    # its file and completion widgets. The flag leaves up-arrow unchanged.
    programs.atuin = {
      enable = true;
      enableZshIntegration = true;
      flags = [ "--disable-up-arrow" ];
      settings.auto_sync = false;
    };
  };
}
