{
  description = "NixOS-only inputs for the nix-config flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/47472570b1e607482890801aeaf29bfb749884f6?shallow=1";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = _: { };
}
