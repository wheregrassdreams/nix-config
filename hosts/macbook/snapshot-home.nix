{
  config,
  flake,
  identity,
  lib,
  ...
}:
{
  imports = [
    flake.homeModules.core
    flake.homeModules."dev.projects"
    flake.homeModules."storage.remote"
    flake.homeModules."connectivity.ssh"
  ];

  home.stateVersion = "25.11";

  sops.secrets = lib.mkIf (builtins.pathExists ../../secrets/users/remote-backups.yaml) {
    "backup/gitea-ssh-private-key" = {
      sopsFile = ../../secrets/users/remote-backups.yaml;
      key = "backup/gitea-ssh-private-key";
      path = "${config.home.homeDirectory}/.config/nix-config/secrets/backup-gitea-ssh-key";
      mode = "0400";
    };
  };

  my = {
    inherit identity;
    paths.personal.projects = "${config.home.homeDirectory}/Workspace/code/projects";
    storage.remote.targets.homelab-gitea-backups = {
      backend.git.sshHost = "gitea-backups";
      provisioner = {
        kind = "giteaPreprovisioned";
        gitea.repository = "homelab-backups/nix-config-snapshots";
      };
    };
    dev.projects.snapshots.remote.target = "homelab-gitea-backups";
  };
}
