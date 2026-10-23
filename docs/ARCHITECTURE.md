# Architecture

## Composition

Each host owns machine facts and chooses exported capability packages. The
flake discovers hosts from their local descriptors and builds system plus
standalone Home outputs:

```text
flake.nix -> flake-parts -> hosts -> package registries -> package configuration
```

`flake-parts/outputs.nix` scans direct child directories of `hosts/` for
`host.nix`. The directory name becomes the output host name. There is no
aggregate host registry and no profiles layer.

- `hosts/<host>/host.nix` owns `outputType` (`darwin` or `nixos`), host identity, machine facts, and
  capability selection. Its presence registers that host with the flake.
- The system architecture remains in `system`; `outputType` selects the flake
  output and builder. `userName` is derived from `identity.username`.
- `hosts/<host>/home.nix` and `system.nix` own host-local values
  and settings. This includes Home Manager username and locale.
- `flake-parts/` owns flake-parts output composition and input partitions.
  `flake.nix` declares the root inputs and imports this composition.
- `integrations/staging/<name>/` holds temporary child flakes for external projects
  whose integration interfaces are still evolving. Hosts select adapters
  explicitly; reevaluate them after the upstream APIs stabilize. These are
  local flake boundaries, not flake-parts partitions.
- `flake-parts/partitions/darwin/` and `nixos/` hold platform-only flake
  inputs. The matching flake-parts partition builds only that platform's system outputs;
  shared inputs and standalone Home outputs stay in the root graph.
- `overlays/` owns shared package-set extensions. `overlays/default.nix`
  discovers local overlay files and composes them with upstream overlays;
  `pkgs.unstable` exposes rolling nixpkgs, while `pkgs.latestAgents` exposes
  the daily-updated agent package set for explicit, per-application opt-in.
  Platform-only system builders and inputs remain in their partitions.
- `modules/home/core/` is the shared Home context package. It owns identity,
  path contracts, and the common SOPS/age user environment.

## Capability packages

A directory with `default.nix` is a package entry point and is discovered as an
output. A directory without one can organize related packages. Organizational
groups do not automatically become packages:

- `ai/` groups AI application packages and shared agent resources.
- `connectivity/` groups user-level connectivity tools such as SSH and
  Tailscale clients.
- `desktop/` groups desktop application packages. A package may configure
  both GUI and CLI behavior when they form one user-facing capability.
- `dev/` groups development packages such as language packages under
  `dev.langs.*`, `dev.tools`, and `dev.ci`.
- `storage/` groups shared remote endpoint declarations and file/state backup
  packages under `storage.remote` and `storage.backup`; it is not itself a
  package.
- `terminal/` owns the terminal product and its `shell`, `tools`, and `tmux`
  packages.

Registry keys preserve dotted paths, for example
`homeModules."ai.codex"`, `homeModules."connectivity.tailscale"`,
`homeModules."desktop.browser"`, `homeModules."dev.langs.go"`, and
`homeModules."dev.kubernetes"`.

Package boundaries represent user-facing capabilities, not an inventory of
installed applications. An application or tool that implements a broader
capability belongs inside that capability, optionally under the platform where
it applies. For example, keyboard mapping is `desktop.input`; Karabiner is a
macOS implementation of it, not a separate `desktop.karabiner` capability.
Ghostty and Kitty are distinct terminal applications, so their configurations
can live in separate directories under `terminal` without becoming separate
packages. Use an application as a package boundary when users select and
configure that application as a capability in its own right. Add a platform
directory only when the implementation or configuration is actually
platform-specific.

The desktop group includes the capability packages `agent`, `apps`, `browser`,
`editor`, `files`, `input`, `launcher`, `menubar`, `note`, `password`,
`terminal`, and `window-manager`;
`dock` is a Home Manager package for user Dock layout. Keep cross-platform
applications grouped by application when their configuration differs, as with
`terminal/ghostty/` and `terminal/kitty/`. Use a `macos/` or `darwin/` subtree
when configuration is specific to that platform, as with Finder, Karabiner,
menubar management, and Dock. Keep an application and its configuration
assets together, such as the Zed keymap under `editor/zed/`. These internal
directories do not create packages unless they have their own `default.nix`.
Desktop capability packages select applications using compact keys such as
`kagimacos`, `zed`, or `ghostty`. On macOS, activation scans installed app
bundles and resolves those keys from the final component of each bundle ID,
expanding collisions deterministically. The `desktop.apps` integration package
refreshes this local cache after Homebrew synchronization; it is a runtime
machine fact, not a flake input. Vicinae first uses the previous cache so its
LaunchAgent can start without waiting for Homebrew, then refreshes its aliases
and restarts only Vicinae if they changed. Editor file associations use the
refreshed identities. Browser selection remains owned by the browser package.
This lookup is platform-specific and does not treat a macOS bundle ID as a
Linux desktop entry ID.

