{
  config,
  lib,
  ...
}:
let
  cache = config.xdg.cacheHome;
  data = config.xdg.dataHome;
in
{
  options.my.dev.langs.javascript.paths = {
    pnpmHome = lib.mkOption {
      type = lib.types.str;
      default = "${data}/pnpm";
      description = "pnpm global package and executable directory";
    };
    playwrightBrowsers = lib.mkOption {
      type = lib.types.str;
      default = "${cache}/ms-playwright";
      description = "Shared cache directory for Playwright browser binaries";
    };
    pnpmStore = lib.mkOption {
      type = lib.types.str;
      default = "${cache}/pnpm/store";
      description = "Shared pnpm package store directory";
    };
    pnpmCache = lib.mkOption {
      type = lib.types.str;
      default = "${cache}/pnpm";
      description = "pnpm registry metadata and dlx cache directory";
    };
    npmCache = lib.mkOption {
      type = lib.types.str;
      default = "${cache}/npm";
      description = "npm cache and npx execution directory";
    };
    bunPackageCache = lib.mkOption {
      type = lib.types.str;
      default = "${cache}/bun/install";
      description = "Bun's global package cache directory";
    };
    bunRuntimeCache = lib.mkOption {
      type = lib.types.str;
      default = "${cache}/bun/transpiler";
      description = "Bun's runtime transpiler cache directory";
    };
  };
}
