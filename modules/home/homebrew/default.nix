{
  config,
  repoLib,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.homebrew;
  brewfile = import ./lib/brewfile.nix { inherit cfg lib pkgs; };
  brewSync = import ./lib/brew-sync.nix {
    inherit
      cfg
      lib
      pkgs
      brewfile
      ;
  };
in
{
  imports = [
    (repoLib.assertPlatform {
      package = "homebrew";
      platforms = [ "darwin" ];
    })
  ]
  ++ repoLib.importAll ./.;

  config = {
    my.homebrew.brews = [ "mas" ];

    xdg.configFile."homebrew/Brewfile".source = brewfile;
    home.sessionVariables = {
      HOMEBREW_BUNDLE_FILE = "${config.xdg.configHome}/homebrew/Brewfile";

      # Keep Homebrew's native macOS cache path and cleanup retention policy
      # visible in Nix; Homebrew still owns the cache format and cleanup logic.
      HOMEBREW_CACHE = "${config.home.homeDirectory}/Library/Caches/Homebrew";
      HOMEBREW_CLEANUP_MAX_AGE_DAYS = "120";
    };
    home.packages = [ brewSync ];

    home.activation.brewBundle = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if ${lib.boolToString cfg.sync.enable}; then
        if ! $DRY_RUN_CMD ${brewSync}/bin/brew-nix-sync; then
          ${
            if cfg.sync.strict then "exit 1" else ''echo "warning: Homebrew bundle synchronization failed" >&2''
          }
        fi
      fi
    '';
  };
}
