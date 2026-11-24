const settings = __CLASH_VERGE_SETTINGS__;

function main(config) {
  const { proxyName, hostname } = settings;

  config.proxies = config.proxies || [];
  const node = {
    name: proxyName,
    type: "tailscale",
    hostname,
    // Keep this relative to Mihomo's -d HomeDir: absolute XDG paths are
    // rejected by Clash Verge/Mihomo's HomeDir and SAFE_PATHS checks.
    "state-dir": "./tailscale",
    udp: true,
    "accept-routes": true,
  };

  const i = config.proxies.findIndex((p) => p && p.name === proxyName);
  if (i < 0) config.proxies.push(node);
  else config.proxies[i] = { ...config.proxies[i], ...node };

  config.dns = config.dns || {};
  config.dns.enable = true;
  config.dns["prefer-tailscale"] = true;
  config.dns["tailscale-fallback"] = "sequential";

  // With redir-host there is no fake-IP to preserve the tailnet domain for
  // PREFERRED-BY, so the DNS answer must come from tsnet itself. Keep the
  // tsnet transport in the main nameserver list (not only nameserver-policy)
  // so prefer-tailscale records the answer source used by PREFERRED-BY.
  const nameservers = Array.isArray(config.dns.nameserver)
    ? config.dns.nameserver
    : typeof config.dns.nameserver === "string"
      ? [config.dns.nameserver]
      : [];
  const tailscaleNameserver = `tailscale://${proxyName}`;
  if (!nameservers.includes(tailscaleNameserver)) {
    nameservers.unshift(tailscaleNameserver);
  }
  config.dns.nameserver = nameservers;

  const rule = `PREFERRED-BY,${proxyName},${proxyName}`;
  config.rules = (config.rules || []).filter((r) => r !== rule);

  // PREFERRED-BY must run before the 100.64/10 DIRECT rule (and before
  // GEOIP/MATCH) or a real tailnet IP would bypass tsnet in redir-host mode.
  const priority = config.rules.findIndex(
    (r) =>
      /^IP-CIDR,100\.64\.0\.0\/10,/i.test(r) ||
      /^GEOIP,/i.test(r) ||
      /^(MATCH|FINAL),/i.test(r),
  );
  config.rules.splice(priority < 0 ? config.rules.length : priority, 0, rule);

  return config;
}
