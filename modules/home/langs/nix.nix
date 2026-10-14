{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.my.development.enable && config.my.development.nix.enable) {
    home.packages = with pkgs; [
      alejandra
      deadnix
      nil
      nixd
      nixfmt-rfc-style
      nixpkgs-fmt
      statix
    ];
  };
}
