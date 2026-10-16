{
  inputs,
  lib,
  pkgs,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  raycastRepoRev = "c4dc0113e4cb11bb2a0a8639af719aae5658d6da";
in
{
  # Keep the upstream source-build API available for extensions that need it.
  mkRayCastExtension =
    { name, sha256 }:
    inputs.vicinae.lib.${system}.mkRayCastExtension {
      inherit name;
      hash = sha256;
      rev = raycastRepoRev;
    };

  mkRayCastStoreExtensionSync =
    {
      dataHome,
      extensions,
    }:
    pkgs.writeShellApplication {
      name = "sync-vicinae-raycast-extensions";
      runtimeInputs = with pkgs; [
        coreutils
        curl
        jq
        unzip
      ];
      text = ''
        set -euo pipefail

        extension_dir=${lib.escapeShellArg "${dataHome}/vicinae/extensions"}
        mkdir -p "$extension_dir"
        tmpdir="$(mktemp -d)"
        active_target=""
        active_backup=""
        active_stage=""
        cleanup() {
          local status=$?
          if [ "$status" -ne 0 ] && [ -n "$active_backup" ] &&
            [ -e "$active_backup" ] && [ ! -e "$active_target" ]; then
            mv "$active_backup" "$active_target" || true
          fi
          if [ -n "$active_stage" ] && [ -d "$active_stage" ]; then
            rm -rf "$active_stage"
          fi
          rm -rf "$tmpdir"
        }
        trap cleanup EXIT

        install_extension() {
          local owner="$1"
          local name="$2"
          local expected_commit="$3"
          local expected_sha256="$4"
          local listing entry commit download_url archive unpacked target stage backup

          target="$extension_dir/store.raycast.$name"
          if [ -f "$target/.nix-config-archive-sha256" ] &&
            [ "$(cat "$target/.nix-config-archive-sha256")" = "$expected_sha256" ]; then
            return
          fi

          listing="$(curl -fsSL --get \
            --data-urlencode "q=$name" \
            --data-urlencode "cachebust=$(date +%s)" \
            https://backend.raycast.com/api/v1/store_listings/search)"
          entry="$(jq -er --arg owner "$owner" --arg name "$name" \
            '[.data[] | select(.owner.handle == $owner and .name == $name)] | if length == 1 then .[0] else error("extension not found uniquely") end' \
            <<<"$listing")"
          commit="$(jq -er '.commit_sha' <<<"$entry")"
          if [ "$commit" != "$expected_commit" ]; then
            printf 'Raycast extension %s/%s changed from pinned commit %s to %s; update its archive hash before installing.\n' \
              "$owner" "$name" "$expected_commit" "$commit" >&2
            return 1
          fi

          download_url="$(jq -er '.download_url' <<<"$entry")"
          case "$download_url" in
            https://extensions.raycast-releases.com/*) ;;
            *)
              printf 'Unexpected Raycast extension download host for %s.\n' "$name" >&2
              return 1
              ;;
          esac
          archive="$tmpdir/$name.zip"
          unpacked="$tmpdir/$name"
          curl -fsSL "$download_url" -o "$archive"
          printf '%s  %s\n' "$expected_sha256" "$archive" | sha256sum --check --status
          mkdir -p "$unpacked"
          unzip -q "$archive" -d "$unpacked"
          if [ ! -f "$unpacked/$name/package.json" ]; then
            printf 'Raycast archive for %s has no package.json.\n' "$name" >&2
            return 1
          fi

          stage="$extension_dir/../.store.raycast.$name.stage-$$"
          active_stage="$stage"
          mkdir -p "$stage"
          cp -R "$unpacked/$name/." "$stage/"
          printf '%s\n' "$expected_sha256" > "$stage/.nix-config-archive-sha256"

          backup="$tmpdir/$name.previous"
          active_target="$target"
          active_backup="$backup"
          if [ -e "$target" ] || [ -L "$target" ]; then
            mv "$target" "$backup"
          fi
          if ! mv "$stage" "$target"; then
            if [ -e "$backup" ]; then
              mv "$backup" "$target"
            fi
            return 1
          fi
          active_stage=""
          active_backup=""
          active_target=""
        }

        ${lib.concatMapStringsSep "\n" (
          extension:
          "install_extension ${
            lib.escapeShellArgs [
              extension.owner
              extension.name
              extension.commit
              extension.sha256
            ]
          }"
        ) extensions}
      '';
    };
}