Within a package:

- `default.nix` marks the package and assembles its configuration.
- A package owns its public options. Importing the package selects the
  capability; `enable` is for optional subfeatures, not the package itself.
- When present, the package root's `options.nix` is imported automatically by
  `mylib.importAll ./.`; the scanner then collects other `.nix` configuration
  files recursively in deterministic path order.
- If configuration collection is platform-gated, import the root options on
  platforms where `mylib.importAll` is skipped.
- Files and directories beginning with `_` are excluded from discovery and
  may still be imported explicitly by a consumer.
- A child directory with its own `default.nix` is a separate package. Parent
  package collection skips that directory; hosts choose parent and child
  packages independently.
- `lib/` contains implementation helpers and is imported explicitly, never
  discovered as configuration.
- Feature fragments read their package options from `config` and gate optional
  behavior with `lib.mkIf`.
- Packages limited to one OS import `mylib.assertPlatform` in their entry
  point. Selecting one from an incompatible host fails evaluation with the
  package name and supported OS instead of silently producing a partial setup.
- Keep small packages compact. Use source comments for non-obvious behavior;
  add a README when package boundaries or lifecycle rules need more context.

## Product packages

### Terminal

`terminal.shell` owns Zsh, prompts, shell integrations, `direnv`, and Atuin.
Atuin is selected as an optional shell-history feature. In the current host
configuration it owns `Ctrl-R`, leaves the up-arrow behavior alone, and
automatically syncs to the declared self-hosted endpoint
`https://atuin.wheregrassdreams.top`. Server availability, account
registration, and sync were verified on 2026-10-17 using disposable clients
and synthetic history only. The managed Home Manager output evaluates to this
endpoint with `auto_sync = true`; the endpoint's `/healthz` check returned 200
over HTTPS with certificate verification enabled. The regular MacBook client
remains logged out, and no existing shell history was imported.
Zsh prioritizes the Home Manager profile in `PATH`, so editors and terminals
resolve declared tools and language servers before unmanaged copies.

`terminal.tools` is the everyday command-line package. Its files provide soft
internal groupings such as search/data, interactive tools, files, clipboard,
web, and SSH helpers; those groups are not separate packages. The full package
is the default. Its `minimal` option keeps the core everyday set and omits
extended utilities. `television` and media tools remain optional subfeatures.
`xh`, `sshpass`, `trzsz-ssh`, `rclone`, and command-line clipboard tools live
here for now. The `trash PATH...` command sends files to the platform's native
trash: macOS uses its system Trash, while Linux uses the FreeDesktop trash.
`act` belongs to `dev.ci`, not terminal tools.
The native `terminal.tmux` package retains the repository's original
configuration and remains selected by WSL. The MacBook host comments out that
package and selects `staging.tmux-config`, which owns the external tmux package,
server LaunchAgent, configuration reload, and quickpane reconciliation. Ghostty
uses the selected package from `programs.tmux.package`. The staging adapter
exports its resurrect snapshot directory as
`my.paths.exported."staging.tmux-config.resurrect"`.

### Connectivity and desktop

`connectivity.ssh` owns the Home Manager SSH client configuration. The NixOS
SSH server adapter remains in `modules/system/nixos/`; platform-specific server
behavior is not combined with the Home client package.

