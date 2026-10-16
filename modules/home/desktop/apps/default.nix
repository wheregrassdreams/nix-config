{
  config,
  lib,
  pkgs,
  repoLib,
  ...
}:
let
  appIdentity = import ./lib/package.nix { inherit pkgs; };
  cacheFile = "${config.xdg.cacheHome}/nix-config/app-identities.json";
in
{
  imports = [
    (repoLib.assertPlatform {
      package = "desktop.apps";
      platforms = [ "darwin" ];
    })
  ];

  home.packages = [ appIdentity ];

  home.activation.refreshAppIdentities = lib.hm.dag.entryAfter [ "brewBundle" ] ''
    $DRY_RUN_CMD ${appIdentity}/bin/app-identity refresh --cache ${lib.escapeShellArg cacheFile}
  '';
}
