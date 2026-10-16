{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.desktop.files.disktree.enable {
    home.packages = [ pkgs.disktree ];
    home.file."Applications/disktree.app".source = "${pkgs.disktree}/Applications/disktree.app";
  };
}
