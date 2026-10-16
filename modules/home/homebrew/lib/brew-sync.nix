{
  cfg,
  lib,
  pkgs,
  brewfile,
}:
let
  brewStateSync = (pkgs.buildGoModule.override {
    go = pkgs.unstable.go_1_27;
  })
    {
      pname = "brew-state-sync";
      version = "0.1.0";
      src = ./brew-state-sync;
      vendorHash = null;
      subPackages = [ "cmd/brew-state-sync" ];
    };
in
pkgs.writeShellScriptBin "brew-nix-sync" ''
  set -eu

  brew=${lib.escapeShellArg "${cfg.brewPrefix}/bin/brew"}
  brewfile=${lib.escapeShellArg brewfile}
  auto_update=${if cfg.sync.autoUpdate then "1" else "0"}
  upgrade=${if cfg.sync.upgrade then "1" else "0"}
  cleanup=${lib.escapeShellArg cfg.sync.cleanup}

  usage() {
    echo "Usage: brew-nix-sync [--update] [--upgrade] [--cleanup] [--zap]" >&2
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

  sync_args=(sync --prefix ${lib.escapeShellArg cfg.brewPrefix} --brew "$brew" --brewfile "$brewfile")
  if [ "$auto_update" -eq 1 ]; then
    sync_args+=(--auto-update)
  fi
  if [ "$upgrade" -eq 1 ]; then
    sync_args+=(--upgrade)
  fi
  ${brewStateSync}/bin/brew-state-sync "''${sync_args[@]}"

  case "$cleanup" in
    none) ;;
    uninstall|zap)
      # The Go synchronizer owns missing-package installs; Bundle still owns
      # its mature cleanup and zap semantics for explicit invocations.
      export HOMEBREW_NO_AUTO_UPDATE=1
      bundle_args=(bundle install --file="$brewfile" --no-upgrade --force-cleanup)
      if [ "$cleanup" = zap ]; then
        bundle_args+=(--zap)
      fi
      exec "$brew" "''${bundle_args[@]}"
      ;;
    *) echo "invalid cleanup mode: $cleanup" >&2; exit 2 ;;
  esac
''
