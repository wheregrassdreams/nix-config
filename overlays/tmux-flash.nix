{ inputs, ... }:
final: prev:
let
  source = inputs.tmux-flash-rs;
  version = final.lib.removeSuffix "\n" (builtins.readFile "${source}/VERSION");
  binary = final.rustPlatform.buildRustPackage {
    pname = "tmux-flash";
    inherit version;
    src = source;
    cargoLock.lockFile = "${source}/Cargo.lock";
  };
  plugin = prev.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-flash";
    inherit version;
    rtpFilePath = "tmux-flash.tmux";
    src = source;
    postInstall = ''
      mkdir -p "$target/bin"
      install -m755 ${binary}/bin/tmux-flash "$target/bin/tmux-flash"

      # Nix-managed tmux servers use the bundled binary instead of downloading
      # a private GitHub release at runtime.
      cat > "$target/scripts/install-tmux-flash" <<'EOF'
      #!/bin/sh
      set -eu
      script_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
      binary="$script_dir/bin/tmux-flash"
      [ -x "$binary" ] || exit 1
      printf '%s\n' "$binary"
      EOF
      chmod 755 "$target/scripts/install-tmux-flash"
    '';
    meta = {
      description = "Standalone tmux flash search and jump plugin";
      homepage = "https://github.com/wheregrassdreams/tmux-flash-rs";
      platforms = final.lib.platforms.unix;
    };
  };
in
{
  tmuxPlugins = prev.tmuxPlugins // {
    tmux-flash = plugin;
  };
}
