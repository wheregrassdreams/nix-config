{ ... }:
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
      matchBlocks.gitea-backups = {
        hostname = "ssh.gitea.wheregrassdreams.top";
        port = 30222;
        user = "git";
        identityFile = "~/.config/nix-config/secrets/backup-gitea-ssh-key";
        identitiesOnly = true;
      };
    };
  };
}
