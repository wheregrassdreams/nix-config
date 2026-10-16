# AGENTS.md

## Repository model

This is a Nix flake for the MacBook and NixOS WSL. Read
[`ARCHITECTURE.md`](docs/ARCHITECTURE.md) before changing package boundaries.
The composition chain is:

```text
flake output -> flakes -> discovered hosts -> exported capability packages
```

- `hosts/<host>/host.nix` marks a host and owns its machine facts and selected
  packages. `flakes/outputs.nix` discovers these files and drives system plus
  standalone Home Manager outputs; there is no aggregate host registry.
- Each host owns its machine facts, local settings, and selected capability
  packages. There is no profiles layer.
- A package is discovered from its `default.nix`; groups such as `ai/`,
  `connectivity/`, `desktop/`, and `dev/` have no package entry point of
  their own. `terminal/` owns the terminal capability and its shell, tools,
  and tmux packages.
- Package options live with the package. There is no global `modules/options/`
  tree.
- `modules/home/` is Home Manager-only. `modules/system/` owns Darwin/NixOS
  behavior. Neither imports the other's implementation.
- `flakes/` owns flake output composition and input partitions. Development-only
  inputs live under `flakes/dev/`.
- `resources/` holds versioned configuration deliberately deployed outside
  Nix. `resources/agents/` is the intended source for shared agent resources;
  `ai.agent-resources` manages the user-level `~/.agents/` directory. The
  application-consumption contract for MCP resources is still being settled.
- `secrets/` holds encrypted SOPS data only.

The canonical outputs are `darwinConfigurations.macbook`,
`nixosConfigurations.wsl`, `homeConfigurations.zanelu@macbook`, and
`homeConfigurations.zane@wsl`. The old
`homeConfigurations.zanelu-macbook` alias has been removed.

## Local development

```zsh
just check
just fmt
just build
just test
just switch
```

On macOS, `just switch` owns OS/bootstrap changes and its embedded Home
Manager activation. `just switch-home` is the standalone, user-environment
only path. Formulae, casks, taps, and Homebrew service lifecycle are included
in the embedded Home Manager activation. `brew-sync --cleanup` and
`brew-sync --zap` are explicit destructive actions; never make undeclared-
package cleanup automatic without a requested change.

Do not claim a host is usable merely because evaluation succeeds. A rebuild
must be followed by host-appropriate boot, service, and recovery verification.

## Package conventions

- `default.nix` marks a package and assembles its configuration.
- `options.nix` owns that package's public option interface when needed.
- Keep small packages directly in their package directory. Use meaningful
  subdirectories such as `tmux/` or `zsh/` when they clarify ownership; do not
  create a generic `module/` directory.
- Package entry points use `repoLib.importAll ./.`, which imports the package
  root's `options.nix` when present, then collects other configuration `.nix`
  files below the package, excluding `default.nix`, `options.nix`, `_`-prefixed
  names, `lib/`, and child package directories. If collection is platform-gated,
  import the root options explicitly on platforms where collection is skipped.
- Prefer ordinary Nix module `imports`; feature fragments read their own
  package options from `config` and gate their settings with `lib.mkIf`.
- `lib/` contains technical implementation helpers and is imported explicitly,
  never as configuration discovery.
- Use `dev/langs/`, `connectivity/`, and `desktop/` for the chosen
  implementation directories; do not infer public option names from directory
  names.
- `terminal.shell` owns shell configuration, including Atuin and direnv.
  `terminal.tools` is the everyday CLI package, internally grouped by source
  file; `minimal` is an optional reduced set. Development utilities belong in
  `dev/`.
- Host settings own Home Manager username and locale. Hosts select
  `home.core` for shared identity, path, and secrets context.
- Keep direct package dependencies stable and one-way. Add an integration
  package when reusable cross-package coordination is concrete.
- Keep development-only inputs in the `dev` partition under `flakes/dev/`;
  do not move optional inputs into the root graph without a current
  base-output consumer.
- `my.services` owns local processes and client tools only. It never owns
  durable service data, backups, or restoration.
- State backup classification and tooling are not finalized. Do not add a
  backup tool or claim recovery behavior until that model is agreed.

## Secrets and non-Nix assets

Use SOPS/age for secrets and never add plaintext credentials. Neovim remains a
manual symlink from `resources/nvim`. Windows configuration is out of scope;
do not add it here.
