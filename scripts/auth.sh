#!/bin/bash
set -euo pipefail

# 配置 GitHub token，供后续 Nix 命令访问私有仓库；不更新 flake.lock。
nix_config="${XDG_CONFIG_HOME:-$HOME/.config}/nix/nix.conf"
mkdir -p "$(dirname "$nix_config")"
temporary_config=$(mktemp)
trap 'rm -f "$temporary_config"' EXIT

if [[ -f "$nix_config" ]]; then
  awk '!/^[[:space:]]*access-tokens[[:space:]]*=/' "$nix_config" > "$temporary_config"
fi

printf 'access-tokens = github.com=%s\n' "$(gh auth token)" >> "$temporary_config"
mv "$temporary_config" "$nix_config"
