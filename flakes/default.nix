{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.partitions
    ./outputs.nix
    ../overlays/default.nix
  ];

  partitions.dev = {
    extraInputsFlake = ./dev;
    module = ./development.nix;
  };

  partitions.darwin = {
    extraInputsFlake = ./darwin;
    module = ./darwin-partition.nix;
  };

  partitions.nixos = {
    extraInputsFlake = ./nixos;
    module = ./nixos-partition.nix;
  };

  partitionedAttrs = {
    devShells = "dev";
    formatter = "dev";
    packages = "dev";
    darwinConfigurations = "darwin";
    nixosConfigurations = "nixos";
  };
}
