# Architecture

## Composition

Each host owns machine facts and chooses exported capability packages. The
flake discovers hosts from their local descriptors and builds system plus
standalone Home outputs:

```text
flake.nix -> flakes -> hosts -> package registries -> package configuration
```

`flakes/outputs.nix` scans direct child directories of `hosts/` for
`host.nix`. The directory name becomes the output host name. There is no
aggregate host registry and no profiles layer.

- `hosts/<host>/host.nix` owns `outputType` (`darwin` or `nixos`), host identity, machine facts, and
  capability selection. Its presence registers that host with the flake.
- The system architecture remains in `system`; `outputType` selects the flake
  output and builder. `userName` is derived from `identity.username`.
- `hosts/<host>/home.nix` and `system.nix` own host-local values
  and settings. This includes Home Manager username and locale.
- `flakes/` owns flake output composition and input partitions. `flake.nix`
  declares the root inputs and imports this composition.
- `flakes/darwin/` and `flakes/nixos/` hold platform-only flake inputs. The
  matching flake-parts partition builds only that platform's system outputs;
  shared inputs and standalone Home outputs stay in the root graph.
- `overlays/` owns shared package-set extensions. `overlays/default.nix`
  discovers local overlay files and composes them with upstream overlays;
  `pkgs.unstable` exposes rolling nixpkgs, while `pkgs.latestAgents` exposes
  the daily-updated agent package set for explicit, per-application opt-in.
  Platform-only system builders and inputs remain in their partitions.
- There is no `modules/home/base` package. Reusable path contracts belong to
  `modules/home/paths/` and are selected explicitly by hosts that use them.

## Capability packages

A directory with `default.nix` is a package entry point and is discovered as an
output. A directory without one can organize related packages. Organizational
groups do not automatically become packages:

- `ai/` groups AI application packages and shared agent resources.
- `connectivity/` groups user-level connectivity tools such as SSH and
  Tailscale clients.
- `desktop/` groups desktop application packages. A package may configure
  both GUI and CLI behavior when they form one user-facing capability.
- `dev/` groups development packages such as `dev.langs` and `dev.ci`.
- `terminal/` owns the terminal product and its `shell`, `tools`, and `tmux`
  packages.

Registry keys preserve dotted paths, for example
`homeModules."ai.codex"`, `homeModules."connectivity.tailscale"`,
`homeModules."desktop.browser"`, `homeModules."dev.langs"`, and
`homeModules."dev.kubernetes"`.

Within a package:

- `default.nix` marks the package and assembles its configuration.
- A package owns its public options. Importing the package selects the
  capability; `enable` is for optional subfeatures, not the package itself.
- When present, `options.nix` is imported explicitly by `default.nix`.
- The package entry point uses `repoLib.importAll ./.` to collect its other
  `.nix` configuration files recursively in deterministic path order.
- Files and directories beginning with `_` are excluded from discovery and
  may still be imported explicitly by a consumer.
- A child directory with its own `default.nix` is a separate package. Parent
  package collection skips that directory; hosts choose parent and child
  packages independently.
- `lib/` contains implementation helpers and is imported explicitly, never
  discovered as configuration.
- Feature fragments read their package options from `config` and gate optional
  behavior with `lib.mkIf`.
- Packages limited to one OS import `repoLib.assertPlatform` in their entry
  point. Selecting one from an incompatible host fails evaluation with the
  package name and supported OS instead of silently producing a partial setup.
- Keep small packages compact. Use source comments for non-obvious behavior;
  add a README when package boundaries or lifecycle rules need more context.

## Product packages

### Terminal

`terminal.shell` owns Zsh, prompts, shell integrations, `direnv`, and Atuin.
Atuin is selected as an optional shell-history feature. In the current host
configuration it records locally, owns `Ctrl-R`, leaves the up-arrow behavior
alone, and has automatic sync disabled.

`terminal.tools` is the everyday command-line package. Its files provide soft
internal groupings such as search/data, interactive tools, files, clipboard,
web, and SSH helpers; those groups are not separate packages. The full package
is the default. Its `minimal` option keeps the core everyday set and omits
extended utilities. `television` and media tools remain optional subfeatures.
`xh`, `sshpass`, `trash-cli`, and command-line clipboard tools live here for
now. `act` belongs to `dev.ci`, not terminal tools.

