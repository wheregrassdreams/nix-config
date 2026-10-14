{ self }:
let
  identity = {
    username = "zane";
    fullname = "Zane Lu";
    email = "lv2497712968@outlook.com";
  };
  home = self.homeModules;
in
{
  system = "x86_64-linux";
  inherit identity;
  userName = identity.username;
  hostName = "nixos";
  configRepoPath = "/home/zane/nix-config";
  isWsl = true;
  systemModules = [
    self.nixosModules.platform
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
    home."connectivity.tailscale"
    home.services
    home.data
    ./home.nix
  ];
}
