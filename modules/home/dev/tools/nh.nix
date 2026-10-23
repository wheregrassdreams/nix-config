{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.dev.tools.nh.enable {
    home.packages = [ pkgs.nh ];
  };
}
