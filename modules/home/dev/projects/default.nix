{
  config,
  inputs,
  hostName,
  isDarwin,
  lib,
  pkgs,
  mylib,
  ...
}:
let
  cfg = config.my.dev.projects;
  paths = config.my.paths;
  remote = import ../../storage/remote/lib/targets.nix { inherit lib; };
  clients = import ../../storage/remote/lib/clients.nix { inherit lib pkgs; };
  target =
    if cfg.snapshots.remote.target == null then
      null
    else
      remote.find config cfg.snapshots.remote.target;
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
  imports =
    lib.optionals (!isDarwin) [ ./options.nix ]
    ++ [
      (mylib.assertPlatform {
        package = "dev.projects";
        platforms = [
          "darwin"
          "linux"
        ];
      })
    ]
    ++ lib.optionals isDarwin (mylib.importAll ./.)
    ++ [ inputs.staging-reprise.homeManagerModules.default ];

  config = {
    my.staging.reprise = {
      projectsPath = paths.personal.projects;
      inactiveAfterDays = cfg.inactiveAfterDays;
      snapshotDirectory = cfg.snapshots.directory;
      retentionDays = cfg.snapshots.retentionDays;
      hostId = hostName;
      xdgDataHome = config.xdg.dataHome;
      xdgStateHome = config.xdg.stateHome;
      remote = resolvedRemote;
    };

    my.paths.exported."dev.projects.snapshots" = cfg.snapshots.directory;

    assertions = [
      {
        assertion = cfg.snapshots.remote.target == null || target != null;
        message = "my.dev.projects.snapshots.remote.target must name a declared my.storage.remote.targets entry.";
      }
      {
        assertion = cfg.snapshots.remote.target == null || gitTarget != null;
        message = "my.dev.projects snapshots require a Git remote target.";
      }
      {
        assertion =
          cfg.snapshots.remote.target == null
          || builtins.elem target.provisioner.kind [
            "sshBare"
            "gitea"
            "giteaPreprovisioned"
          ];
        message = "my.dev.projects requires provisioner.kind = sshBare, gitea, or giteaPreprovisioned.";
      }
    ];
  };
}
