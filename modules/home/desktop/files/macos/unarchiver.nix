{ config, lib, ... }:
{
  config = lib.mkIf config.my.desktop.files.archiveExtraction.enable {
    my.homebrew.casks = [ "the-unarchiver" ];
  };
}
