#!/usr/bin/env bash
set -Eeuo pipefail

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 1 ]] || die "usage: $(basename "$0") REPOSITORY"
command -v jq >/dev/null 2>&1 || die "jq is required"

repo="$1"
[[ -f "$repo/flake.nix" ]] || die "repository does not contain flake.nix: $repo"

target_info="$(bash "$repo/scripts/nix-target.sh" describe "$repo")"
home_target="$(sed -n 's/^home_target=//p' <<<"$target_info")"
[[ -n $home_target ]] || die "could not determine the current Home Manager target"

flake_ref="path:$repo#homeConfigurations.\"$home_target\".config.my.paths.exported"
paths_json="$(nix eval --json "$flake_ref")" || die "could not evaluate exported paths for $home_target"

printf '%-36s %-10s %s\n' 'CONTRACT' 'SIZE' 'PATH'
printf '%-36s %-10s %s\n' '------------------------------------' '----------' '----'

count=0
while IFS= read -r -d '' name && IFS= read -r -d '' path; do
  count=$((count + 1))
  if [[ -e $path || -L $path ]]; then
    size="$(du -sh "$path" 2>/dev/null | cut -f1)" || size=unreadable
    [[ -n $size ]] || size=unreadable
  else
    size=missing
  fi
  printf '%-36s %-10s %s\n' "$name" "$size" "$path"
done < <(jq -j 'to_entries[] | .key, "\u0000", .value, "\u0000"' <<<"$paths_json")

if [[ $count -eq 0 ]]; then
  printf 'No exported paths are declared for %s.\n' "$home_target"
fi
