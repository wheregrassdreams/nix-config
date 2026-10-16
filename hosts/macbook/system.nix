{ hostName, pkgs, self, userName, ... }:
{
  imports = [ self.darwinModules.platform ];

  config = {
    fonts.packages = [ pkgs.unstable.nerd-fonts.jetbrains-mono ];

    home-manager.backupFileExtension = "hm-backup";
    system.stateVersion = 5;
    system.primaryUser = userName;
    networking.hostName = hostName;
    time.timeZone = "Asia/Shanghai";

    system.keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = false;
      remapCapsLockToEscape = false;
      nonUS.remapTilde = true;
    };

    system.startup.chime = false;
  };
}
