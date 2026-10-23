{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.partitions
    ./outputs.nix
    ../overlays/default.nix
  ];

  partitions.dev = {
    extraInputsFlake = ./partitions/dev;
    module = ./development.nix;
  };

  partitions.darwin = {
    extraInputsFlake = ./partitions/darwin;
    module = import ./platform-outputs.nix { outputType = "darwin"; };
  };

  partitions.nixos = {
    extraInputsFlake = ./partitions/nixos;
    module = import ./platform-outputs.nix { outputType = "nixos"; };
  };

  partitionedAttrs = {
    devShells = "dev";
    formatter = "dev";
    packages = "dev";
    darwinConfigurations = "darwin";
    nixosConfigurations = "nixos";
  };
}
