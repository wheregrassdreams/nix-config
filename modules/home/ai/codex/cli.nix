{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.ai.codex.cli.enable {
    programs.codex = {
      enable = true;
      package = pkgs.latestAgents.codex;
    };
  };
}
