{ lib, ... }:
{
  options.my.terminal.rex = {
    enable = lib.mkEnableOption "Rex terminal multiplexer CLI and configuration";

    appBundles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Rex.app"
        "Rex Beta.app"
      ];
      description = ''
        Application bundle names under /Applications that may contain the Rex
        CLI, tried in order. Rex is a closed beta, so the bundle name changes
        between builds; add the new name here instead of hardcoding a path.
      '';
    };
  };
}
