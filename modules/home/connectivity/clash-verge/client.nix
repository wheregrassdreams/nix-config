{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.connectivity.clashVerge;
  script = pkgs.writeText "clash-verge-tailnet.js" (
    builtins.replaceStrings
      [
        "__CLASH_VERGE_HOSTNAME__"
        "__CLASH_VERGE_STATE_DIR__"
        "__CLASH_VERGE_TAILNET_DOMAIN__"
        "__CLASH_VERGE_TAILNET_CIDR__"
        "__CLASH_VERGE_DNS_UPSTREAM__"
      ]
      [
        (builtins.toJSON cfg.hostname)
        (builtins.toJSON cfg.stateDir)
        (builtins.toJSON cfg.tailnetDomain)
        (builtins.toJSON cfg.tailnetCidr)
        (builtins.toJSON cfg.dnsUpstream)
      ]
      (builtins.readFile ./clash-verge-tailnet.js)
  );
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.hostname != "";
          message = "my.connectivity.clashVerge.hostname must be set when this package is imported";
        }
        {
          assertion = cfg.tailnetDomain != "";
          message = "my.connectivity.clashVerge.tailnetDomain must be set when this package is imported";
        }
        {
          assertion = cfg.tailnetCidr != "";
          message = "my.connectivity.clashVerge.tailnetCidr must be set when this package is imported";
        }
        {
          assertion = cfg.dnsUpstream != "";
          message = "my.connectivity.clashVerge.dnsUpstream must be set when this package is imported";
        }
      ];
    }
    {
      my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "clash-verge-rev" ];
      home.file."Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/profiles/Script.js".source =
        script;
    }
  ];
}
