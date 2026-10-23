{
  description = "Darwin-only inputs for the nix-config flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/8fd9daa3db09ced9700431c5b7ad0e8ba199b575?shallow=1";

    nix-darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-25.11?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew?shallow=1";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3.8.6";
  };

  outputs = _: { };
}
