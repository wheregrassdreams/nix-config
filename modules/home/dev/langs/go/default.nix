{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.langs.go;
  paths = config.my.paths;
  goPath = "${paths.xdg.data}/go";
  importsIndex = cfg.paths.importsIndex;
  _paths = {
    moduleCache = cfg.paths.moduleCache;
    buildCache = "${paths.xdg.cache}/go-build";
  };
in
{
  imports = [ ./options.nix ];

  config = {
    programs.go = {
      enable = true;
      package = pkgs.unstable.go_1_27;
      env = {
        GOPATH = goPath;
        GOBIN = paths.localBin;
        GOENV = "${goPath}/env";
        GOMODCACHE = _paths.moduleCache;
        GOCACHE = _paths.buildCache;
        GOTOOLCHAIN = "local";
      };
    };
    home.packages = [ pkgs.unstable.gopls ];
    my.paths.exported = {
      "dev.go.module-cache" = _paths.moduleCache;
      "dev.go.build-cache" = _paths.buildCache;
      "dev.go.imports-index" = importsIndex;
    };

    # Go's os.UserCacheDir() ignores XDG_CACHE_HOME on macOS. Keep its fixed
    # Library/Caches location as a compatibility symlink to the declared path.
    home.activation.goImportsIndexPath = lib.mkIf pkgs.stdenv.isDarwin (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        target=${lib.escapeShellArg importsIndex}
        legacy=${lib.escapeShellArg "${config.home.homeDirectory}/Library/Caches/goimports"}

        if [ -L "$legacy" ]; then
          rm "$legacy"
        elif [ -e "$legacy" ]; then
          if [ -e "$target" ]; then
            echo "Both Go imports cache paths exist; refusing to overwrite either" >&2
            exit 1
          fi
          mkdir -p "$(dirname "$target")"
          mv "$legacy" "$target"
        else
          mkdir -p "$(dirname "$legacy")"
        fi

        mkdir -p "$target"
        if [ ! -L "$legacy" ]; then
          ln -s "$target" "$legacy"
        fi
      ''
    );
  };
}
