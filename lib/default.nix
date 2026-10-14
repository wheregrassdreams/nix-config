{
  lib,
  nixpkgs,
  inputs,
  self,
  overlays,
}:
let
  dotfilesLib = {
    discoverPackages = import ./discover-packages.nix { inherit lib; };
    collectPackageModules = import ./collect-package-modules.nix { inherit lib; };
    mkHost = import ./mk-host.nix { inherit nixpkgs inputs self overlays dotfilesLib; };
    mkHome = import ./mk-home.nix { inherit nixpkgs inputs self overlays dotfilesLib; };
  };
in dotfilesLib
