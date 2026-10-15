{
  config,
  lib,
  ...
}:
{
  options.my.dev.langs.go.paths = {
    moduleCache = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/go/pkg/mod";
      description = "Go module download cache directory";
    };
    importsIndex = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.cacheHome}/goimports";
      description = "Go imports index cache directory";
    };
  };
}
