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

  homeConfigurations = lib.mapAttrs' (
    name: host: lib.nameValuePair "${host.identity.username}@${name}" (repoLib.mkHome host)
  ) hosts;
in
{
  flake = {
    homeModules = repoLib.discoverPackages ../modules/home;
    homeConfigurations = homeConfigurations;
    darwinModules.platform = import ../modules/system/darwin;
    nixosModules.platform = import ../modules/system/nixos;
    lib = lib.extend (_: _: { nixConfig = lib.removeAttrs repoLib [ "mkHost" ]; });
  };
}
