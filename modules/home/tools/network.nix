{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.my.tools.enable && config.my.tools.network) {
    home.packages = with pkgs; [
      # mosh
      tailscale
    ];
  };
}
