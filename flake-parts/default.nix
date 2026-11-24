{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.partitions
    ./outputs.nix
    ../packages/default.nix
  ];

  partitions.dev = {
    extraInputsFlake = ./partitions/dev;
    module = ./development.nix;
  };

  partitions.darwin = {
    extraInputsFlake = ./partitions/darwin;
    module = {
      imports = [
        (import ./platform-outputs.nix { outputType = "darwin"; })
        ./deploy-outputs.nix
      ];
    };
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
    deploy = "darwin";
    apps = "darwin";
    checks = "darwin";
  };
}
