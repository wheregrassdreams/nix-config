{ lib, pkgs, ... }:
{
  config = lib.mkIf pkgs.stdenv.isDarwin {
    home.file."Applications/CC Switch.app".source = "${pkgs.unstable.cc-switch}/Applications/CC Switch.app";
  };
}
