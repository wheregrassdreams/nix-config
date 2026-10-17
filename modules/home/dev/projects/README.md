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
`~/.local/share/project-snapshots` by default. Every six hours it snapshots
dirty worktrees and clean branches whose push state cannot be established. A
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

Remote endpoints are registered under `my.storage.remote.targets`. A Git target
uses an SSH alias from the host's SSH configuration. The `sshBare` provisioner
also requires an absolute server directory and creates a bare repository per
host and project on the first snapshot:

```nix
my.storage.remote.targets.project-snapshots = {
  backend.git = {
    sshHost = "snapshot-store";
    root = "/srv/git/project-snapshots";
  };
  provisioner.kind = "sshBare";
};

my.dev.projects.snapshots.remote.target = "project-snapshots";
```

The host's `programs.ssh.matchBlocks.snapshot-store` supplies the actual
hostname, user, and identity. The remote repository path is
`<root>/<host-id>/<project-id>.git`. Project IDs derive from the normalized
local repository path; `projectIdOverrides` can preserve an ID after a move.
The project source's `origin` is never used as a snapshot destination.

For Gitea, `gitea` creates and verifies one private repository per host/project
through the HTTPS API. `giteaPreprovisioned` instead pushes to one existing
private repository through a repository-scoped write deploy key, separating
project timelines into deterministic hashed refs:

```nix
my.storage.remote.targets.project-snapshots = {
  backend.git.sshHost = "gitea-backups";
  provisioner = {
    kind = "giteaPreprovisioned";
    gitea = {
      repository = "project-backups/nix-config-snapshots";
    };
  };
};

my.dev.projects.snapshots.remote.target = "project-snapshots";
```

The repository must already exist and be private. Add the dedicated public SSH
key as a write deploy key to that repository. No Gitea API token or site-admin
capability is needed in this mode. The SSH alias must name the Git server and
select the matching dedicated private key; add
the server host key to `known_hosts` only after verifying its fingerprint
through a trusted channel. For the current homelab target, deploy-key enrollment
and server host-key verification are still outstanding. Do not treat the declared endpoint as an
accepted backup until a real snapshot and isolated restore have succeeded.

Each API-provisioned project repository has one `refs/heads/snapshots` timeline.
The shared pre-provisioned repository stores each project at
`refs/heads/nix-config-snapshots/<stable-hash>` derived from both host and
project IDs. Every commit
stores the snapshot time, project ID, worktree ID, source branch, source HEAD,
and snapshot reason in Git commit trailers. Commits chain only to earlier
snapshots, not to the source repository's history. Tracked and non-ignored
untracked files are included; ignored files are excluded.

When entries expire, the local timeline is compacted to retained commits and
the remote branch is updated using force-with-lease. Local Git garbage
collection uses a two-week grace window for newly unreachable objects. Remote
branch history follows the 30-day window; when the server physically removes
unreachable objects depends on its own Git garbage-collection schedule. Failed
remote operations leave local snapshots available for retry.

Snapshots created by the previous per-worktree-ref format are kept in place,
listed as `legacy-local`, and remain restorable by their old ref. They are not
rewritten or pruned by the new timeline policy.

Use `project-snapshot --list` to browse the timeline, then restore a selected
commit hash (or the branch tip):

```sh
project-snapshot --restore STORE <commit> /path/to/new-restore-directory
project-snapshot --restore-remote <commit> /path/to/new-restore-directory --project-id <project-id>
```

`project-snapshot --check` verifies local Git connectivity and compares the
remote snapshots branch with the local branch tip. It does not download remote
objects, encrypt Git objects at rest, or run restore drills. The private Git
service's access controls and disk encryption protect stored snapshots; SSH
protects transfer. File and state datasets use the separate `storage.backup`
package.
