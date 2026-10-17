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

On 2026-10-17, the current source completed a two-project synthetic
push/list/check/restore round trip. Both remote refs matched, both restored
payloads were byte-identical, and the synthetic refs were removed. Gitea
confirmed the `nix-config-project-snapshots` deploy key, and a real push proved
its write access to this repository. This pre-provisioned design needs no
organization/team membership or API token: authorization is limited to this
repository's deploy key.

The MacBook Home Manager generation now includes the SOPS-projected key and
managed SSH alias. A synthetic project passed push, list, remote consistency
check, and remote restore through that command and alias; tracked and untracked
payload hashes matched, then the synthetic ref was deleted. The loaded
`org.nix-config.projects-snapshot` LaunchAgent has a six-hour interval. Its
first timer-fired run has not yet been observed. WSL runtime validation is out
of scope per the operator's instruction.

The private key is recoverable from the single-recipient SOPS entry
`backup/gitea-ssh-private-key`; local decryption succeeded and the derived
public key matched `~/.ssh/homelab-backups.pub`. Home Manager declares an
owner-only `0400` projection at
`~/.config/nix-config/secrets/backup-gitea-ssh-key` for both MacBook and WSL.
The SSH alias `gitea-backups` pins `ssh.gitea.wheregrassdreams.top:30222` and
sets `StrictHostKeyChecking yes`. The currently trusted ED25519 fingerprint
is `SHA256:lm73ciwBKxXsLoh9sdOtb9xcsEsWkOtB0G/RiEaiggs`; on a replacement
client, obtain the pinned entry from a trusted existing `known_hosts` copy or
verify this fingerprint independently before adding it. Do not trust a fresh
`ssh-keyscan` result by itself.

Atuin clients are configured to sync to `https://atuin.wheregrassdreams.top`.
Register/login on each client after the Atuin server is provisioned; the user
sync key is created by Atuin and is not stored in this repository.
