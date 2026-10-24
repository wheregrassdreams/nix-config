{
  hostName,
  lib,
  pkgs,
  self,
  userName,
  ...
}:
{
  imports = [ self.darwinModules.platform ];

  config = {
    nixpkgs.hostPlatform = "aarch64-darwin";
    networking.hostName = hostName;
    networking.computerName = hostName;
    networking.localHostName = hostName;

    users.users.${userName}.home = "/Users/${userName}";
    system.primaryUser = userName;
    system.stateVersion = 5;
    time.timeZone = "Asia/Shanghai";

    environment.systemPackages = [
      pkgs.jq
      pkgs.tailscale
    ];
    environment.etc."sudoers.d/90-zane-deploy".text = "${userName} ALL=(ALL:ALL) NOPASSWD: ALL\n";

    # The remote Mac runs the CLI daemon as a system LaunchDaemon.
    launchd.daemons.tailscaled.serviceConfig = {
      Label = "com.tailscale.tailscaled";
      ProgramArguments = [
        "${pkgs.tailscale}/bin/tailscaled"
        "--state=/var/db/tailscale/tailscaled.state"
        "--tun=utun"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
      StandardOutPath = "/var/log/tailscaled.log";
      StandardErrorPath = "/var/log/tailscaled.log";
    };

    system.activationScripts.postActivation.text = lib.mkAfter ''
      /usr/bin/install -d -o root -g wheel -m 0700 /var/db/tailscale
    '';
  };
}
