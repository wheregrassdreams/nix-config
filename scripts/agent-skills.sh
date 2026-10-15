#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skills_root="$repo_root/resources/agents/skills"
manifest="$repo_root/resources/agents/sources.json"
temp_dir=""

cleanup() {
  if [[ -n "$temp_dir" ]]; then
    rm -rf "$temp_dir"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage:
  just agent-skills-find <query>
  just agent-skills-add <source> <upstream-skill> [local-name]
  just agent-skills-update <local-name>

Skills are fetched with `npx skills`, copied into resources/agents/skills,
and then deployed by Home Manager from the checked-in files.
EOF
}

read_manifest_entry() {
  python3 - "$manifest" "$1" <<'PY'
import json
import sys

manifest_path, name = sys.argv[1:]
with open(manifest_path, encoding="utf-8") as stream:
    manifest = json.load(stream)
entry = manifest.get("skills", {}).get(name)
if entry is None:
    raise SystemExit(f"No recorded upstream source for skill: {name}")
print(entry["source"])
print(entry["skill"])
PY
}

record_source() {
  local name="$1" source="$2" upstream_skill="$3" integrity="$4"
  python3 - "$manifest" "$name" "$source" "$upstream_skill" "$integrity" <<'PY'
import json
import os
import sys
import tempfile

manifest_path, name, source, upstream_skill, integrity = sys.argv[1:]
with open(manifest_path, encoding="utf-8") as stream:
    manifest = json.load(stream)
manifest.setdefault("version", 1)
manifest.setdefault("skills", {})[name] = {
    "integrity": integrity,
    "source": source,
    "skill": upstream_skill,
}
directory = os.path.dirname(manifest_path)
fd, temporary_path = tempfile.mkstemp(prefix="sources.", suffix=".json", dir=directory)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        json.dump(manifest, stream, indent=2, sort_keys=True)
        stream.write("\n")
    os.replace(temporary_path, manifest_path)
except BaseException:
    try:
        os.unlink(temporary_path)
    except FileNotFoundError:
        pass
    raise
PY
}

fetch_skill() {
  local source="$1" upstream_skill="$2" destination_name="$3" mode="$4"
  local staged_dir destination backup_dir integrity
  temp_dir="$(mktemp -d)"

  (
    cd "$temp_dir"
    npx --yes skills add "$source" \
      --skill "$upstream_skill" \
      --agent codex \
      --copy \
      --yes
  )

  staged_dir="$temp_dir/.agents/skills/$upstream_skill"
  if [[ ! -f "$staged_dir/SKILL.md" ]]; then
    printf 'skills CLI did not produce a skill at %s\n' "$staged_dir" >&2
    return 1
  fi

  destination="$skills_root/$destination_name"
  if [[ "$mode" == add && -e "$destination" ]]; then
    printf 'Skill already exists: %s\n' "$destination_name" >&2
    return 1
  fi

  staged_dir="$skills_root/.${destination_name}.staging.$$"
  backup_dir="$skills_root/.${destination_name}.backup.$$"
  rm -rf "$staged_dir" "$backup_dir"
  cp -R "$temp_dir/.agents/skills/$upstream_skill" "$staged_dir"

  if [[ "$mode" == update ]]; then
    if [[ ! -d "$destination" ]]; then
      printf 'Managed skill directory is missing: %s\n' "$destination_name" >&2
      rm -rf "$staged_dir"
      return 1
    fi
    mv "$destination" "$backup_dir"
  fi

  if ! mv "$staged_dir" "$destination"; then
    if [[ -d "$backup_dir" ]]; then
      mv "$backup_dir" "$destination"
    fi
    return 1
  fi
  rm -rf "$backup_dir"
  integrity="$(python3 - "$destination" <<'PY'
import hashlib
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
digest = hashlib.sha256()
for path in sorted(item for item in root.rglob("*") if item.is_file()):
    relative = path.relative_to(root).as_posix().encode("utf-8")
    contents = path.read_bytes()
    digest.update(len(relative).to_bytes(8, "big"))
    digest.update(relative)
    digest.update(len(contents).to_bytes(8, "big"))
    digest.update(contents)
print("sha256:" + digest.hexdigest())
PY
)"
  record_source "$destination_name" "$source" "$upstream_skill" "$integrity"
  printf 'Fetched %s from %s. Review the skill and source record before committing.\n' \
    "$destination_name" "$source"
}

valid_name() {
  [[ -n "$1" && "$1" != . && "$1" != .. && "$1" != */* ]]
}

command_name="${1:-}"
if [[ -z "$command_name" ]]; then
  usage >&2
  exit 2
fi
shift

case "$command_name" in
  find)
    exec npx --yes skills find "$@"
    ;;
  add)
    if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then
      usage >&2
      exit 2
    fi
    source="$1"
    upstream_skill="$2"
    local_name="${3:-$upstream_skill}"
    valid_name "$local_name" || { printf 'Invalid local skill name: %s\n' "$local_name" >&2; exit 2; }
    fetch_skill "$source" "$upstream_skill" "$local_name" add
    ;;
  update)
    if [[ "$#" -ne 1 ]]; then
      usage >&2
      exit 2
    fi
    local_name="$1"
    valid_name "$local_name" || { printf 'Invalid local skill name: %s\n' "$local_name" >&2; exit 2; }
    source_and_skill="$(read_manifest_entry "$local_name")"
    source="${source_and_skill%%$'\n'*}"
    upstream_skill="${source_and_skill#*$'\n'}"
    fetch_skill "$source" "$upstream_skill" "$local_name" update
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
