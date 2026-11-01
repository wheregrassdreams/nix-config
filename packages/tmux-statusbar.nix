{ inputs, ... }:
final: prev:
let
  source = inputs.tmux-statusbar;
  marquee = final.rustPlatform.buildRustPackage {
    pname = "tmux-statusbar-session-marquee";
    version = "0.1.0";
    src = "${source}/session-marquee";
    cargoLock.lockFile = "${source}/session-marquee/Cargo.lock";
  };
  plugin = prev.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-statusbar";
    version = "0.1.0";
    rtpFilePath = "tmux-statusbar.tmux";
    src = "${source}";
    postInstall = ''
      mkdir -p "$target/bin"
      install -m755 ${marquee}/bin/session-marquee "$target/bin/session-marquee"

      # Use the bundled renderer instead of the standalone plugin's release
      # downloader. The tmux server can start offline and without GitHub auth.
      cat > "$target/scripts/install-session-marquee" <<'EOF'
      #!/bin/sh
      set -eu
      script_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
      renderer="$script_dir/bin/session-marquee"
      [ -x "$renderer" ] || exit 1
      printf '%s\n' "$renderer"
      EOF
      chmod 755 "$target/scripts/install-session-marquee"
    '';
    meta = {
      description = "Standalone tmux status bar with optional session marquee";
      homepage = "https://github.com/wheregrassdreams/tmux-statusbar";
      platforms = final.lib.platforms.unix;
    };
  };
in
{
  tmuxPlugins = prev.tmuxPlugins // {
    tmux-statusbar = plugin;
  };
}
