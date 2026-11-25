{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.terminal.rex;

  appDirs = map (name: "/Applications/${name}") cfg.appBundles;

  # Rex ships its CLI inside the app bundle's helper; nothing in the DMG puts
  # it on PATH. The wrapper resolves the bundle at runtime so app updates and
  # beta renames do not require a rebuild.
  rex = pkgs.writeShellScriptBin "rex" ''
    for app in ${lib.escapeShellArgs appDirs}; do
      bin="$app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex"
      if [ -x "$bin" ]; then
        exec "$bin" "$@"
      fi
    done

    printf '%s\n' "rex: no Rex app bundle found in /Applications; install the Rex beta DMG" >&2
    exit 127
  '';
in
{
  config = lib.mkIf cfg.enable {
    # Rex reads init.lua but never writes it, so a store symlink is safe.
    # force replaces the hand-written file on the first switch.
    xdg.configFile."rex/init.lua" = {
      source = ./init.lua;
      force = true;
    };

    home = {
      packages = [ rex ];

      # `rex skill setup` only touches its own entries and is safe to repeat.
      # It keeps ~/.claude/skills/rex, ~/.agents/skills/rex and the agent
      # hooks current after each switch; without the CLI it used to leave a
      # dead stub behind.
      activation.rexSkillSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if ${rex}/bin/rex --help >/dev/null 2>&1; then
          run ${rex}/bin/rex skill setup || echo "rex: skill setup failed; run 'rex skill setup' by hand" >&2
        else
          verboseEcho "rex: Rex app bundle not installed, skipping skill setup"
        fi
      '';

      # A running server keeps the old config until reloaded. No server means
      # nothing to reload, so this stays informational.
      activation.rexConfigReload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if ${rex}/bin/rex --help >/dev/null 2>&1; then
          run ${rex}/bin/rex config reload --autostart=false || verboseEcho "rex: no running server, config loads at next start"
        fi
      '';
    };
  };
}
