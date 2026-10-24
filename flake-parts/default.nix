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

  partitions.desktop = {
    extraInputsFlake = ./partitions/desktop;
    module = ./desktop-outputs.nix;
  };

  partitionedAttrs = {
    devShells = "dev";
    formatter = "dev";
    packages = "dev";
    desktop = "desktop";
    darwinConfigurations = "darwin";
    nixosConfigurations = "nixos";
  };
}
