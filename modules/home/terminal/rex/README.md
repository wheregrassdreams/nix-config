# terminal.rex

Declarative half of the [Rex](https://www.superlogical.com/rex) terminal
multiplexer (Superlogical, closed beta).

## What is managed

- `rex` on `PATH`: a wrapper around the CLI shipped inside the app bundle at
  `/Applications/<bundle>/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex`.
  The wrapper probes `my.terminal.rex.appBundles` in order at runtime, so a
  beta rename only needs a new entry in that list.
- `~/.config/rex/init.lua`: the keybindings file. Rex reads it and never
  writes it, so it is a read-only store symlink.
- `rex skill setup` on activation: keeps the Claude/Codex/OpenCode skill and
  hook entries current. It only touches its own entries and is safe to repeat.
- `rex config reload --autostart=false` after linking, so a running server
  picks up a changed `init.lua` without starting one.

## What is not managed

The GUI app itself. There is no Homebrew cask and no nixpkgs package, and the
app is a Sparkle self-updating beta, so a pinned DMG would fight its updater.
Install it by hand until upstream ships a cask; this module only takes over
the CLI and configuration.

## Checks

```sh
rex config check
rex keymap
```

If the app moves the helper out of `Contents/Helpers`, update the wrapper path
in `default.nix` and bump `appBundles` as needed.
