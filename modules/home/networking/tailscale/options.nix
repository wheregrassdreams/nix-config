{ lib, ... }:
{
  options.my.connectivity.tailscale = {
    host = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Tailnet MagicDNS host for this machine";
    };
  };
}
