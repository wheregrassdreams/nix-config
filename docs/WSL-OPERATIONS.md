# WSL operations

This document contains maintenance procedures that are intentionally kept out
of the normal bootstrap path.

## Publishing a bootstrap release

The public install commands in the README use an immutable `bootstrap-v1` tag.
Before publishing those commands, create and push the tag, then protect it in
GitHub. Never move or reuse a published bootstrap tag; publish `bootstrap-v2`
for an incompatible launcher change.

```zsh
git tag -a bootstrap-v1 -m "NixOS WSL bootstrap v1"
git push origin bootstrap-v1
```

If this repository becomes private, move the launcher to a separate public
repository and update the README URL before changing visibility. A private
repository cannot supply an unauthenticated raw bootstrap download.

## Bootstrap options

The bootstrap is safe to re-run once `~/nix-config` is a Git flake checkout: it
rebuilds from that checkout without replacing it.

- `--private` uses temporary GitHub CLI HTTPS authentication for the initial
  clone, then configures the permanent checkout for SSH after switch.
- `--repair` restores `zane:users` ownership of the checkout and resets the
  `zane` password.
- `--source /absolute/path` uses a locally prepared Git checkout for a first
  installation instead of cloning it.
- `--no-github-ssh` leaves `origin` on HTTPS temporarily. It only skips the
  post-switch key setup; the private `git+ssh` flake inputs still need
  credentials before evaluation (see below). `--skip-github-ssh` remains as
  a deprecated alias.

Private keys and GitHub CLI credentials remain outside the repository.

## Private flake inputs

Four inputs are fetched over SSH because their repositories are private:

- `tmux-statusbar`, `tmux-flash-rs`, and `tmux-prompt-cursor` in `flake.nix`;
- `reprise` in `integrations/staging/reprise`.

They are resolved during evaluation, so a machine without GitHub credentials
cannot build the configuration at all. `--no-github-ssh` does not change that:
it only controls the post-switch `origin` setup.

Verify credentials before the first build:

```bash
ssh -T git@github.com
git ls-remote git@github.com:wheregrassdreams/tmux-statusbar.git HEAD
```

With HTTPS-only credentials, configure `gh auth setup-git` and set
`url."git@github.com:".insteadOf` if the SSH URL still fails. Making these
inputs optional is not attempted here: the tmux capability consumes them
unconditionally.

## Mainland China mirrors

`cache.nixos.org` is unreliable from mainland China. The NixOS module exposes an
optional mirror of the same cache:

```nix
my.nix.cacheMirror = "ustc"; # or "tuna"
```

`hosts/wsl` enables `ustc`, which mirrors `cache.nixos.org` and signs with the
same key, so `trusted-public-keys` needs no change. Remove the setting on a host
with good upstream connectivity.

Two further sources stay slow and need manual treatment:

- `flake.nix` adds `cache.numtide.com` through `nixConfig.extra-substituters`.
  If it hangs (0 bytes for minutes), remove that line locally; it is not
  required by the lock file.
- `nix-index-database` ships its index as a fixed-output GitHub release
  (about 97 MB) and ignores substitutes. Download it through an accelerator such
  as `ghfast.top`, then pre-seed it with `nix-store --add-fixed sha256 <file>`.

## Stable WSL identity and Codex

The primary WSL account has UID `1000`. DrvFS stores numeric Linux ownership
metadata, so a rename must retain UID `1000`.

The bootstrap performs the rename for a fresh installation: when UID `1000`
belongs to another account (the stock image uses `nixos`), it rewrites
`/etc/passwd`, `/etc/shadow`, and `/etc/group`, keeps UID `1000`, and moves the
home directory to `/home/zane`. `usermod -l` is not usable here because the
account is in use by the running session. Reopen WSL after the switch so the
session picks up the new home directory.

For a system that already switched with another UID `1000` account:

1. Declare the new user with UID `1000` and make it the WSL default user.
2. Switch the system before removing the old account.
3. Shut down WSL, reopen it, and confirm the new identity with `id`.
4. Re-enable the Codex WSL backend only after the new default user is active.

A real UID change requires explicitly migrating only the affected Windows-side
state. For Codex:

```bash
sudo chown -R --no-dereference NEW_USER:users /mnt/c/Users/<WindowsUser>/.codex
```

Do not recursively change ownership of a whole Windows profile or drive.

The WSL tarball builder is available at:

```text
.#nixosConfigurations.wsl.config.system.build.tarballBuilder
```
