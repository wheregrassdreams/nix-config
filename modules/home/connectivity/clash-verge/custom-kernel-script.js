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

  const rule = `PREFERRED-BY,${proxyName},${proxyName}`;
  config.rules = (config.rules || []).filter((r) => r !== rule);
  const fallback = config.rules.findIndex((r) => /^(MATCH|FINAL),/i.test(r));
  config.rules.splice(fallback < 0 ? config.rules.length : fallback, 0, rule);

  return config;
}
