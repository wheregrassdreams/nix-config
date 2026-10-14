{ ... }:
{
  imports = [ (import ./platform-outputs.nix { outputType = "nixos"; }) ];
}
