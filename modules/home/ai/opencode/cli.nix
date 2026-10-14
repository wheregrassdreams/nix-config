{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.ai.opencode.cli.enable {
    programs.opencode = {
      enable = true;
      package = pkgs.latestAgents.opencode;
    };
  };
}
