{ lib, ... }:
/*
The following service options are paused for reevaluation.

let
  modeType = lib.types.nullOr (
    lib.types.enum [
      "external"
      "local-manual"
      "local-daemon"
    ]
  );
  serviceComponent = name: {
    enable = lib.mkEnableOption name;
    mode = lib.mkOption {
      type = modeType;
      default = null;
      description = "runtime mode for ${name}; null inherits services.defaultMode";
    };
    client.enable = lib.mkEnableOption "${name} client tools" // {
      default = true;
    };
  };
in
*/
{
  options.my.nix.cacheMirror = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "ustc"
        "tuna"
      ]
    );
    default = null;
    description = ''
      Optional mainland-China mirror of cache.nixos.org. The mirror serves
      cache.nixos.org content, so its signing key is unchanged.
    '';
  };

  options.my.ssh = {
    server = {
      enable = lib.mkEnableOption "an SSH server";

      authorizedKeys = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = { };
        description = ''
          Public keys grouped by local user for a future NixOS SSH server.
          Keys may be declared before the server is enabled.
        '';
      };
    };
  };

  /*
  options.my.services = {
    defaultMode = lib.mkOption {
      type = lib.types.enum [
        "external"
        "local-manual"
        "local-daemon"
      ];
      default = "external";
      description = "default lifecycle mode for enabled local services";
    };
    mysql = serviceComponent "MySQL";
    postgres = serviceComponent "PostgreSQL";
    redis = serviceComponent "Redis";
  };
  */
}
