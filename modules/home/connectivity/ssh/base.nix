{
  config,
  lib,
  pkgs,
  ...
}:
let
  sshConfig = config.home.file.".ssh/config";
  managedStart = "# BEGIN HOME MANAGER MANAGED BLOCK";
  managedEnd = "# END HOME MANAGER MANAGED BLOCK";
  managedComment = "# Put personal Host or Match overrides above this block.";
  managedInclude = "Include ~/.ssh/config.d/home-manager.conf";
in
{
  config = {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = [ "~/.ssh/config.local" ];
      matchBlocks."*" = {
        forwardAgent = false;
        hashKnownHosts = true;
        serverAliveInterval = 30;
        serverAliveCountMax = 3;
        controlMaster = "auto";
        controlPath = "~/.ssh/control-%C";
        controlPersist = "30m";
        extraOptions.StrictHostKeyChecking = "ask";
      };
    };

    # Keep Home Manager's SSH model and renderer, but deploy its rendered text
    # as a drop-in instead of replacing the user's ~/.ssh/config.
    home.file.".ssh/config".enable = lib.mkForce false;
    home.file.".ssh/config.d/home-manager.conf".text = sshConfig.text;

    home.activation.updateSshConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${pkgs.bash}/bin/bash ${./scripts/update-config-section.sh} \
        "$HOME/.ssh/config" \
        ${lib.escapeShellArg managedStart} \
        ${lib.escapeShellArg managedEnd} \
        ${lib.escapeShellArg managedComment} \
        ${lib.escapeShellArg managedInclude}
    '';
  };
}
