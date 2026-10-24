{
  description = "Temporary Home Manager integration for the standalone Reprise project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    reprise = {
      url = "git+ssh://git@github.com/wheregrassdreams/reprise.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: {
    homeManagerModules.default =
      { pkgs, ... }@args:
      import ./modules/home.nix (
        args
        // {
          inherit (inputs.reprise) outPath;
          reprise = inputs.reprise.packages.${pkgs.system}.default;
        }
      );
  };
}
