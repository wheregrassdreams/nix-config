{
  config,
  lib,
  pkgs,
  ...
}:
let
  homebrewCfg = config.my.homebrew.brewPrefix;
  cfg = config.my.desktop.browser;
  defaultbrowserName = if cfg.default == "orion" then "kagimacos" else cfg.default;
  setDefaultBrowser = pkgs.writeShellScriptBin "browser-default" ''
    defaultbrowser=${lib.escapeShellArg "${homebrewCfg}/bin/defaultbrowser"}
    if [ ! -x "$defaultbrowser" ]; then
      echo "defaultbrowser is unavailable; run brew-sync before setting the default browser." >&2
      exit 0
    fi

    exec "$defaultbrowser" ${defaultbrowserName}
  '';
in
{
  config = {
    my.homebrew = {
      brews = [ "defaultbrowser" ];
      casks =
        lib.optionals cfg.chrome.enable [ "google-chrome" ]
        ++ lib.optionals cfg.orion.enable [ "orion" ]
        ++ lib.optionals cfg.zen.enable [ "zen" ];
    };

    home.packages = [ setDefaultBrowser ];
    home.activation.setDefaultBrowser = lib.hm.dag.entryAfter [ "brewBundle" ] ''
      ${setDefaultBrowser}/bin/browser-default
    '';
  };
}
