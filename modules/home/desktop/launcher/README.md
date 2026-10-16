# Launcher

`vicinae.nix` owns settings shared by desktop platforms. `macos/` configures
the launch agent and Raycast Store extensions; `linux/` configures the user
systemd service. The package supports Darwin and Linux, but hosts still choose
whether to import it.

Raycast Store extensions are prebuilt by Raycast and installed into
`$XDG_DATA_HOME/vicinae/extensions/store.raycast.<name>` during Home Manager
activation. The installer resolves a fresh store download URL, then verifies
the pinned upstream commit and archive SHA-256 before replacing the extension
directory. A network connection is needed when a pinned bundle is not already
installed or its pin changes. Extension support data under Vicinae's separate
`support/` path is left untouched. Updating an extension requires reviewing
and changing both its commit and archive hash.

Vicinae's Nix settings own stable aliases and the complete favorites list.
Application aliases and favorites are generated from the host's selected
default browser, terminal, and agent. `settings.json` stays writable for
Vicinae's GUI-managed preferences; it should not duplicate those aliases or
favorites because the Nix wrapper loads them as higher-priority overrides.

`lib/raycast-extensions.nix` also retains `mkRayCastExtension` for extensions
that need to be built from source instead of using a published bundle.
