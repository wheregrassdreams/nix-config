{ lib, ... }:
{
  options.my.desktop.files = {
    # baseline.enable = lib.mkEnableOption "file browsing baseline";
    # archiveExtraction.enable = lib.mkEnableOption "archive extraction integration";
    disktree.enable = lib.mkEnableOption "DiskTree filesystem usage browsing";
  };
}
