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
  home.packages = [ pkgs.gh ];

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
          url: https://git.wheregrassdreams.top
          ssh_host: git.wheregrassdreams.top
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

  # Provide the SOPS-managed token to interactive GitHub CLI commands and to
  # Git credential requests from tools launched outside an interactive shell.
  programs.zsh.initContent = lib.mkAfter ''
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
        "${codex}/bin/codex"
        "app-server"
        "--listen"
        "ws://127.0.0.1:45231"
      ];
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
