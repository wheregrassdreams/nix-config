{ config, lib, ... }:
let
  cfg = config.my.dev.langs;
  paths = config.my.paths;
  goPath = "${paths.xdg.data}/go";
in
{
  config = lib.mkIf cfg.go.enable {
    programs.go = {
      enable = true;
      packages = { };
      env = {
        GOPATH = goPath;
        GOBIN = paths.localBin;
        GOENV = "${goPath}/env";
        GOMODCACHE = "${goPath}/pkg/mod";
        GOCACHE = "${paths.xdg.cache}/go-build";
        GOTOOLCHAIN = "go1.27.1+auto";
      };
    };
    # home.sessionPath = [ programs.go.env.GOBIN ];
  };
}
