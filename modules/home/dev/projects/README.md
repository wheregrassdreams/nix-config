# Project inventory and snapshots

`project-scan` reads the host's `NIX_CONFIG_PATH_PROJECTS` path and reports Git
repositories, linked worktrees, uninitialized project candidates, and review
signals. It reads Git metadata and file timestamps only; it does not inspect
file contents or change repositories.

The scanner excludes common generated directories while discovering nested
repositories. A directory without Git metadata is reported as an
uninitialized candidate only when it contains a recognized project manifest.
Last activity is an estimate based on the newest local commit or the newest
non-ignored tracked/untracked file timestamp. It is a review signal, not a
deletion decision.

Run `just projects-scan` for the human-readable report or `project-scan
--json` for machine-readable output. Inactivity defaults to 90 days and can be
changed per invocation with `--inactive-days`. A weekly LaunchAgent records
the first inventory as a quiet baseline, then notifies only when new review
findings appear; it never removes or changes a project.

`project-snapshot` stores Git snapshots outside the projects tree in
`~/.local/share/project-snapshots` by default. On Darwin, its LaunchAgent runs
every six hours and snapshots dirty worktrees and clean branches whose push
state cannot be established. A
temporary Git index captures tracked and non-ignored untracked files without
changing the source index, branch, or worktree. Clean branches synchronized
with an upstream are skipped. Snapshot history retains 30 days.

Use `just projects-snapshot` for a manual run and `just projects-snapshots` to
list retained commits. Restore a selected local commit into a new directory
with:

```sh
project-snapshot --restore STORE COMMIT /path/to/new-restore-directory
```

Run `just projects-snapshot --check` to verify local object connectivity and,
when configured, compare each project's local timeline with its remote. The
check is read-only and does not download remote objects. Restore accepts only
commits reachable from the retained timeline, rejects symlink or non-empty
destinations, and verifies the restored HEAD and clean worktree before
reporting success.

## Optional remote snapshots

MacBook and WSL declare the `homelab-gitea-backups` target in their host
configuration. `project-snapshot` writes per-project timelines to the existing
private `homelab-backups/nix-config-snapshots` repository using a repository-
scoped deploy key. Each host declares its `gitea-backups` SSH alias and projects
the SOPS key at sops-nix's default
`~/.config/sops-nix/secrets/backup/gitea-ssh-private-key` path with mode `0400`,
independent of the nix-config checkout location. WSL runs snapshots on demand;
Darwin also has a six-hour LaunchAgent. SSH requires a matching host key in the
user's `known_hosts`.
