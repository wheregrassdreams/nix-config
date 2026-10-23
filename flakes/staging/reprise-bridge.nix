{ inputs, lib }:
{
  config,
  hostName,
  pkgs,
  ...
}:
let
  targetId = config.my.staging.reprise.remote.target;
  targetTools = import ../../modules/home/storage/remote/lib/targets.nix { inherit lib; };
  clients = import ../../modules/home/storage/remote/lib/clients.nix { inherit lib pkgs; };
  target = if targetId == null then null else targetTools.find config targetId;
  gitClient = clients.git target;
  gitTarget = if gitClient.sshHost == null then null else gitClient;
  resolvedRemote =
    if gitTarget == null then
      null
    else
      {
        kind = target.provisioner.kind;
        sshHost = gitTarget.sshHost;
        root = if gitTarget.root == null then "" else gitTarget.root;
        giteaApiUrl = target.provisioner.gitea.apiUrl or "";
        giteaOrganization = target.provisioner.gitea.organization or "";
        giteaTokenFile = target.provisioner.gitea.tokenFile or "";
        giteaRepository = target.provisioner.gitea.repository or "";
      };
in
{
  imports = [ inputs.staging-reprise.homeManagerModules.default ];

  config = {
    my.staging.reprise = {
      hostId = hostName;
      xdgDataHome = config.xdg.dataHome;
      xdgStateHome = config.xdg.stateHome;
      remote.resolved = resolvedRemote;
    };

    my.paths.exported."staging.reprise.snapshots" = config.my.staging.reprise.snapshotDirectory;

    assertions = [
      {
        assertion = targetId == null || target != null;
        message = "my.staging.reprise.remote.target must name a declared my.storage.remote.targets entry.";
      }
      {
        assertion = targetId == null || gitTarget != null;
        message = "Reprise snapshots require a Git remote target.";
      }
      {
        assertion =
          targetId == null
          || builtins.elem target.provisioner.kind [
            "sshBare"
            "gitea"
            "giteaPreprovisioned"
          ];
        message = "Reprise supports sshBare, gitea, or giteaPreprovisioned snapshot targets.";
      }
    ];
  };
}
