{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.connectivity.clashVerge;
  replace = name: template: replacements:
    pkgs.writeText name (
      builtins.replaceStrings (map (entry: entry.placeholder) replacements)
        (map (entry: entry.value) replacements)
        (builtins.readFile template)
    );
  render = name: template: replacements:
    replace name template (
      map (entry: entry // { value = builtins.toJSON entry.value; }) replacements
    );
  script =
    if cfg.scriptProfile == "tailnet" then
      render "clash-verge-tailnet.js" ./clash-verge-tailnet.js [
        {
          placeholder = "__CLASH_VERGE_HOSTNAME__";
          value = cfg.hostname;
        }
        {
          placeholder = "__CLASH_VERGE_TAILNET_DOMAIN__";
          value = cfg.tailnetDomain;
        }
        {
          placeholder = "__CLASH_VERGE_TAILNET_CIDR__";
          value = cfg.tailnetCidr;
        }
        {
          placeholder = "__CLASH_VERGE_DNS_UPSTREAM__";
          value = cfg.dnsUpstream;
        }
      ]
    else if cfg.scriptProfile == "custom-kernel" then
      replace "custom-kernel-script.js" ./custom-kernel-script.js [
        {
          placeholder = "__CLASH_VERGE_SETTINGS__";
          value = builtins.toJSON {
            proxyName = "tsnet";
            hostname = cfg.hostname;
          };
        }
      ]
    else
      null;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.scriptProfile == "disabled" || cfg.hostname != "";
          message = "my.connectivity.clashVerge.hostname must be set when this package is imported";
        }
        {
          assertion = cfg.scriptProfile != "tailnet" || cfg.tailnetDomain != "";
          message = "my.connectivity.clashVerge.tailnetDomain must be set when this package is imported";
        }
        {
          assertion = cfg.scriptProfile != "tailnet" || cfg.tailnetCidr != "";
          message = "my.connectivity.clashVerge.tailnetCidr must be set when this package is imported";
        }
        {
          assertion = cfg.scriptProfile != "tailnet" || cfg.dnsUpstream != "";
          message = "my.connectivity.clashVerge.dnsUpstream must be set when this package is imported";
        }
      ];
    }
    {
      my.homebrew.casks = lib.mkIf pkgs.stdenv.isDarwin [ "clash-verge-rev" ];
      home.file."Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/profiles/Script.js" =
        lib.mkIf (cfg.scriptProfile != "disabled") { source = script; };
    }
  ];
}
