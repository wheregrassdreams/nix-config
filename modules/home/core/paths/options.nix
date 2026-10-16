{ config, lib, ... }:
let
  pathVariables = import ./lib/path-variables.nix { inherit lib; };
  cfg = config.my.paths;
  pathNames =
    builtins.attrNames (pathVariables {
      prefix = "NIX_CONFIG_PATH_";
      values = cfg.personal;
    })
    ++ builtins.attrNames (pathVariables {
      prefix = "NIX_CONFIG_PATH_";
      values = cfg.exported;
    });
  xdgNames = builtins.attrNames (pathVariables {
    prefix = "NIX_CONFIG_XDG_";
    values = cfg.xdg;
  });
  allNames = pathNames ++ xdgNames;
in
{
  options.my.paths = {
    home = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
    };
    configRepo = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
    };
    localBin = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
    };
    xdg = {
      config = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
      };
      data = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
      };
      cache = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
      };
      state = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
      };
    };
    personal = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Named personal and business locations";
    };
    exported = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Named path contracts contributed by selected capability packages";
    };
  };

  config.assertions = [
    {
      assertion = builtins.length allNames == builtins.length (lib.unique allNames);
      message = "my.paths.personal and my.paths.exported contain names that map to the same NIX_CONFIG_PATH_* or NIX_CONFIG_XDG_* environment variable";
    }
  ];
}
