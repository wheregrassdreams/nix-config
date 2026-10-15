{ pkgs, ... }:
{
  home.packages = [ pkgs.unstable.aerospace ];
  home.file."Applications/AeroSpace.app".source = "${pkgs.unstable.aerospace}/Applications/AeroSpace.app";
}