The former `gui/` package group is named `desktop/`. Product boundaries follow
the user capability rather than a strict GUI/CLI split. Finder preferences,
archive extraction, and optional DiskTree filesystem usage browsing belong to
`desktop.files`; DiskTree's macOS release derivation belongs to `overlays/`.
Keyboard mapping and pointer scrolling tools belong to `desktop.input`; Raycast
belongs to `desktop.launcher`. `desktop.dock` configures a user's Dock through
Home Manager, not the Darwin system activation phase. Host-specific
applications without an established shared capability remain declared by that
host instead of being grouped into a `workspace` catch-all. `networking/` is
named `connectivity/`, with options under `my.connectivity`.
`desktop.launcher` imports Vicinae's official Home Manager module from the
`vicinae` flake. It installs the flake package, writes settings, manages the
macOS LaunchAgent, and installs the four used Raycast extensions (`brew`,
`clean-keyboard`, `downloads-manager`, and `video-downloader`) from a pinned
Raycast extensions revision. The Home Manager module bundled with Vicinae
replaces the Linux-only module from Home Manager 25.11. The proprietary Chrome
browser is installed outside Home Manager, so its native-messaging integration
is disabled.

### Development and paths

`dev/` is an organizational group. `dev/langs/` organizes one package per
language; shared development utilities live in `dev.tools`, and local CI tools
live in `dev.ci`.

The `staging.reprise` Home Manager module is an explicit host-selected
integration from `integrations/staging/reprise`. The staging flake owns project
inventory and snapshot configuration, commands, and services. A small root
bridge in `integrations/staging/reprise-bridge.nix` resolves the declared
storage target and passes the concrete Git destination. Reevaluate this boundary after
Reprise's API stabilizes.

`terminal.tmux` preserves the repository's original tmux configuration.
`integrations/staging/tmux-config` is an adapter imported explicitly by the
MacBook host; other hosts such as WSL continue to select `terminal.tmux`.

`dev.langs.go` uses the pinned `pkgs.unstable.go_1_27` package and sets
`GOTOOLCHAIN=local`, so Go uses the Nix-managed 1.27 toolchain instead of
downloading a second toolchain at first invocation. Go manages its module and
build cache contents; the module cache path is configurable, while the build
cache uses the package's XDG-based default.
Home Manager's package profile is
placed before `my.paths.localBin` so declared tools win name collisions while
project-specific binaries remain available. Development packages own their
concrete data paths. Go exposes `my.dev.langs.go.paths.moduleCache` as a
configuration option. JavaScript exposes Playwright browsers, pnpm's store
and metadata cache, npm cache, Bun's package cache, and Bun's runtime cache as
configurable `my.dev.langs.javascript.paths` values. These and Node compile
and node-gyp caches use XDG cache defaults. Deno's cache uses `~/.cache/deno`
while its CLI package is selected. pnpm 10 and 11 receive
compatible environment settings for their shared store and metadata cache.
The selected packages register their effective paths with
the generic `my.paths.exported` contract. Their
`NIX_CONFIG_PATH_*` shell exports are intentionally dormant until a concrete
downstream consumer needs them; package configuration uses the paths directly.
Node-gyp owns its downloaded, version-specific headers. Remove obsolete versions explicitly with
`node-gyp remove <version>` after checking project targets; do not prune
automatically because native builds may target a Node version other than the
active runtime. Project manifests own the Playwright library version.
Kubernetes CLI tools live
in `dev.kubernetes`;
the full package includes kubectl, k9s, Helm, Kustomize, kubectx, stern, and
Flux, while `my.dev.kubernetes.minimal` retains kubectl and k9s. `langs/` is
the organizational directory for language packages, whose path options use
the `my.dev.langs.<language>` namespace.

AI CLI packages use `pkgs.latestAgents`, backed by the agent package
maintainer's rolling nixpkgs set. The lock file pins that package source and
`nix flake update llm-agents` advances the agent packages together. Generic
fast-moving packages can use `pkgs.unstable` independently.

`home.core` owns the shared identity and path context. Its paths component
owns generic path roots, host-specific personal locations, and
the export mechanism. A shared naming function generates active personal
`NIX_CONFIG_PATH_*` and `NIX_CONFIG_XDG_*` variables and validates path-name
collisions. Capability packages can register path contracts without adding
their paths to a central catalogue; package path exports stay commented out
until shell-level consumers are established.

`core` is the Home host-context package, not a baseline application bundle.
Hosts provide its identity and personal path values. It provides SOPS/age
support to every selected Home host; consumers still declare which encrypted
secrets they use. It does not select Git, SSH, or everyday tools by implication.

