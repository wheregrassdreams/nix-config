{ config, lib, ... }:
let
  cfg = config.my.desktop.files.archiveExtraction;
in
{
  config = lib.mkIf cfg.enable {
    my.homebrew.casks = [ "the-unarchiver" ];
  };
}
