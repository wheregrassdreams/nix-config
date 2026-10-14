# Architecture

## Composition model

The host registry is the single source for system and standalone Home outputs.
Each host declares its machine facts and selects exported capability packages
directly:

```text
flake outputs -> configurations/hosts -> package registries -> package configuration
```

`configurations/hosts/default.nix` explicitly maps host names to host
descriptors. The flake iterates this map to create the matching Darwin or
NixOS output and the standalone Home Manager output. A host descriptor refers
to capability values such as `self.homeModules."gui.browser"`; it does not
name a reusable profile.

- `configurations/hosts/<host>/default.nix` owns platform, host identity,
  capability selection, and machine facts.
- `configurations/hosts/<host>/home.nix` and `system.nix` hold settings local to
  that host and target.
- There is no `configurations/profiles/` layer.
- There is no global `modules/options/` layer. A package owns its public option
  declarations beside its entry point.
- `modules/flake-parts/` owns flake output composition and input partitions.

## Capability packages

A directory with `default.nix` is a package entry point and is eligible for
discovery. Directories without an entry point can organize related packages.
The `ai/`, `gui/`, and `networking/` directories are organizational groups;
they do not export a parent package. Registry keys preserve the dotted path,
for example `homeModules."ai.codex"` or
`homeModules."networking.tailscale"`.

The chosen implementation names include `modules/home/langs/` and
`modules/home/networking/`. These directory names are independent from option
namespaces such as `my.development` and `my.connectivity`.

Within a package:

- `default.nix` is the main configuration module and package marker.
- `options.nix` declares the package's public options when it has a stable
  configuration interface.
- Keep small packages directly in the package directory. Use meaningful
  subdirectories such as `tmux/` or `zsh/` when they clarify ownership; a
  generic `module/` directory is not required.
- A package entry point may collect configuration `.nix` files from its own
  directory tree, excluding its entry point, options declaration, and `lib/`.
- Compose configuration with ordinary Nix module `imports`. Feature fragments
  read their package options from `config` and gate their settings with
  `lib.mkIf` rather than receiving ad hoc arguments from the package entry.
- `lib/` contains concrete implementation helpers and is imported explicitly;
  it is never auto-collected as configuration.
- Source comments should explain non-obvious behavior. Add a README only when
  a package has boundaries or lifecycle rules that are not clear from source.

Not every directory needs all of these files. Small packages remain compact.
The `editor/` directory at the Home root remains an unregistered placeholder;
the current editor package is `gui.editor`.

## Package relationships

- Hosts choose packages and provide host-specific values. They are the
  composition roots, not shared capability libraries.
- `ai.<application>` packages own each agent application's options and
  configuration. `ai/` only groups those packages.
- `agent-resources` currently owns the shared agent resource environment
  variables and runtime directories. The source and deployment contract for
  repository-managed `.agent/` MCP and skills resources is still being worked
  out; do not infer an application-specific layout from this package.
- GUI applications declare their Homebrew casks through the stable Homebrew
  interface. The host combines those packages with `homebrew` on macOS.
- The Home Manager Homebrew package owns the generated Brewfile and
  user-level synchronization. The Darwin platform package owns the
  Homebrew installation substrate. Cleanup remains an explicit operation.
- `my.services` owns local processes and client tools only. It does not own
  durable service data, backups, or restoration.
- Direct cross-package definitions are appropriate for stable, one-way
  dependencies. Reusable coordination across packages should become an
  integration package when that need is concrete.

## State and recovery direction

State belongs to the capability that creates or manages it. The long-term
direction is for packages to describe their own state (for example, tmux
Continuum history or an agent's sessions), while shared backup/recovery logic
applies policy, collects data, tracks copies, and supports restoration.

The policy model is not finalized. Loss impact (including level 3 historical
data, level 2 rebuildable caches, and critical data), content type (such as
code, binary files, logs, or databases), and available recovery source are
separate dimensions. No backup tool, retention policy, or critical-data level
is selected here. The existing `my.data` contract remains transitional until
that model is researched and agreed.

## Platform packages

The system registry exports one platform package per target:

- `darwinModules.platform` configures the Darwin substrate and imports its
  platform-local behavior, including Dock and Homebrew installation.
- `nixosModules.platform` configures the NixOS/WSL substrate and SSH server
  adapter.

Home Manager and system adapters remain separate. A Home package must not
import a Darwin or NixOS implementation, and a platform adapter must not
import Home Manager behavior.

## Flake partitions

The root flake uses flake-parts for explicit output composition. Development-
only inputs stay in the `dev` partition under
`modules/flake-parts/dev/`; they do not enter the base deployment input graph
without a current base-output consumer.

## Non-Nix assets and secrets

- `resources/` holds versioned configuration deliberately deployed outside
  Nix. Neovim remains a manual symlink from `resources/nvim`.
- `.agent/` is the intended source location for shared MCP and skills
  resources once their deployment and application-consumption contract is
  established.
- `secrets/` holds encrypted SOPS data only. Never add plaintext credentials.
- Windows configuration remains out of scope for this repository; WSL
  integration is in scope.
