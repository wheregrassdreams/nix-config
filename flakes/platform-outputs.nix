{ outputType }:
{ inputs, ... }:
let
  inherit (inputs) self nixpkgs;
  inherit (nixpkgs) lib;

  overlays = [ self.overlays.default ];

  repoLib = import ../lib {
    lib = nixpkgs.lib;
    inherit
      nixpkgs
      inputs
      self
      overlays
      ;
  };

  hostRoot = ../hosts;
  hostEntries = lib.filterAttrs (
    name: type:
    type == "directory"
    && !lib.hasPrefix "_" name
    && builtins.pathExists (hostRoot + "/${name}/host.nix")
  ) (builtins.readDir hostRoot);
  hosts = lib.mapAttrs (
    name: _: import (hostRoot + "/${name}/host.nix") { inherit self; }
  ) hostEntries;
  selectedHosts = lib.filterAttrs (_: host: host.outputType == outputType) hosts;
  outputName = if outputType == "darwin" then "darwinConfigurations" else "nixosConfigurations";
  configurations = lib.mapAttrs (_: repoLib.mkHost) selectedHosts;
in
{
  flake = lib.setAttrByPath [ outputName ] configurations;
}
