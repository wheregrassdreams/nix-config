{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  codex = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  remote = config.my.ai.codex.remote;
  remoteEnvironment = lib.optionalString (remote.host != null) ''
    export CODEX_REMOTE_HOST="''${CODEX_REMOTE_HOST:-${lib.escapeShellArg remote.host}}"
    export CODEX_REMOTE_USER="''${CODEX_REMOTE_USER:-${lib.escapeShellArg remote.user}}"
    export CODEX_REMOTE_HOST_KEY_ALIAS="''${CODEX_REMOTE_HOST_KEY_ALIAS:-${
      lib.escapeShellArg (if remote.hostKeyAlias == null then remote.host else remote.hostKeyAlias)
    }}"
  '';

  codexRemote = pkgs.writeShellApplication {
    name = "codex-remote";
    runtimeInputs = [
      codex
      pkgs.curl
      pkgs.jq
      pkgs.openssh
      pkgs.unstable.tailscale
    ];
    text = remoteEnvironment + builtins.readFile ./scripts/codex-remote;
  };
in
{
  home.packages = [ codexRemote ];
}
