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
      package =
        if config.my.ai.codex.cli.packageChannel == "latest" then pkgs.latestAgents.codex else pkgs.codex;
    };
  };
}
