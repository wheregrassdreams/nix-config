{ config, lib, ... }:
let
  cfg = config.my.agentResources;
in
{
  options.my.agentResources.dataHome = lib.mkOption {
    type = lib.types.str;
    default = ".agents/";
    description = "Shared runtime directory used by agent applications and their resources.";
  };

  config = {
    home.sessionVariables = {
      AI_AGENT_HOME = cfg.dataHome;
      AI_AGENT_SKILLS_DIR = "${cfg.dataHome}/skills";
      AI_AGENT_MCP_DIR = "${cfg.dataHome}/mcp";
    };

    home.activation.createAgentResourceDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg cfg.dataHome}/skills ${lib.escapeShellArg cfg.dataHome}/mcp
    '';
  };
}
