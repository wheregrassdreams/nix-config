{ ... }:
let
  identity = {
    username = "zane";
    fullname = "Zane Lu";
    email = "lv2497712968@outlook.com";
  };
in
{
  system = "aarch64-darwin";
  outputType = "darwin";
  hostName = "moon";
  inherit identity;

  hostFacts = {
    network.proxyUrl = "http://proxy.wheregrassdreams.top:18080";
    # Keep Nix daemon downloads direct by default. Set true to route all daemon
    # initiated Nix downloads through the host proxy; see readme.md.
    network.nixDaemonProxyEnabled = false;
    deploy = {
      hostname = "macbook.wheregrassdreams.top";
      sshUser = identity.username;
      sshOpts = [
        "-A"
        "-o"
        "ControlMaster=no"
        "-o"
        "ControlPath=none"
        "-o"
        "ControlPersist=no"
        "-o"
        "HostKeyAlias=macbookm1air"
      ];
    };
  };

  systemModules = [ ./system.nix ];
  homeModules = [ ./home.nix ];
}
