{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs = {
    bat = {
      enable = true;
      config = {
        color = "auto";
        pager = "less";
        paging = "never";
        map-syntax = [ ".ignore:.gitignore" ];
      };
    };
    eza = {
      enable = true;
      icons = "auto";
      colors = "auto";
      git = true;
      enableZshIntegration = true;
    };
  };

  home.packages = [ pkgs.timg ];

  config = lib.mkIf (!config.my.terminal.tools.minimal) {
    programs.fastfetch.enable = true;
    programs.btop.enable = true;
    home.packages = with pkgs; [
      dust
      procs
      tokei
    ];
  };
}
