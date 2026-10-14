{ self }:
let
  identity = {
    username = "zanelu";
    fullname = "Zane Lu";
    email = "lv2497712968@outlook.com";
  };
  home = self.homeModules;
in
{
  system = "aarch64-darwin";
  inherit identity;
  outputType = "darwin";
  hostName = "macbook";
  systemModules = [
    self.darwinModules.platform
    ./system.nix
  ];
  homeModules = [
    home.paths
    home."terminal.shell"
    home.terminal
    home."terminal.tmux"
    home."terminal.tools"
    home."dev.langs"
    home."dev.ci"
    home.git
    home."connectivity.ssh"
    home.secrets
    home."ai.claude"
    home."ai.codex"
    home."ai.opencode"
    home."ai.agent-resources"
    home."desktop.browser"
    home."desktop.editor"
    home."desktop.file-browser"
    home."desktop.keymap"
    home."desktop.menu-bar"
    home."desktop.terminal"
    home."desktop.workspace"
    home."connectivity.clash-verge"
    home."connectivity.tailscale"
    home.services
    home.data
    ./home.nix
  ];
}
