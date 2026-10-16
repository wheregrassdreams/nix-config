{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.ai.opencode.cli;
in
{
  config = lib.mkIf cfg.enable {
    programs.opencode = {
      enable = true;
      package = pkgs.latestAgents.opencode;
    };
  };
}
