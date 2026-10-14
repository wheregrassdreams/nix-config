{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.my.tools.enable && config.my.tools.workflow) {
    home.packages = with pkgs; [
      # hurl
      sshpass
      act
      xh
      # entr
      just
      sttr
      tldr
      trash-cli
      clipboard-jh
      nur.repos.charmbracelet.gum
      # nur.repos.charmbracelet.mods
    ];
  };
}
