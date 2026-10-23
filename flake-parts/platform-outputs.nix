{ outputType }:
{ inputs, ... }:
let
  inherit (import ./host-context.nix { inherit inputs; }) lib mylib hosts;
  selectedHosts = lib.filterAttrs (_: host: host.outputType == outputType) hosts;
  outputName = if outputType == "darwin" then "darwinConfigurations" else "nixosConfigurations";
  configurations = lib.mapAttrs (_: mylib.mkHost) selectedHosts;
in
{
  flake = lib.setAttrByPath [ outputName ] configurations;
}
