{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.my.tools.network) {
    home.packages = with pkgs; [
      # mosh
      tailscale
    ];
  };
}
