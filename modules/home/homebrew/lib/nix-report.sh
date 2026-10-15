#!/usr/bin/env bash
set -euo pipefail

mode="report"
case "${1:-}" in
  "") ;;
  --drift-only)
    mode="drift"
    shift
    ;;
  -h|--help)
    cat <<'EOF'
Usage: brew nix-report [--drift-only]

Report Homebrew inventory drift and storage use without changing installed
packages or cache contents. --drift-only prints only the inventory comparison.
EOF
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    echo "Usage: brew nix-report [--drift-only]" >&2
    exit 2
    ;;
esac

if (( $# > 0 )); then
  echo "Unexpected argument: $1" >&2
  echo "Usage: brew nix-report [--drift-only]" >&2
  exit 2
fi

if [[ "$(uname -s)" != Darwin ]]; then
  echo "Homebrew Nix report is available on macOS only." >&2
  exit 2
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew was not found in PATH." >&2
  exit 2
fi

brewfile="${HOMEBREW_BUNDLE_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/homebrew/Brewfile}"
if [[ ! -f "$brewfile" ]]; then
  echo "Active Homebrew Brewfile not found: $brewfile" >&2
  echo "Run the Home Manager activation first, or set HOMEBREW_BUNDLE_FILE." >&2
  exit 2
fi

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

audit_kind() {
  local kind="$1"
  local declared="$tmpdir/declared-$kind"
  local installed="$tmpdir/installed-$kind"
  local requested="$tmpdir/requested-$kind"
  local missing="$tmpdir/missing-$kind"
  local candidate="$tmpdir/candidate-$kind"

  if ! brew bundle list --file "$brewfile" "--$kind" \
    | LC_ALL=C sort -u >"$declared"; then
    printf 'Could not read declared Homebrew %s.\n' "$kind" >&2
    return 2
  fi
  if ! brew list --full-name "--$kind" \
    | LC_ALL=C sort -u >"$installed"; then
    printf 'Could not read installed Homebrew %s.\n' "$kind" >&2
    return 2
  fi

  if [[ "$kind" == formula ]]; then
    if ! brew list --installed-on-request --formula --full-name \
      | LC_ALL=C sort -u >"$requested"; then
      printf 'Could not read Homebrew formulae installed on request.\n' >&2
      return 2
    fi
  else
    cp "$installed" "$requested"
  fi

  comm -23 "$declared" "$installed" >"$missing"
  comm -13 "$declared" "$requested" >"$candidate"

  if [[ -s "$missing" || -s "$candidate" ]]; then
    printf '\n%s drift:\n' "$kind"
    if [[ -s "$missing" ]]; then
      printf '  Declared but not installed:\n'
      sed 's/^/    - /' "$missing"
    fi
    if [[ -s "$candidate" ]]; then
      printf '  Installed on request but not declared (review as Nix candidates):\n'
      sed 's/^/    - /' "$candidate"
    fi
    return 1
  fi

  printf '%s: no missing declarations or direct-install candidates.\n' "$kind"
  return 0
}

report_size() {
  local label="$1"
  local path="$2"
  if [[ -e "$path" ]]; then
    printf '  %-12s %s  (%s)\n' "$label" "$(du -sh "$path" | awk '{print $1}')" "$path"
  else
    printf '  %-12s not present  (%s)\n' "$label" "$path"
  fi
}

if [[ "$mode" == report ]]; then
  printf 'Homebrew Nix report\n'
  printf 'Brewfile: %s\n' "$brewfile"
  printf '\nStorage:\n'
  cache="$(brew --cache)"
  cellar="$(brew --cellar)"
  prefix="$(brew --prefix)"
  report_size "download cache" "$cache"
  report_size "formulae" "$cellar"
  report_size "casks" "$prefix/Caskroom"
  report_size "logs" "$HOME/Library/Logs/Homebrew"
fi

status=0
printf '\nDeclared versus installed inventory:\n'
for kind in formula cask; do
  result=0
  audit_kind "$kind" || result=$?
  if (( result > status )); then
    status="$result"
  fi
done

if (( status == 2 )); then
  printf '\nReport could not complete; no packages or data were changed.\n'
  exit 2
fi

if [[ "$mode" == report ]]; then
  printf '\nHomebrew cleanup preview (read-only; includes old formula versions and downloads):\n'
  if ! brew cleanup --dry-run; then
    printf 'Could not produce the Homebrew cleanup preview.\n' >&2
    exit 2
  fi
fi

if (( status != 0 )); then
  printf '\nInventory differs from the active Brewfile; no packages or data were changed.\n'
  exit 1
fi
