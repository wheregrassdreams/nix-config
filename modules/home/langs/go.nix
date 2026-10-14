{ config, ... }:
let
  paths = config.my.paths;
  goPath = "${paths.xdg.data}/go";
in
{
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
}
