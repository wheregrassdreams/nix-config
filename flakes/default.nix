{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.partitions
    ./outputs.nix
  ];

  partitions.dev = {
    extraInputsFlake = ./dev;
    module = ./development.nix;
  };

  partitionedAttrs = {
    devShells = "dev";
    formatter = "dev";
    packages = "dev";
  };
}
