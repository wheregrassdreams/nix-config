{ lib, ... }:
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
{
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
}
