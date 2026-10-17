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
  target's SSH alias and server root, Gitea organization settings, or a
  pre-provisioned Gitea repository path.
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

Gitea is registered separately as `homelab-gitea-backups` with the
`giteaPreprovisioned` provisioner. `project-snapshot` pushes all project
timelines to the existing private `homelab-backups/nix-config-snapshots`
repository over the configured SSH alias. Each project has a separate hashed
branch under `refs/heads/nix-config-snapshots/`, hashed from host and project
IDs so same-named projects on different hosts stay separate. A repository-scoped write
deploy key covers the workload without an API token or repository-creation
scope. The `gitea` API provisioner remains available for deployments that prefer
separate repositories. The `sshBare` provisioning behavior also remains
available for filesystem-rooted bare-repository targets.

The destination repository has been provisioned, but deploy-key enrollment has
not been verified. Keep the private SSH key outside this repo at
`~/.ssh/homelab-backups`; add only its public half as a write deploy key on
`homelab-backups/nix-config-snapshots`. No account-wide SSH key or API token is
needed. Do not reuse a personal credential or commit the private key.
Before enabling scheduled snapshots, add the Gitea SSH host key to
`~/.ssh/known_hosts` only after verifying its fingerprint through a trusted
channel. The shared SSH policy uses `StrictHostKeyChecking=ask`; a first-use
prompt cannot be answered by a LaunchAgent, so the scheduled push will fail
closed until the host key is trusted.

Atuin clients are configured to sync to `https://atuin.wheregrassdreams.top`.
Register/login on each client after the Atuin server is provisioned; the user
sync key is created by Atuin and is not stored in this repository.
