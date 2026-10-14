{ config, lib, ... }@ctx:
let
  cfg = config.my.development;
  apply = path: extraArgs:
    let module = import path;
    in if builtins.isFunction module then module (ctx // extraArgs) else module;
  enabled = feature: path: extraArgs:
    lib.optional (cfg.enable && feature) (apply path extraArgs);
in
{
  imports = [ ./options.nix ];
  config = lib.mkMerge (
    lib.optional cfg.enable (apply ./common.nix { })
    ++ enabled cfg.lua.enable ./lua.nix { }
    ++ enabled cfg.nix.enable ./nix.nix { }
    ++ enabled cfg.go.enable ./go.nix { }
    ++ enabled cfg.javascript.enable ./javascript.nix { }
    ++ enabled cfg.rust.enable ./rust.nix { }
    ++ enabled cfg.clang.enable ./clang.nix { feature = cfg.clang; }
    ++ enabled cfg.haskell.enable ./haskell.nix { }
    ++ enabled cfg.python.enable ./python.nix { feature = cfg.python; }
  );
}
