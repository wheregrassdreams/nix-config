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
    programs.git.settings = {
      # 不生效
      # credential."https://git.wheregrassdreams.top".helper = "!tea login helper";
    };
  };

}
