{ ... }:
let
  identity = {
    username = "zanelu";
    fullname = "Zane Lu";
    email = "lv2497712968@outlook.com";
  };
in
{
  system = "aarch64-darwin";
  inherit identity;
  outputType = "darwin";
  hostName = "macbook";
  systemModules = [
    ./system.nix
  ];
  homeModules = [ ./home.nix ];
}
