{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.my.git.gitea.enable {
    home.packages = [ pkgs.unstable.tea ];
    programs.git.settings = {
      # 不生效
      # credential."https://git.wheregrassdreams.top".helper = "!tea login helper";
    };
  };

}
