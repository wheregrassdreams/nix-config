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
  dotfilesPath = "/home/zane/nix-config";
  isWsl = true;
  systemModules = [
    self.nixosModules.platform
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
    home.services
    home.data
    ./home.nix
  ];
}
