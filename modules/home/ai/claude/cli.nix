{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.ai.claude.cli.enable {
    programs.claude-code = {
      enable = true;
      package = pkgs.latestAgents.claude-code;
    };
  };
}
