{
  config,
  pkgs,
  ...
}:
let
  cfg = config.my.dev.langs.javascript;
  homeCfg = config.my.paths;
  paths = cfg.paths // {
    nodeGypHeaders = "${homeCfg.xdg.cache}/node-gyp";
    nodeCompileCache = "${homeCfg.xdg.cache}/nodejs-compile-cache";
  };
in
{
  imports = [ ./options.nix ];

  config = {
    my.paths.exported = {
      "dev.javascript.playwright-browsers" = paths.playwrightBrowsers;
      "dev.javascript.pnpm-home" = paths.pnpmHome;
      "dev.javascript.pnpm-store" = paths.pnpmStore;
      "dev.javascript.pnpm-cache" = paths.pnpmCache;
      "dev.javascript.node-gyp-headers" = paths.nodeGypHeaders;
      "dev.javascript.node-compile-cache" = paths.nodeCompileCache;
      "dev.javascript.npm-cache" = paths.npmCache;
      "dev.javascript.bun-package-cache" = paths.bunPackageCache;
      "dev.javascript.bun-runtime-cache" = paths.bunRuntimeCache;
    };

    programs.zsh.shellAliases = {
      npm = "pnpm";
      npx = "pnpm dlx";
    };

    programs.bun = {
      enable = true;
      enableGitIntegration = true;
      package = pkgs.unstable.bun;
    };

    home.packages = [
      pkgs.unstable.nodejs
      pkgs.unstable.pnpm

      # lsp servers
      pkgs.vtsls
      pkgs.eslint
      pkgs.tailwindcss-language-server
      pkgs.vscode-langservers-extracted
    ];

    home.sessionVariables = {
      PNPM_HOME = paths.pnpmHome;
      NODE_COMPILE_CACHE = paths.nodeCompileCache;
      PLAYWRIGHT_BROWSERS_PATH = paths.playwrightBrowsers;
      # pnpm 10 uses npm_config_*; pnpm 11 uses pnpm_config_* and no longer
      # reads npm_config_* for pnpm-specific settings.
      npm_config_store_dir = paths.pnpmStore;
      pnpm_config_store_dir = paths.pnpmStore;
      npm_config_cache_dir = paths.pnpmCache;
      pnpm_config_cache_dir = paths.pnpmCache;
      npm_config_cache = paths.npmCache;
      npm_package_config_node_gyp_devdir = paths.nodeGypHeaders;
      BUN_INSTALL_CACHE_DIR = paths.bunPackageCache;
      BUN_RUNTIME_TRANSPILER_CACHE_PATH = paths.bunRuntimeCache;
    };

    home.sessionPath = [ paths.pnpmHome ];
  };
}
