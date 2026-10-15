{ config, lib, ... }:
let
  cfg = config.my.ai.agentResources;
  skillsDirectory = ../../../../resources/agents/skills;
  entries = builtins.readDir skillsDirectory;
  managedSkills = lib.filterAttrs (
    name: type:
    type == "directory" && builtins.pathExists (skillsDirectory + "/${name}/SKILL.md")
  ) entries;
  skillLinks = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "agent-skill-${name}" {
      target = "${cfg.dataHome}/skills/${name}";
      source = skillsDirectory + "/${name}";
    }
  ) managedSkills;
in
{
  options.my.ai.agentResources.dataHome = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/.agents";
    description = "Home directory for shared agent skills and resource catalogs.";
  };

  config = {
    home.file = skillLinks;

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