## Package relationships

- Hosts select packages and provide host-specific values. Shared capabilities
  remain one-way dependencies; reusable cross-package coordination can become
  an integration package when concrete reuse exists.
- `ai.<application>` packages own application-specific configuration; CC Switch
  is included as the AI provider manager. `ai.agent-resources` owns the shared
  agent resource paths and runtime directories under `~/.agents/`. Skills
  stored in `resources/agents/skills/` are linked individually into
  `~/.agents/skills/`, leaving other client- or user-managed skills alone.
- `resources/agents/skills/` is the versioned source for shared skills.
  `just agent-skills-find` delegates discovery to `npx skills`; `just
  agent-skills-add` fetches a selected skill into the repository and records
  its source in `resources/agents/sources.json`. The checked-in files, not a
  network fetch during Home Manager activation, are the deployed version.
  `just agent-skills-update` explicitly refreshes one recorded source; review
  the content diff before committing. Locally authored skills can be added
  directly to the same directory without a source record. MCP discovery,
  ownership, and application-specific activation remain unsettled; this skill
  workflow does not imply that shared MCP inventory is active client config.
- Darwin application packages declare Homebrew casks through the stable
  Homebrew interface and depend on the full `homebrew` package. Their package
  entry points include that dependency only on Darwin, so Linux hosts do not
  receive Brewfile generation or synchronization behavior. Applications
  packaged directly by Nix can instead expose their `.app` bundle through a
  Home Manager link in `~/Applications`, as with AeroSpace and CC Switch.
- The Home Manager Homebrew package owns the generated Brewfile and
  user-level synchronization. The Darwin platform package owns the Homebrew
  installation substrate. Cleanup remains an explicit operation.
- `just homebrew-drift-check` compares installed Homebrew formulae and casks
  with the active generated Brewfile. `my.homebrew.driftCheck.enable` adds a
  weekly Monday 09:00 LaunchAgent that runs the same check and notifies only
  when inventory differs. Both paths are read-only; they do not remove
  undeclared software or inspect application data.
- `brew nix-report` is a read-only Homebrew external command provided by the
  Homebrew package. It reports inventory drift, Homebrew storage directory
  sizes, and the native `brew cleanup --dry-run` preview. Formulae installed
  on request and casks absent from the Brewfile are reported as declaration
  candidates; formulae installed only as dependencies are excluded. It never
  changes package declarations, installed packages, or cache contents. The
  weekly drift check reuses its inventory-only mode.
- `brew nix-sync` runs the same Nix-generated Brewfile synchronization used by
  Home Manager activation. It accepts explicit `--update`, `--upgrade`,
  `--cleanup`, and `--zap` overrides; by default it does not update Homebrew
  metadata, upgrade installed packages, or remove undeclared packages.
- `my.services` owns local processes and client tools only. It does not own
  durable service data, backups, or restoration.

## State and recovery

