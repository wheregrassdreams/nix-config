{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.ai.claude.cli;
in
{
  config = lib.mkIf cfg.enable {
    programs.claude-code = {
      enable = true;
      package = pkgs.latestAgents.claude-code;
    };
  };
}
