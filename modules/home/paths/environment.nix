{
  config,
  lib,
  configRepoPath,
  ...
}:
let
  cfg = config.my.paths;
  pathVariables = import ./lib/path-variables.nix { inherit lib; };
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
    }
    // pathVariables {
      prefix = "NIX_CONFIG_PATH_";
      values = cfg.personal;
    }
    // pathVariables {
      prefix = "NIX_CONFIG_XDG_";
      values = cfg.xdg;
    }
    # Keep package path registrations dormant until a concrete downstream
    # consumer needs these shell-level contracts.
    # // pathVariables {
    #   prefix = "NIX_CONFIG_PATH_";
    #   values = cfg.exported;
    # }
    ;

    # Prefer declarative packages when a local, manually installed binary has
    # the same name; keep localBin available for project-specific tools.
    home.sessionPath = [
      "${config.home.profileDirectory}/bin"
      cfg.localBin
    ];
  };
}
