{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.connectivity.tailscale;
  host = cfg.host;
  tailscale = pkgs.unstable.tailscale;
in
{
  config = lib.mkMerge [
    {
      home.packages = [ tailscale ];
    }
    (lib.mkIf pkgs.stdenv.isDarwin {
      my.homebrew.casks = [ "tailscale-app" ];
    })
    (lib.mkIf (host != "") {
      home.file.".local/bin/tailscale-self-dns" = {
        executable = true;
        text = ''
          actual="$(${tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -r '.Self.DNSName')"
          test -n "$actual" -a "$actual" != "null" || { echo 'Tailscale daemon unavailable' >&2; exit 1; }
          echo "$actual"
          test "$actual" = '${host}' || { echo "declared host: ${host}" >&2; exit 2; }
        '';
      };
    })
  ];
}
