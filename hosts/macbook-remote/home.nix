{
  config,
  flake,
  hostFacts,
  identity,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  codex = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  homeDirectory = config.home.homeDirectory;
  proxyUrl = hostFacts.network.proxyUrl;
  githubTokenPath = config.sops.secrets."github/token".path;
  githubCredentialHelper = pkgs.writeShellScript "gh-git-credential" ''
    export GH_TOKEN="$(<${githubTokenPath})"
    exec ${pkgs.gh}/bin/gh auth git-credential "$@"
  '';
  codexRemoteAppServer = pkgs.writeShellScript "codex-remote-app-server" ''
    if [[ ! -r ${lib.escapeShellArg githubTokenPath} ]]; then
      echo "codex-remote-app-server: GitHub token secret is unavailable" >&2
      exit 1
    fi
    export GH_TOKEN="$(<${lib.escapeShellArg githubTokenPath})"
    exec ${codex}/bin/codex app-server --listen ws://127.0.0.1:45231
  '';
  colimaOnDemand = pkgs.stdenv.mkDerivation {
    pname = "colima-on-demand";
    version = "1.0.0";
    src = ./colima-on-demand.c;
    dontUnpack = true;
    buildPhase = ''
      runHook preBuild
      $CC -std=c11 -Wall -Wextra -Werror -pthread "$src" -o colima-on-demand
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 colima-on-demand "$out/bin/colima-on-demand"
      runHook postInstall
    '';
  };
  colimaDockerSocket = "${homeDirectory}/.colima/on-demand.sock";
in
{
  imports = [
    flake.homeModules.core
    flake.homeModules.terminal
    flake.homeModules."terminal.shell"
    flake.homeModules."terminal.tools"
    flake.homeModules.git
    flake.homeModules."connectivity.ssh"
    flake.homeModules."ai.codex"
    flake.homeModules."dev.tools"
    flake.homeModules."dev.langs.go"
    flake.homeModules."dev.langs.javascript"
    flake.homeModules."dev.langs.nix"
    flake.homeModules."dev.langs.python"
    flake.homeModules."dev.langs.rust"
    flake.homeModules."dev.langs.shell"
  ];

  home.stateVersion = "25.11";
  home.enableNixpkgsReleaseCheck = false;
  home.packages = [
    pkgs.gh
    pkgs.unstable.colima
    pkgs.docker-client
  ];

  home.file.".colima/default/colima.yaml".text = ''
    arch: host
    runtime: docker
    cpu: 2
    memory: 2
    disk: 100
    vmType: vz
    mountType: virtiofs
    mounts:
      - location: ${homeDirectory}
        writable: true
    autoActivate: false
  '';

  programs.docker-cli = {
    enable = true;
    contexts.colima = {
      Metadata.Description = "On-demand Colima Docker engine";
      Endpoints.docker.Host = "unix://${colimaDockerSocket}";
    };
    settings.currentContext = "colima";
  };

  launchd.agents.colima = {
    enable = true;
    config = {
      Label = "dev.wheregrassdreams.colima";
      ProgramArguments = [
        "${colimaOnDemand}/bin/colima-on-demand"
        "--colima"
        "${pkgs.unstable.colima}/bin/colima"
        "--docker"
        "${pkgs.docker-client}/bin/docker"
        "--upstream"
        "${homeDirectory}/.colima/default/docker.sock"
        "--idle-seconds"
        "1800"
      ];
      Sockets.DockerOnDemand = {
        SockPassive = true;
        SockPathName = colimaDockerSocket;
        SockPathMode = 384;
        SockType = "stream";
      };
      EnvironmentVariables = {
        COLIMA_HOME = "${homeDirectory}/.colima";
        HOME = homeDirectory;
        HTTP_PROXY = proxyUrl;
        HTTPS_PROXY = proxyUrl;
        http_proxy = proxyUrl;
        https_proxy = proxyUrl;
        PATH = lib.makeBinPath [
          pkgs.unstable.colima
          pkgs.docker-client
        ] + ":/usr/bin:/bin:/usr/sbin:/sbin";
      };
      RunAtLoad = false;
      StandardOutPath = "${homeDirectory}/Library/Logs/colima-on-demand.log";
      StandardErrorPath = "${homeDirectory}/Library/Logs/colima-on-demand.log";
    };
  };

  sops.secrets."github/token" = {
    sopsFile = ../../secrets/hosts/macbook-remote.yaml;
    mode = "0400";
  };

  sops.secrets."gitea/token" = {
    sopsFile = ../../secrets/hosts/macbook-remote.yaml;
    mode = "0400";
  };

  sops.templates."tea-config.yml" = {
    content = ''
      logins:
        - name: zane
          url: https://gitea.wheregrassdreams.top
          ssh_host: gitea.wheregrassdreams.top
          user: zane
          token: ${config.sops.placeholder."gitea/token"}
          default: true
    '';
    path = "${homeDirectory}/Library/Application Support/tea/config.yml";
    mode = "0400";
  };

  # This host has a dedicated SSH identity for SOPS. It stays on the remote
  # machine and is converted to an age recipient in .sops.yaml.
  sops.age.keyFile = lib.mkForce null;
  sops.age.sshKeyPaths = lib.mkForce [ "${homeDirectory}/.ssh/id_ed25519_sops" ];
  home.sessionVariables = {
    SOPS_AGE_KEY_FILE = lib.mkForce "";
    SOPS_AGE_KEY_CMD = lib.mkForce "${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i ${homeDirectory}/.ssh/id_ed25519_sops";
    SOPS_AGE_SSH_PRIVATE_KEY_FILE = lib.mkForce "";
  };

  # Make the SOPS-managed token available to interactive and non-interactive
  # zsh commands, plus Git credential requests from external tools.
  programs.zsh.envExtra = lib.mkAfter ''
    if [[ -r ${lib.escapeShellArg githubTokenPath} ]]; then
      export GH_TOKEN="$(<${lib.escapeShellArg githubTokenPath})"
    fi
  '';
  programs.git.settings.credential."https://github.com".helper = "!${githubCredentialHelper}";

  my = {
    inherit identity;
    git.gitea.enable = true;
    terminal.shell = {
      prompt.enable = true;
      direnv.enable = true;
    };
    paths.personal.projects = "${homeDirectory}/Workspace/code/projects";
  };

  # This app-server belongs to the remote Mac host; the local Mac host does not
  # inherit its proxy settings or LaunchAgent.
  launchd.agents.codex-remote-app-server = {
    enable = true;
    config = {
      Label = "dev.wheregrassdreams.codex-remote-app-server";
      ProgramArguments = [
        "${codexRemoteAppServer}"
      ];
      WorkingDirectory = "${homeDirectory}/Workspace/code/projects";
      EnvironmentVariables = {
        CODEX_HOME = "${homeDirectory}/.codex";
        HOME = homeDirectory;
        HTTP_PROXY = proxyUrl;
        HTTPS_PROXY = proxyUrl;
        http_proxy = proxyUrl;
        https_proxy = proxyUrl;
        PATH = "/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/usr/bin:/bin";
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${homeDirectory}/Library/Logs/codex-remote-app-server.log";
      StandardErrorPath = "${homeDirectory}/Library/Logs/codex-remote-app-server.log";
    };
  };
}
