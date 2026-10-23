{ pkgs, mylib, ... }:
{
  imports = mylib.importAll ./.;
  home.packages = [ pkgs.unstable.cc-switch ];
}
