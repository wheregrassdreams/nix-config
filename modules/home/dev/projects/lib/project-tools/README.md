# Project tools

The package builds one `project-tools` executable with three commands:

- `scan` inventories Git repositories, worktrees, uninitialized candidates,
  and review findings without changing them.
- `audit` saves the weekly findings baseline and notifies only when new
  findings appear.
- `snapshot` stores local snapshots for dirty or unpushed worktrees, lists the
  retained project timeline, restores a selected commit into a new directory,
  and optionally provisions and updates a separate remote repository per
  project.

The scanner uses go-git where it can and the Git CLI for worktree-aware or
otherwise unsupported behavior. Git is therefore a runtime dependency. The
Go package is wired to Home Manager by `dev.projects`.

Build locally with Go 1.27 or later:

```sh
go build -o /tmp/project-tools .
/tmp/project-tools scan --root /path/to/projects --json
```

The JSON output is a versioned aggregation contract (`schemaVersion: 1`), not
a replacement for Git's machine-readable commands. Repository and worktree
fields reflect Git metadata and status. The report also includes scanner
observations: `lastCommitAt` is the newest local commit timestamp,
`lastFileActivityAt` is the newest modification time among tracked and
non-ignored untracked files, and `activityAgeDays` is the age of the newer of
those two signals relative to `scannedAt`. Activity is a review hint, not proof
that a repository is unused. Each worktree reports whether Git could inspect
its metadata. Snapshot runs skip unavailable, prunable, or uninspectable
worktrees and continue with other valid worktrees. All configured remotes are
listed with fetch and push URLs; URL credentials, query strings, and fragments
are removed. The scanner does not infer repository ownership or a worktree
destination.

Check local snapshot object connectivity and, when configured, compare each
project's local timeline with its remote:

```sh
/tmp/project-tools snapshot --snapshot-root /path/to/snapshots --check
```

The check does not download remote objects, so branch parity does not prove the
server's objects are readable. It is read-only. A nonzero exit indicates local
corruption, an unavailable remote, or a missing/mismatched timeline.

Repository discovery uses bounded `fastwalk` workers. Candidate signal scans
retain the depth and result limits of the original inventory behavior.

Remote snapshot transfer uses the Git CLI and configured SSH identity. The
`sshBare` provisioner retains its filesystem-rooted bare repository behavior.
The `gitea` provisioner creates a private repository idempotently through the
Gitea HTTPS API, verifies existing repository privacy and token push access,
then pushes over SSH. It reads the API token from an external runtime file and
does not delete repositories. Gitea repository names are deterministic sanitized
`<host-id>-<project-id>` names in the configured organization. The
`giteaPreprovisioned` provisioner instead writes all projects into one existing
private repository and needs only a repository-scoped write deploy key. It uses
a separate deterministic `refs/heads/nix-config-snapshots/<hash>` branch per
host/project pair so local snapshot stores do not share a timeline. Each project timeline
chains snapshot commits; retention compaction rewrites only that branch, using
force-with-lease for remote updates. Failed pushes leave local snapshots
available for retry. See the package README for configuration, restore syntax,
metadata, and retention behavior.

The local transport experiment used temporary repositories and credentials on
loopback only. SSH used a temporary ed25519 key and `sshd`; HTTPS used a
temporary TLS certificate, `git http-backend`, a basic-auth test endpoint, and
a temporary credential helper. Both completed push/fetch; invalid SSH and
HTTPS credentials failed without removing local refs, and a subsequent valid
credential retry succeeded. `GIT_TRACE_PACKFILE` recorded 500 bytes for the
SSH fixture and 587 bytes for the HTTPS fixture (different tiny file contents,
so these figures are not a protocol benchmark; they exclude transport
handshakes/framing). The verified local restore round-trip retained a dirty
tracked file and a non-ignored untracked file. All temporary key, token,
certificate, server, repository, and pack files were removed after the run.
