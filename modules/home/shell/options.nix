{ lib, ... }:
{
  options.my.shell = {
    enable = lib.mkEnableOption "shell environment";
    zsh = {
      enable = lib.mkEnableOption "portable Zsh shell";
      clipboard.enable = lib.mkEnableOption "system clipboard integration" // { default = true; };
    };
    prompt.enable = lib.mkEnableOption "shell prompt";
    integrations = {
      macos.enable = lib.mkEnableOption "macOS shell conveniences";
      nixIndex.enable = lib.mkEnableOption "Nix command discovery";
    };
  };
}
