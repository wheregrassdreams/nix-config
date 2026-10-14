{ config, lib, ... }@ctx:
let
  cfg = config.my.tools;
  apply = path:
    let module = import path;
    in if builtins.isFunction module then module ctx else module;
  enabled = feature: path:
    lib.optional (cfg.enable && feature) (apply path);
in
{
  imports = [ ./options.nix ];
  config = lib.mkMerge (
    enabled cfg.core ./core.nix
    ++ enabled cfg.direnv ./direnv.nix
    ++ enabled cfg.query ./query.nix
    ++ enabled cfg.network ./network.nix
    ++ enabled cfg.workflow ./workflow.nix
    ++ enabled cfg.interactive ./interactive.nix
    ++ enabled cfg.television ./television.nix
    ++ enabled cfg.media ./media.nix
  );
}
