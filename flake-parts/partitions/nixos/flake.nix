{
  description = "NixOS-only inputs for the nix-config flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/8fd9daa3db09ced9700431c5b7ad0e8ba199b575?shallow=1";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-emoji-linux = {
      url = "github:samuelngs/apple-emoji-linux?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = _: { };
}
