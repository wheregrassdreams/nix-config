{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.connectivity.ssh.trzsz;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.unstable.trzsz-ssh ];
    home.shellAliases.ssh = "tssh";
  };
}
