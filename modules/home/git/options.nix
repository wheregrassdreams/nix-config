{ lib, ... }:
{
  options.my.git = {
    gitea.enable = lib.mkEnableOption "Gitea CLI";
    github.enable = lib.mkEnableOption "GitHub CLI";
    gitlab.enable = lib.mkEnableOption "GitLab CLI";
    lazygit.enable = lib.mkEnableOption "Lazygit";
  };
}
