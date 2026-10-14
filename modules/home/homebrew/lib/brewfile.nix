{
  cfg,
  lib,
  pkgs,
}:
let
  escapeRuby = value: lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] value;
  tapLine = tap: ''tap "${escapeRuby tap.name}"'' + lib.optionalString tap.trusted ", trusted: true";
in
pkgs.writeText "Brewfile" (
  lib.concatStringsSep "\n" (
    lib.unique (map tapLine cfg.taps)
    ++ lib.unique (map (name: ''brew "${escapeRuby name}"'') cfg.brews)
    ++ lib.unique (map (name: ''cask "${escapeRuby name}"'') cfg.casks)
    ++ lib.mapAttrsToList (name: id: ''mas "${escapeRuby name}", id: ${toString id}'') cfg.masApps
  )
  + "\n"
)
