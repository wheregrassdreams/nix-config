{
  config,
  inputs,
  system,
  pkgs,
  lib,
  ...
}:
let
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
in
{
  config = lib.mkIf config.my.dev.langs.javascript.enable {
    programs.zsh.shellAliases.npm = "pnpm";
    programs.bun = {
      enable = true;
      enableGitIntegration = true;
      package = pkgs-unstable.bun;
    };
    home.packages = [
      pkgs.nodejs
      pkgs.pnpm
    ];
    home.sessionVariables.NODE_COMPILE_CACHE = "${config.xdg.cacheHome}/nodejs-compile-cache";
  };
}
