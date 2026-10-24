{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.git.gitea;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.unstable.tea ];
    programs.git.settings.credential."https://git.wheregrassdreams.top".helper =
      "!${pkgs.unstable.tea}/bin/tea logins helper";
  };
}
