{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.git.gitlab;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.glab ];
  };
}
