#!/usr/bin/env bash
set -euo pipefail

config_file=$1
start_marker=$2
end_marker=$3
comment_line=$4
include_line=$5
config_dir=${config_file%/*}

mkdir -p "$config_dir"

if [[ -L $config_file ]]; then
  printf 'Refusing to edit symlinked SSH config: %s\n' "$config_file" >&2
  exit 1
fi

if [[ -e $config_file && ! -f $config_file ]]; then
  printf 'Refusing to edit non-regular SSH config: %s\n' "$config_file" >&2
  exit 1
fi

tmp_file=$(mktemp "$config_file.tmp.XXXXXX")
trap 'rm -f "$tmp_file"' EXIT

if [[ -f $config_file ]]; then
  seen_start=0
  seen_end=0
  inside=0
  invalid=0
  line_count=0

  while IFS= read -r line || [[ -n $line ]]; do
    line_count=$((line_count + 1))

    if [[ $line == "$start_marker" ]]; then
      if (( seen_start || inside || seen_end )); then
        invalid=1
        continue
      fi

      seen_start=1
      inside=1
      printf '%s\n%s\n%s\n' "$start_marker" "$comment_line" "$include_line"
      continue
    fi

    if [[ $line == "$end_marker" ]]; then
      if (( ! inside || seen_end )); then
        invalid=1
        continue
      fi

      inside=0
      seen_end=1
      printf '%s\n' "$end_marker"
      continue
    fi

    (( inside )) && continue
    printf '%s\n' "$line"
  done < "$config_file" > "$tmp_file"

  if (( invalid || inside || seen_start != seen_end )); then
    printf 'Invalid managed SSH config block in %s\n' "$config_file" >&2
    exit 1
  fi

  if (( ! seen_start )); then
    (( line_count == 0 )) || printf '\n' >> "$tmp_file"
    printf '%s\n%s\n%s\n%s\n' \
      "$start_marker" "$comment_line" "$include_line" "$end_marker" >> "$tmp_file"
  fi
else
  printf '%s\n%s\n%s\n%s\n' \
    "$start_marker" "$comment_line" "$include_line" "$end_marker" > "$tmp_file"
fi

chmod 600 "$tmp_file"

if [[ -f $config_file ]] && cmp -s "$tmp_file" "$config_file"; then
  exit 0
fi

mv -f "$tmp_file" "$config_file"
trap - EXIT