### Connectivity and desktop

`connectivity.ssh` owns the Home Manager SSH client configuration. The NixOS
SSH server adapter remains in `modules/system/nixos/`; platform-specific server
behavior is not combined with the Home client package.

The former `gui/` package group is named `desktop/`. Product boundaries follow
the user capability rather than a strict GUI/CLI split. `networking/` is named
`connectivity/`, with options under `my.connectivity`.

### Development and paths

`dev/` is an organizational group. Language support lives in `dev.langs` and
local CI tools in `dev.ci`. Kubernetes CLI tools live in `dev.kubernetes`;
the full package includes kubectl, k9s, Helm, Kustomize, kubectx, stern, and
Flux, while `my.dev.kubernetes.minimal` retains kubectl and k9s. `langs/` is
the chosen implementation name for the language package; its current options
use `my.dev.langs`.

AI CLI packages use `pkgs.latestAgents`, backed by the agent package
maintainer's rolling nixpkgs set. The lock file pins that package source and
`nix flake update llm-agents` advances the agent packages together. Generic
fast-moving packages can use `pkgs.unstable` independently.

`home.paths` owns the `my.paths` contract, generated `NIX_CONFIG_PATH_*`
variables, and collision validation. Hosts provide host-specific path values.

`core` is an architectural concept for ecosystem rules and conventions, not a
default package. It does not imply that Git, SSH, or a baseline Home package is
automatically selected.

## Package relationships

- Hosts select packages and provide host-specific values. Shared capabilities
  remain one-way dependencies; reusable cross-package coordination can become
  an integration package when concrete reuse exists.
- `ai.<application>` packages own application-specific configuration.
  `ai.agent-resources` owns the shared agent resource paths and runtime
  directories under `~/.agents/`.
- `resources/agents/` is the intended repository source for shared MCP and
  skills assets. App-specific MCP activation and resource deployment are not
  yet a settled contract; a shared MCP inventory must not be mistaken for an
  active client configuration.
- Darwin application packages declare Homebrew casks through the stable
  Homebrew interface and depend on the full `homebrew` package. Their package
  entry points include that dependency only on Darwin, so Linux hosts do not
  receive Brewfile generation or synchronization behavior.
- The Home Manager Homebrew package owns the generated Brewfile and
  user-level synchronization. The Darwin platform package owns the Homebrew
  installation substrate. Cleanup remains an explicit operation.
- `my.services` owns local processes and client tools only. It does not own
  durable service data, backups, or restoration.

## State and recovery

State belongs to the capability that creates or manages it. The long-term
direction is for packages to describe their own state (for example, tmux
Continuum history or an agent application's sessions), while shared
backup/recovery logic applies policy, collects data, tracks copies, and
supports restoration.

The policy model is not finalized. Loss impact, content type, and available
recovery source are separate dimensions. No backup tool, retention policy, or
critical-data level is selected. Do not infer recovery behavior from Atuin's
optional encrypted sync or from a package's local state directory. The
existing `my.data` contract remains transitional until the model is researched
and agreed.

## System packages

The system registry exports one platform package per target:

- `darwinModules.platform` configures the Darwin substrate and imports
  platform-local behavior, including Dock and Homebrew installation.
- `nixosModules.platform` configures the NixOS/WSL substrate and SSH server
  adapter.

`modules/system/shared/` is a system configuration package for behavior shared
by Darwin and NixOS. Platform packages depend on it one way. It is separate
from platform-local `lib/` implementation helpers. Home Manager packages do
not import Darwin or NixOS implementations.

## Flake partitions

Development-only inputs stay in the `dev` partition under `flakes/dev/`;
Darwin system inputs stay in `flakes/darwin/`; and NixOS system inputs stay in
`flakes/nixos/`. The `darwinConfigurations` and `nixosConfigurations` output
attributes are evaluated in their matching partitions. Shared Home Manager
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
