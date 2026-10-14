{ inputs, ... }:
let
  inherit (inputs) self nixpkgs;
  inherit (nixpkgs) lib;

  overlays = [
    inputs.nur.overlays.default
    inputs.llm-agents.overlays.default
  ];

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

  mkHostOutputs =
    name: host:
    assert lib.elem host.outputType [
      "darwin"
      "nixos"
    ];
    lib.recursiveUpdate
      (lib.setAttrByPath [
        (if host.outputType == "darwin" then "darwinConfigurations" else "nixosConfigurations")
        name
      ] (repoLib.mkHost host))
      (
        lib.setAttrByPath [ "homeConfigurations" "${host.identity.username}@${name}" ] (repoLib.mkHome host)
      );

  hostOutputs = lib.foldl' lib.recursiveUpdate { } (lib.mapAttrsToList mkHostOutputs hosts);
in
{
  flake =
    lib.recursiveUpdate
      {
        homeModules = repoLib.discoverPackages ../modules/home;
        darwinModules.platform = import ../modules/system/darwin;
        nixosModules.platform = import ../modules/system/nixos;
      }
      (
        lib.recursiveUpdate hostOutputs {
          lib = lib.extend (
            _: _: {
              nixConfig = repoLib;
            }
          );
        }
      );
}
