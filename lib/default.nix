{
  lib,
  nixpkgs,
  inputs,
  self,
  overlays,
}:
let
  repoLib = {
    discoverPackages = import ./discover-packages.nix { inherit lib; };
    importAll = import ./import-all.nix { inherit lib; };
    mkHost = import ./mk-host.nix {
      inherit
        nixpkgs
        inputs
        self
        overlays
        repoLib
        ;
    };
    mkHome = import ./mk-home.nix {
      inherit
        nixpkgs
        inputs
        self
        overlays
        repoLib
        ;
    };
  };
in
repoLib
