{ lib, ... }:
{
  options.my.connectivity.tailscale = {
    host = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Expected Tailnet MagicDNS host; set it to install the self-check helper";
    };
  };
}
