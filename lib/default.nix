{
  lib,
  nixpkgs,
  inputs,
  self,
  overlays,
}:
let
  mylib = {
    assertPlatform = import ./assert-platform.nix;
    discoverPackages = import ./discover-packages.nix { inherit lib; };
    importAll = import ./import-all.nix { inherit lib; };
    mkHost = import ./mk-host.nix {
      inherit
        nixpkgs
        inputs
        self
        overlays
        mylib
        ;
    };
    mkHome = import ./mk-home.nix {
      inherit
        nixpkgs
        inputs
        self
        overlays
        mylib
        ;
    };
  };
in
mylib
