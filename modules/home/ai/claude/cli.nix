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
      package =
        if config.my.ai.claude.cli.packageChannel == "latest" then
          pkgs.latestAgents.claude-code
        else
          pkgs.claude-code;
    };
  };
}
