{ pkgs, repoLib, ... }:
{
  imports = repoLib.importAll ./.;
  home.packages = [ pkgs.unstable.cc-switch ];
}
