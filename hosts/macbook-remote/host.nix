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
  hostName = "macbookm1air";
  inherit identity;

  hostFacts = {
    network.proxyUrl = "http://proxy.wheregrassdreams.top:18080";
    deploy = {
      hostname = "macbook.wheregrassdreams.top";
      sshUser = identity.username;
      sshOpts = [
        "-A"
        "-S"
        "none"
        "-o"
        "ControlMaster=no"
        "-o"
        "HostKeyAlias=macbookm1air"
      ];
    };
  };

  systemModules = [ ./system.nix ];
  homeModules = [ ./home.nix ];
}
