{ ... }:
{
  imports = [ (import ./platform-outputs.nix { outputType = "darwin"; }) ];
}
