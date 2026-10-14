{
  config,
  lib,
  configRepoPath,
  ...
}:
let
  cfg = config.my.paths;
  locationVariable =
    name:
    "NIX_CONFIG_PATH_${lib.toUpper (lib.replaceStrings [ "-" "." "/" " " ] [ "_" "_" "_" "_" ] name)}";
  locationVariables = lib.mapAttrs' (name: path: {
    name = locationVariable name;
    value = path;
  }) cfg.personal;
in
{
  config = {
    my.paths = {
      home = lib.mkDefault config.home.homeDirectory;
      configRepo = lib.mkDefault configRepoPath;
      localBin = lib.mkDefault "${config.home.homeDirectory}/.local/bin";
      xdg = {
        config = lib.mkDefault config.xdg.configHome;
        data = lib.mkDefault config.xdg.dataHome;
        cache = lib.mkDefault config.xdg.cacheHome;
        state = lib.mkDefault config.xdg.stateHome;
      };
    };

    home.sessionVariables = {
      NIX_CONFIG_REPO_ROOT = cfg.configRepo;
      NIX_CONFIG_USER_HOME = cfg.home;
      NIX_CONFIG_LOCAL_BIN = cfg.localBin;
      NIX_CONFIG_XDG_CONFIG_HOME = cfg.xdg.config;
      NIX_CONFIG_XDG_DATA_HOME = cfg.xdg.data;
      NIX_CONFIG_XDG_CACHE_HOME = cfg.xdg.cache;
      NIX_CONFIG_XDG_STATE_HOME = cfg.xdg.state;
    }
    // locationVariables;

    home.sessionPath = [ cfg.localBin ];
  };
}
