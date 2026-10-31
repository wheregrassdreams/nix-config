{ lib, ... }:
{
  options.my.connectivity.clashVerge = {
    scriptProfile = lib.mkOption {
      type = lib.types.enum [ "tailnet" "custom-kernel" "disabled" ];
      default = "tailnet";
      description = ''
        Clash Verge script profile: the standard Tailnet rules, the custom
        Mihomo kernel integration, or no managed Script.js profile.
      '';
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Hostname advertised by the embedded Tailscale node";
    };

    tailnetDomain = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Tailnet DNS domain routed through the Clash policy group";
    };

    tailnetCidr = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Tailnet CIDR routed through the Clash policy group";
    };

    dnsUpstream = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "DNS upstream for the Tailnet domain";
    };
  };
}
