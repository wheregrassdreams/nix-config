{ config, inputs, lib, system, ... }:
let pkgs-unstable = import inputs.nixpkgs-unstable { inherit system; config.allowUnfree = true; };
in {
  config = lib.mkIf (config.my.git.enable && config.my.git.gitea.enable) {
    home.packages = [ pkgs-unstable.tea ];
    programs.git.settings = {
      # 不生效
      # credential."https://git.wheregrassdreams.top".helper = "!tea login helper";
    };
  };

}
