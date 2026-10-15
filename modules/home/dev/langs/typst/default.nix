{ pkgs, ... }:
{
  home.packages = with pkgs; [
    tinymist
    unstable.typst
  ];
}
