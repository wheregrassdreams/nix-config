{ inputs, ... }:
let
  inherit (inputs) self nixpkgs;
  inherit (nixpkgs) lib;

  overlays = [ self.overlays.default ];

  mylib = import ../lib {
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

  hostHomeConfigurations = lib.mapAttrs' (
    name: host: lib.nameValuePair "${host.identity.username}@${name}" (mylib.mkHome host)
  ) hosts;
  homeConfigurations = hostHomeConfigurations;
in
{
  flake = {
    homeModules = mylib.discoverPackages ../modules/home;
    homeConfigurations = homeConfigurations;
    darwinModules.platform = import ../modules/system/darwin;
    nixosModules.platform = import ../modules/system/nixos;
    lib = lib.extend (_: _: { nixConfig = lib.removeAttrs mylib [ "mkHost" ]; });
  };
}
