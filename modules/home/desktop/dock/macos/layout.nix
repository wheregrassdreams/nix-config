{
  config,
  lib,
  pkgs,
  ...
}:
let
  entries = config.my.desktop.dock.entries;
  normalize = path: if lib.hasSuffix ".app" path then path + "/" else path;
  entryURI =
    path:
    "file://"
    +
      builtins.replaceStrings
        [
          " "
          "!"
          "\""
          "#"
          "$"
          "%"
          "&"
          "'"
          "("
          ")"
        ]
        [
          "%20"
          "%21"
          "%22"
          "%23"
          "%24"
          "%25"
          "%26"
          "%27"
          "%28"
          "%29"
        ]
        (normalize path);
  wantedURIs = lib.concatMapStringsSep "\n" (entry: entryURI entry.path) entries;
  addEntry =
    entry:
    "${pkgs.dockutil}/bin/dockutil --no-restart --add ${lib.escapeShellArg entry.path}"
    + " --section ${lib.escapeShellArg entry.section}"
    + lib.optionalString (entry.options != [ ]) (
      " " + lib.concatMapStringsSep " " lib.escapeShellArg entry.options
    );
in
{
  config = lib.mkIf (entries != [ ]) {
    home.activation.configureDock = lib.hm.dag.entryAfter [ "brewBundle" ] ''
      haveURIs="$(${pkgs.dockutil}/bin/dockutil --list | ${pkgs.coreutils}/bin/cut -f2)"
      wantedURIs=${lib.escapeShellArg wantedURIs}
      if ! ${pkgs.diffutils}/bin/diff -wu <(printf "%s" "$haveURIs") <(printf "%s" "$wantedURIs") >&2; then
        echo >&2 "Resetting the Dock for ${config.home.username}."
        $DRY_RUN_CMD ${pkgs.dockutil}/bin/dockutil --no-restart --remove all
        ${lib.concatMapStringsSep "\n" addEntry entries}
        $DRY_RUN_CMD /usr/bin/killall Dock || true
      else
        echo >&2 "Dock setup complete for ${config.home.username}."
      fi
    '';
  };
}
