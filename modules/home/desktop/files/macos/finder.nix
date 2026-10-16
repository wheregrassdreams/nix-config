{ config, lib, ... }:
let
  cfg = config.my.desktop.files.baseline;
in
{
  config = lib.mkIf cfg.enable {
    targets.darwin.defaults."com.apple.finder" = {
      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true;
      _FXSortFoldersFirstOnDesktop = true;
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
      ShowPathBar = true;
      ShowStatusBar = true;
    };
  };
}
