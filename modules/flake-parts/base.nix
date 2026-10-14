{ inputs, ... }:
let
  inherit (inputs) self nixpkgs;
  inherit (nixpkgs) lib;

  overlays = [
    inputs.nur.overlays.default
    inputs.llm-agents.overlays.default
  ];

  repoLib = import ../../lib {
    lib = nixpkgs.lib;
    inherit
      nixpkgs
      inputs
      self
      overlays
      ;
  };

  hosts = import ../../configurations/hosts { inherit self; };

  mkHostOutputs =
    name: host:
    lib.recursiveUpdate
      (lib.setAttrByPath [
        (if host.isDarwin or false then "darwinConfigurations" else "nixosConfigurations")
        name
      ] (repoLib.mkHost host))
      (lib.setAttrByPath [ "homeConfigurations" "${host.userName}@${name}" ] (repoLib.mkHome host));

  hostOutputs = lib.foldl' lib.recursiveUpdate { } (lib.mapAttrsToList mkHostOutputs hosts);
in
{
  flake =
    lib.recursiveUpdate
      {
        homeModules = repoLib.discoverPackages ../../modules/home;
        darwinModules.platform = import ../../modules/system/darwin;
        nixosModules.platform = import ../../modules/system/nixos;
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
