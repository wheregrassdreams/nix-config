{ cfg, lib, pkgs, brewfile }:
pkgs.writeShellScriptBin "brew-sync" ''
  set -eu

  brew=${lib.escapeShellArg "${cfg.brewPrefix}/bin/brew"}
  brewfile=${lib.escapeShellArg brewfile}
  auto_update=${if cfg.sync.autoUpdate then "1" else "0"}
  upgrade=${if cfg.sync.upgrade then "1" else "0"}
  cleanup=${lib.escapeShellArg cfg.sync.cleanup}

  usage() {
    echo "Usage: brew-sync [--update] [--upgrade] [--cleanup] [--zap]" >&2
  }

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --update) auto_update=1 ;;
      --upgrade) upgrade=1 ;;
      --cleanup) cleanup=uninstall ;;
      --zap) cleanup=zap ;;
      -h|--help) usage; exit 0 ;;
      *) usage; exit 2 ;;
    esac
    shift
  done

  if [ ! -x "$brew" ]; then
    echo "Homebrew is not installed at ${cfg.brewPrefix}; run darwin-rebuild first." >&2
    exit 1
  fi

  if [ "$auto_update" -eq 1 ]; then
    "$brew" update
  else
    export HOMEBREW_NO_AUTO_UPDATE=1
  fi

  set -- bundle install --file="$brewfile"
  if [ "$upgrade" -eq 0 ]; then
    set -- "$@" --no-upgrade
  fi
  case "$cleanup" in
    none) ;;
    uninstall) set -- "$@" --force-cleanup ;;
    zap) set -- "$@" --force-cleanup --zap ;;
    *) echo "invalid cleanup mode: $cleanup" >&2; exit 2 ;;
  esac

  exec "$brew" "$@"
''
