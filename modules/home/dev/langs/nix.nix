{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.dev.langs.nix.enable {
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
