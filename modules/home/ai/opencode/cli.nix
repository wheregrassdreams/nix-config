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
      package =
        if config.my.ai.opencode.cli.packageChannel == "latest" then
          pkgs.latestAgents.opencode
        else
          pkgs.opencode.overrideAttrs (_: {
            doInstallCheck = false;
          });
    };
  };
}
