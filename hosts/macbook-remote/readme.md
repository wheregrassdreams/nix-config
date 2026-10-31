# macbook-remote

This directory defines the remote Apple Silicon Mac host. `host.nix` owns its
machine facts, `system.nix` owns Darwin and system-daemon behavior, and
`home.nix` owns Zane's Home Manager environment and user LaunchAgents.

## Colima and Docker

Colima uses Apple's Virtualization framework (`vz`) with `virtiofs`. The VM has
2 CPUs, 2 GiB of memory, and a 100 GiB data disk. The user's home directory is
explicitly mounted writable; Colima interprets `mounts: null` as disabling
host mounts ([configuration reference](https://colima.run/docs/configuration/)).

The Docker CLI defaults to the `colima` context, which connects to the stable
`~/.colima/on-demand.sock` socket managed by launchd. A Docker API request
activates the headless proxy, starts Colima if needed, waits for the Docker API
to become ready, then forwards the request to Colima's normal socket. With no
active Docker client connections and no running containers, the proxy stops
Colima after 30 minutes and exits; launchd keeps the socket available for the
next request. Colima's initial VM image download receives the host proxy
variables. Commands that override the endpoint with `DOCKER_HOST` or connect
to Colima's raw socket bypass the wake proxy. Proxy logs are in
`~/Library/Logs/colima-on-demand.log`.

The CLI implementation is in `colima-on-demand.c`. Its lifecycle follows the
stable-socket proxy and conservative idle check used by
[ColimaBar](https://github.com/imohitkr/colima-bar), without its GUI or
application-managed socket: launchd owns socket activation, and the proxy
adopts that listener with `launch_activate_socket`.

## Proxy for Nix downloads

The host proxy URL is declared in `host.nix`. Nix downloads are performed by
the system-level Determinate Nix daemon, so proxy variables set only in a
user's shell or on the `nix` client do not automatically reach daemon-side
cache downloads.

`network.nixDaemonProxyEnabled` is intentionally `false`. For a one-off
prefetch/build, inject the proxy variables into a root Nix invocation; this
works for the remote host's local root-side build path:

```sh
sudo env \
  http_proxy=http://proxy.wheregrassdreams.top:18080 \
  https_proxy=http://proxy.wheregrassdreams.top:18080 \
  HTTP_PROXY=http://proxy.wheregrassdreams.top:18080 \
  HTTPS_PROXY=http://proxy.wheregrassdreams.top:18080 \
  nix build --accept-flake-config --no-link \
  '.#homeConfigurations."zane@macbook-remote".activationPackage'
```

Then activate user-level Home Manager changes as `zane`. To route all
daemon-initiated Nix downloads through the proxy, set
`network.nixDaemonProxyEnabled = true` in `host.nix` and activate the Darwin
system configuration. This opts the Determinate Nix LaunchDaemon into the
host's proxy environment; it affects all Nix downloads handled by that daemon.
