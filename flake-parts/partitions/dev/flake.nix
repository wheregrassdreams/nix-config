{
  description = "Nix configuration development-only flake inputs";

  inputs = {
    # Keep this lock aligned with the base graph so the development partition
    # reuses its package cache instead of introducing a second nixpkgs closure.
    nixpkgs.url = "github:NixOS/nixpkgs/47472570b1e607482890801aeaf29bfb749884f6";

    nix-fast-build = {
      url = "github:Mic92/nix-fast-build/5874ab8d0ef2f7b00dbc8644232c18cadee7b3dc";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix/790751ff7fd3801feeaf96d7dc416a8d581265ba";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = _: { };
}
