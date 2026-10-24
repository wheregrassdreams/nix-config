{
  config,
  flake,
  hostFacts,
  identity,
  inputs,
  pkgs,
  ...
}:
let
  codex = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  homeDirectory = config.home.homeDirectory;
  proxyUrl = hostFacts.network.proxyUrl;
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

  my = {
    inherit identity;
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
