{ config, lib, ... }@ctx:
let
  cfg = config.my.shell;
  apply = path: extraArgs:
    let module = import path;
    in if builtins.isFunction module then module (ctx // extraArgs) else module;
  enabled = feature: path:
    lib.optional (cfg.enable && feature.enable)
      (apply path { feature = feature; });
in
{
  imports = [ ./options.nix ];
  config = lib.mkMerge (
    enabled cfg.zsh ./zsh/base.nix
    ++ enabled cfg.prompt ./prompt.nix
    ++ enabled cfg.integrations.macos ./macos.nix
    ++ enabled cfg.integrations.nixIndex ./nix-index.nix
  );
}
