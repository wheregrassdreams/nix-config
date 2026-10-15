{
  ...
}:
{
  nix.settings = {
    builders-use-substitutes = true;
    extra-experimental-features = [
      "flakes"
      "nix-command"
    ];
    max-jobs = "auto";
    cores = 0;
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 14d";
  };
}
