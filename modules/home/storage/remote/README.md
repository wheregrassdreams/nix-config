# Remote targets

`my.storage.remote.targets` is a shared directory of typed endpoint descriptions. It
does not define backup, snapshot, or synchronization jobs and it performs no
network operations.

Consumers explicitly import `lib/targets.nix` for the small shared adapter
surface:

- find a target by ID;
- retrieve a declared backend safely;
- check the number of selected backends and reject parent-directory segments;
- join backend-relative path components consistently.

`lib/clients.nix` makes the supported clients explicit and gives consumers a
backend-aware client configuration:

- `git` provides the Git and OpenSSH runtime dependencies and the selected
  target's SSH alias and server root, or the Gitea organization settings for
  its API provisioner.
- `restic` provides the Restic repository location, password/credential
  environment, and runtime dependencies. It uses Restic's native S3 backend
  or adds rclone for a WebDAV target.

The client interface wires up executables and connection details; it does not
choose operations or policy. `dev.projects` owns Git snapshot creation,
provisioning, and retention. `storage.backup` owns Restic datasets, schedules,
retention, checks, and restore behavior. Each product owns the paths and
recovery semantics for its data.

Keep this shared surface limited to operations with multiple real consumers.
Do not add a universal transfer command or job schema that hides each
product's different consistency and recovery semantics.

## Homelab endpoints

The MacBook and WSL host declarations register `homelab-s3` at
`http://192.168.3.250:8333`, the currently declared SeaweedFS endpoint. The
endpoint is intended to remain stable through the documented SeaweedFS-to-Garage
cutover. S3 compatibility and client access from these hosts have not yet been
end-to-end verified. Store S3 credentials in external secret files and pass
those files to backup consumers; never put credentials in endpoint declarations
or Git. The bucket contract is `home-backups` with the `nix-config/` prefix.

Gitea is registered separately as `homelab-gitea-backups` with the `gitea`
provisioner. `project-snapshot` creates one private repository per host/project
under the configured organization, named from the sanitized `<host-id>-<project-id>`
pair with a stable hash suffix. The suffix prevents punctuation normalization
or length limits from merging different IDs into one repository. Provisioning
uses the Gitea HTTPS API and checks that an existing
repository remains private and the token has push permission. Git data is pushed
over the configured SSH alias; it never uses arbitrary remote shell commands.
The existing `sshBare` provisioning behavior remains available for filesystem-
rooted bare-repository targets.

The planned Git destination is the private Gitea organization
`homelab-backups`; organization, account, team, and token provisioning have not
been verified. An organization owner should create that organization and a
dedicated automation account (for example, `homelab-backup-bot`) with a private
team such as `snapshot-writers`. Give that team organization-level `write`
access to all repositories and enable `can_create_org_repo`; the
project-snapshot client creates private repositories through Gitea's
organization-repository API. This is intentionally broader than
repository-only grants, but does not grant Owner or server-administrator
access. The API token must authorize organization repository creation and
repository permission reads; verify those operations with the deployed Gitea
version before the first snapshot.

Use a dedicated SSH key for Git pushes and a separate API token file for repo
creation and permission checks. The private SSH key stays outside this repo at
`~/.ssh/homelab-backups`; its public half must be added to the bot account.
Keep both private key and API token in the operator's approved secret store,
materialize the files with owner-only permissions, and do not reuse a personal
credential or commit either secret. The configured API token path is a runtime
file path, not a SOPS declaration; create the file through the approved secret
provisioning process before running `project-snapshot`.
Before enabling scheduled snapshots, add the Gitea SSH host key to
`~/.ssh/known_hosts` only after verifying its fingerprint through a trusted
channel. The shared SSH policy uses `StrictHostKeyChecking=ask`; a first-use
prompt cannot be answered by a LaunchAgent, so the scheduled push will fail
closed until the host key is trusted.

Atuin clients are configured to sync to `https://atuin.wheregrassdreams.top`.
Register/login on each client after the Atuin server is provisioned; the user
sync key is created by Atuin and is not stored in this repository.
