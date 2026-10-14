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
  imports = repoLib.importAll ./.;

  config = {
    xdg.configFile."homebrew/Brewfile".source = brewfile;
    home.sessionVariables.HOMEBREW_BUNDLE_FILE = "${config.xdg.configHome}/homebrew/Brewfile";
    home.packages = [ brewSync ];

    home.activation.brewBundle = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if ${lib.boolToString cfg.sync.enable}; then
        if ! $DRY_RUN_CMD ${brewSync}/bin/brew-sync; then
          ${
            if cfg.sync.strict then "exit 1" else ''echo "warning: Homebrew bundle synchronization failed" >&2''
          }
        fi
      fi
    '';
  };
}
