{ lib, ... }:
{
  options.my.terminal.shell = {
    zsh = {
      enable = lib.mkEnableOption "portable Zsh shell";
      clipboard.enable = lib.mkEnableOption "system clipboard integration" // {
        default = true;
      };
    };
    prompt.enable = lib.mkEnableOption "shell prompt";
    atuin.enable = lib.mkEnableOption "Atuin shell history search";
    direnv.enable = lib.mkEnableOption "project environment loading with direnv";
    integrations = {
      macos.enable = lib.mkEnableOption "macOS shell conveniences";
      nixIndex.enable = lib.mkEnableOption "Nix command discovery";
    };
  };
}
