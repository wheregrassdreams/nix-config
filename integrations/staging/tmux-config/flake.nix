{
  description = "Temporary host-selected Home Manager adapter for tmux-config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11?shallow=1";
    tmux-config = {
      url = "git+ssh://git@github.com/wheregrassdreams/tmux-config.git?ref=tmux-config%2Fpackaging";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: {
    homeManagerModules.default =
      { pkgs, ... }@args:
      import ./modules/home.nix (
        args
        // {
          tmuxConfig = inputs.tmux-config.packages.${pkgs.system}.default;
        }
      );
  };
}
