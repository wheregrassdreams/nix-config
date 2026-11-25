{ lib, ... }:
{
  options.my.ai.codex.remote = {
    host = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "SSH host used by codex-remote instead of discovering a Tailscale peer.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "zane";
      description = "SSH user used by codex-remote.";
    };

    hostKeyAlias = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "SSH host key alias for the codex-remote destination.";
    };
  };
}
