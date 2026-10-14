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
  userName = identity.username;
  hostName = "macbook";
  isDarwin = true;
  systemModules = [
    self.darwinModules.platform
    ./system.nix
  ];
  homeModules = [
    home.base
    home.shell
    home.terminal
    home.tools
    home.langs
    home.git
    home.ssh
    home.secrets
    home."ai.claude"
    home."ai.codex"
    home."ai.opencode"
    home."agent-resources"
    home."gui.browser"
    home."gui.editor"
    home."gui.file-browser"
    home."gui.keymap"
    home."gui.menu-bar"
    home."gui.terminal"
    home."gui.workspace"
    home."networking.clash-verge"
    home."networking.tailscale"
    home.services
    home.homebrew
    home.data
    ./home.nix
  ];
}