State belongs to the capability that creates or manages it. The long-term
direction is for packages to describe their own state (for example, tmux
Continuum history or an agent application's sessions), while shared
backup/recovery logic applies policy, collects data, tracks copies, and
supports restoration.

`storage.backup` implements file/path backups with Restic. Data owners register
datasets; the backup package maps their optional `critical`, `valuable`, or
`rebuildable` class to a repository, schedule, and retention policy. The
default class is `valuable`. Repositories bind a registered S3 or WebDAV
target to a Restic password file; S3 credentials, rclone configuration, and
SSH identities are referenced from host-managed secret/configuration paths.
Repositories can opt into `initIfMissing`, which initializes only when
Restic confirms that the repository is absent. Restore defaults to a separate
staging directory. `backup-check` runs Restic repository integrity checks;
`backup-init` remains available for explicit initialization. Automated
restore drills are out of scope.

`storage.remote` owns only shared endpoint registration in
`my.storage.remote.targets`.
Snapshot and backup products own their own schedules, paths, and retention.
Its explicitly imported `lib/targets.nix` provides shared target lookup,
backend access, and path joining. `lib/clients.nix` exposes Git/OpenSSH and
Restic client wiring, including Restic's native S3 and rclone-backed WebDAV
connections. Products retain their own operations and runtime behavior. Git
targets support the `sshBare`, `gitea`, and `giteaPreprovisioned` snapshot
provisioners used by the staging Reprise bridge.
Synchronization products, iCloud, and Syncthing are deferred until they have
concrete directory and conflict semantics. Data-owning capabilities register
concrete paths with `my.storage.backup.datasets` when a backup repository and
policy are configured; `my.paths.personal` continues to own the notes path
itself.

## Machine autonomy

Machine autonomy means the configured machine can explain and check its own
state against declarations, then carry out only the changes whose ownership
and safety rules are explicit. It is not a goal to make every machine change
automatic. Nix declarations are the desired-state authority; observed state is
evidence to compare with them, not a second source of truth.

Tools that support this direction should follow this loop:

```text
declare -> observe -> compare -> report or plan -> reconcile when authorized
```

- **Keep ownership local.** The package that selects or configures a capability
  should own the contract for checking its installed state, runtime state, and
  paths. A shared runner may collect those checks, but should not guess what
  arbitrary files or applications mean.
- **Make findings explainable.** A report should identify the declaration,
  observed evidence, and the reason for a mismatch. Missing evidence should be
  shown as unknown, not treated as proof that something is unused.
- **Separate observation from mutation.** Inventory and health checks are
  read-only by default. A plan should show the exact target and expected effect
  before a cleanup, migration, or repair changes machine state.
- **Automate only bounded reconciliation.** Automatic actions are appropriate
  when the desired state is explicit, the action is repeatable, and failure
  does not destroy user data. Deletion and data migration need an explicit
  product-specific policy and a reviewable recovery path; backup retention and
  restore behavior are declared by `storage.backup`.
- **Prefer small consumers over universal scanners.** A path or state registry
  is useful when a real consumer uses it. Do not create a central catalogue
  that packages must duplicate or maintain without a concrete operational use.

The current Homebrew drift check is a read-only comparison between the
Homebrew inventory and the generated Brewfile. `storage.backup` runs declared
dataset backups and applies explicit retention. The staging Reprise module
runs inventory review and Git workspace snapshots under its own policy.

`just paths-report` consumes the active host's `my.paths.exported` values and
reports each registered path's disk usage or missing status. It does not scan
for unregistered legacy paths, infer whether a path is in use, or remove data.

Future machine checks may aggregate package-owned reports, such as whether a
declared command resolves to the managed version, whether an expected service
is healthy after activation, or which registered cache paths are large and
stale. Aggregation should preserve each finding's owning package and evidence.
Cache cleanup may start as a reviewable plan; it should not infer that a path
is disposable from age or size alone. File and state backup behavior is
governed by the explicit dataset classes, repositories, schedules, and restore
rules in `storage.backup`; this does not imply a machine-wide cleanup policy.

## System packages

The system registry exports one platform package per target:

- `darwinModules.platform` configures the Darwin substrate and imports
  platform-local behavior, including Homebrew installation.
- `nixosModules.platform` configures the NixOS/WSL substrate and SSH server
  adapter.

`modules/system/shared/` is a system configuration package for behavior shared
by Darwin and NixOS. Platform packages depend on it one way. It is separate
from platform-local `lib/` implementation helpers. Home Manager packages do
not import Darwin or NixOS implementations.

## Flake partitions

Development-only inputs stay in the `dev` partition under
`flake-parts/partitions/dev/`; Darwin system inputs stay in
`flake-parts/partitions/darwin/`; and NixOS system inputs stay in
`flake-parts/partitions/nixos/`. The `darwinConfigurations` and
`nixosConfigurations` output attributes are evaluated in their matching
partitions. Shared Home Manager
outputs and reusable capability registries remain in the root graph. This
keeps platform builders and their inputs out of the other platform's system
output evaluation without reorganizing product packages by OS. Shared overlays
are composed once and applied to both system and Home Manager package sets;
Home packages with a real OS restriction also assert their supported platform
when selected.

## Non-Nix assets and secrets

- `resources/` holds versioned configuration deliberately deployed outside
  Nix. Neovim remains a manual symlink from `resources/nvim`.
- `resources/agents/` is reserved for shared agent MCP and skills source files
  once their consuming applications and deployment behavior are wired.
- `secrets/` holds encrypted SOPS data only. Never add plaintext credentials.
- Windows configuration remains out of scope; WSL integration is in scope.
