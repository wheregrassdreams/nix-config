{ ... }:
let
  identity = {
    username = "zane";
    fullname = "Zane Lu";
    email = "lv2497712968@outlook.com";
  };
in
{
  system = "x86_64-linux";
  inherit identity;
  outputType = "nixos";
  hostName = "nixos";
  configRepoPath = "/home/zane/nix-config";
  isWsl = true;
  systemModules = [
    ./system.nix
  ];
  homeModules = [ ./home.nix ];
}
