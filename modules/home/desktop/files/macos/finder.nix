{ ... }:
{
  # TODO: 可以封装一个高抽象的简单的options接口
  config = {
    targets.darwin.defaults."com.apple.finder" = {
      _FXShowPosixPathInTitle = true;
      # _FXSortFoldersFirst = true;
      _FXSortFoldersFirstOnDesktop = true;
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
      ShowPathBar = true;
      ShowStatusBar = true;
      AppleShowAllFiles = false; # don't show hiden files to make it cleaner
      CreateDesktop = false;
      FXDefaultSearchScope = "SCcf";
      FXPreferredViewStyle = "Nlsv";
      FXRemoveOldTrashItems = true;
      NewWindowTarget = "Desktop";
      ShowExternalHardDrivesOnDesktop = false;
      ShowHardDrivesOnDesktop = false;
      ShowMountedServersOnDesktop = false;
      ShowRemovableMediaOnDesktop = false;

    };
  };
}
