{
  hostFacts,
  hostName,
  lib,
  pkgs,
  self,
  userName,
  ...
}:
let
  ensureXcodeCommandLineTools = pkgs.writeShellScript "macbook-remote-ensure-xcode-clt" ''
    set -eu

    # Respect a complete Xcode install or an already working CLT selection.
    unset DEVELOPER_DIR SDKROOT NIX_APPLE_SDK_VERSION || true
    if /usr/bin/xcrun --sdk macosx --find clang >/dev/null 2>&1 \
      && /usr/bin/xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
      exit 0
    fi

    marker=/private/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    created_marker=0
    if [ ! -e "$marker" ]; then
      /usr/bin/touch "$marker"
      created_marker=1
    fi
    cleanup() {
      if [ "$created_marker" -eq 1 ]; then
        /bin/rm -f "$marker"
      fi
    }
    trap cleanup EXIT

    updates=$(/usr/sbin/softwareupdate --list 2>&1) || {
      printf '%s\n' "$updates" >&2
      echo "Could not query Apple Software Update for Xcode Command Line Tools." >&2
      exit 1
    }
    label=$(printf '%s\n' "$updates" \
      | /usr/bin/sed -nE 's/.*Label: (Command Line Tools for Xcode-[0-9][0-9.]*).*/\1/p' \
      | /usr/bin/tail -n 1)

    if [ -z "$label" ]; then
      printf '%s\n' "$updates" >&2
      echo "No compatible Xcode Command Line Tools update was listed by Apple Software Update." >&2
      exit 1
    fi

    echo "Installing $label from Apple Software Update."
    /usr/sbin/softwareupdate --install "$label" --agree-to-license
    /usr/bin/xcode-select --switch /Library/Developer/CommandLineTools

    if ! /usr/bin/xcrun --sdk macosx --find clang >/dev/null 2>&1 \
      || ! /usr/bin/xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
      echo "Xcode Command Line Tools installation completed, but xcrun still cannot use the macOS SDK." >&2
      exit 1
    fi
  '';
in
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

    # Keep the remote Mac reachable. System sleep drops the Tailnet peer, so
    # tsnet SSH/DNS dials to this host time out until it wakes again.
    power.sleep = {
      computer = "never";
      display = "never";
      harddisk = "never";
    };

    environment.systemPackages = [
      pkgs.jq
      pkgs.tailscale
    ];
    environment.etc."sudoers.d/90-zane-deploy".text = "${userName} ALL=(ALL:ALL) NOPASSWD: ALL\n";

    # Apple ships CLT outside Nix. Provision it only when the active developer
    # tools cannot resolve clang and the macOS SDK, before the rest of activation.
    system.activationScripts.preActivation.text = lib.mkBefore ''
      ${ensureXcodeCommandLineTools}
    '';

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

    # Determinate Nix downloads run in its system LaunchDaemon, so proxy
    # variables supplied only to a user's `nix` command do not reach them.
    # Keep this opt-in disabled unless all daemon-side downloads should use the
    # host proxy. Enabling it makes nix-darwin manage the daemon's LaunchDaemon
    # environment and requires a Darwin system activation.
    launchd.daemons."systems.determinate.nix-daemon" = lib.mkIf hostFacts.network.nixDaemonProxyEnabled {
      serviceConfig = {
        Label = "systems.determinate.nix-daemon";
        ProgramArguments = [ "/usr/local/bin/determinate-nixd" "daemon" ];
        RunAtLoad = true;
        HardResourceLimits = {
          NumberOfFiles = 1048576;
          NumberOfProcesses = 1048576;
          Stack = 67108864;
        };
        SoftResourceLimits = {
          NumberOfFiles = 1048576;
          NumberOfProcesses = 1048576;
          Stack = 67108864;
        };
        Sockets = {
          "determinate-nixd.socket" = {
            SockFamily = "Unix";
            SockPassive = true;
            SockPathName = "/var/run/determinate-nixd.socket";
          };
          "nix-daemon.socket" = {
            SockFamily = "Unix";
            SockPassive = true;
            SockPathName = "/var/run/nix-daemon.socket";
          };
        };
        EnvironmentVariables = {
          HTTP_PROXY = hostFacts.network.proxyUrl;
          HTTPS_PROXY = hostFacts.network.proxyUrl;
          http_proxy = hostFacts.network.proxyUrl;
          https_proxy = hostFacts.network.proxyUrl;
        };
        StandardOutPath = "/var/log/determinate-nix-daemon.log";
        StandardErrorPath = "/var/log/determinate-nix-daemon.log";
      };
    };

    system.activationScripts.postActivation.text = lib.mkAfter ''
      /usr/bin/install -d -o root -g wheel -m 0700 /var/db/tailscale
    '';
  };
}
