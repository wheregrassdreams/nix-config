# Remote backup credential and acceptance runbook

This runbook covers the remaining operator steps for the MacBook's Gitea
project snapshots and Garage-backed Restic repository. It contains no
credentials. The exact single SOPS recipient below was compared with the
workstation age identity; keep that identity recoverable from the password
manager before storing any recovery secret here.

## Gitea project snapshots

The private `homelab-backups/nix-config-snapshots` repository already exists.
The current client writes separate deterministic project refs in that one
repository, so a repository-scoped deploy key avoids an API token and any
organization-wide repository creation permission.

The dedicated `/Users/zanelu/.ssh/homelab-backups.pub` key is enrolled as the
`nix-config-project-snapshots` deploy key on this repository. The single
SOPS-recipient source at `secrets/users/remote-backups.yaml` decrypts locally;
the recovered private key's public half matched that enrolled public key. The
credential is repository-scoped, so this flow does not require organization or
team membership, an account-wide key, or an API token.

On 2026-10-17, the current repository source completed a fresh MacBook synthetic
round trip: two dirty project repositories were snapshotted and pushed to
distinct deterministic refs, `--list` reported both as synced, `--check`
matched both remote refs, remote restore returned both payloads byte-for-byte,
and the synthetic refs were deleted afterward. A direct strict-host-key SSH
authentication and remote read/write check also succeeded. At the end, the
remote contained only its `main` branch.

That initial source-level E2E used an isolated temporary SSH alias, the existing
`~/.ssh/homelab-backups` key, and the real `~/.ssh/known_hosts`; it preceded
Home Manager activation and did not verify scheduled delivery.

The SOPS source stores the Gitea key as a nested YAML value at
`backup.gitea-ssh-private-key`; sops-nix declarations use the matching path
`backup/gitea-ssh-private-key`. The ciphertext was re-encrypted to correct the
previous flat-key shape, preserving the decrypted key value and the same sole
age recipient. Restic and S3 secret projections are not declared until those
credentials are provisioned, so the deferred Garage work does not block this
Gitea key projection.

The MacBook `just build-home` succeeds. This build used
`NIX_CONFIG='sandbox = false'` because the existing Go test suite starts a local
TLS test server and the Nix sandbox denied its localhost bind; `go test ./...`
passes outside the sandbox. Home Manager was activated from a clean worktree so
the unrelated dirty Zed settings edit was excluded. The key projection resolves
to mode `0400`, its public-key fingerprint matches the enrolled deploy key, and
`ssh -G gitea-backups` reports `StrictHostKeyChecking yes`. A strict-host-key
`git ls-remote` succeeded against the private repository.

After activation, a synthetic temporary project was pushed through the managed
`project-snapshot` command and Gitea deploy key. `--list` reported the remote
ref synced; `--check` matched the remote ref; `--restore-remote` restored both
tracked and untracked payloads with matching SHA-256 hashes. The synthetic ref
was deleted afterward, and the repository returned to its original `main`
HEAD. The `org.nix-config.projects-snapshot` LaunchAgent is loaded with a six
hour interval (`StartInterval = 21600`); it had not run on its own at the time
of verification, so the first timer-fired run remains unobserved. WSL runtime
validation is out of scope per the operator's instruction.

The SSH alias declares `ssh.gitea.wheregrassdreams.top:30222` with strict host
key checking. The current trusted ED25519 pin is
`SHA256:lm73ciwBKxXsLoh9sdOtb9xcsEsWkOtB0G/RiEaiggs`. Recover the private key by
decrypting the SOPS entry `backup/gitea-ssh-private-key` only into a protected
runtime file; the Home Manager declaration projects it with mode `0400` to
`~/.config/nix-config/secrets/backup-gitea-ssh-key` on MacBook and WSL. For a
replacement machine, restore the existing known-host entry from a trusted
client or independently verify the pin above before adding it. Do not trust a
fresh `ssh-keyscan` result alone. Never print the decrypted key or commit it.

## Garage S3 and Restic

Do not create backup credentials until Garage is healthy, its backing pool is
healthy, and it has enough free space for the source data, a complete new
repository, and rollback headroom. The earlier check found a degraded backup
pool, so that gate is currently closed. Preserve SeaweedFS data and rollback
until a complete Garage restore has been verified.

After the storage operator confirms the gate is open:

1. In Garage, confirm cluster status and the `home-backups` bucket. If the
   bucket does not exist, create it. Create a dedicated key named
   `nix-config-restic`; grant it only `--read --write` access to `home-backups`
   (do not grant bucket ownership or bucket creation). Garage permissions are
   bucket-scoped, not prefix-scoped, so this key can access the entire bucket;
   use a dedicated bucket instead if that access is too broad for the other
   bucket contents. Garage displays the secret access key only at creation.

   ```sh
   garage status
   garage bucket info home-backups
   garage key create nix-config-restic
   garage bucket allow home-backups --key nix-config-restic --read --write
   garage bucket info home-backups
   ```
2. Immediately place the access key ID and secret access key in OpenBao at
   `homelab/apps/nix-config-backups/s3`, for example using its approved UI or
   secure input workflow. Confirm the KV mount and write policy first. Do not
   put values in shell arguments, terminal logs, Git, or chat. OpenBao's ESO
   projection is for Kubernetes consumers; it does not materialize files on
   this macOS client. If a cluster workload also needs this key, create a
   narrowly scoped ExternalSecret from that OpenBao path after the value is
   stored. Keep a recoverable, SOPS-encrypted workstation copy for Restic.
3. Generate a separate high-entropy Restic repository password. Store it in
   the SOPS file as a recovery key; do not rotate it independently of the
   repository. Do not create an ESO projection for the password unless a
   Kubernetes Restic client is separately approved and needs it.
4. Create the dedicated SOPS file with restrictive umask, encrypt it before
   committing, then edit only through SOPS:

   ```sh
   cd /Users/zanelu/Workspace/code/projects/nix-config
   umask 077
   printf '{}\n' > secrets/users/remote-backups.yaml
   sops --encrypt --in-place secrets/users/remote-backups.yaml
   sops secrets/users/remote-backups.yaml
   ```

   Store these YAML string keys in the encrypted file: `backup/s3-environment`
   (two shell-compatible assignments named
   `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`), and
   `backup/restic-valuable` (the Restic password). When an Atuin account is
   authorized and registered, also store its recovery key as `atuin/sync-key`.
   The SOPS creation rule uses only the password-manager-backed workstation
   age recipient. Verify
   `sops filestatus secrets/users/remote-backups.yaml` reports encrypted and
   `sops --decrypt secrets/users/remote-backups.yaml >/dev/null` succeeds; do
   not print decrypted values. Never commit a plaintext staging file.
5. The MacBook declaration already conditionally projects the SOPS entries
   from `../../secrets/users/remote-backups.yaml` to owner-only files
   under `~/.config/nix-config/secrets/`. Those declarations become active
   only when the encrypted source exists. The valuable Restic repository and
   policy are also declared, with automatic initialization disabled. After
   creating the encrypted source, evaluate the MacBook Home Manager output and
   confirm the projected file paths and modes. Do not enable an existing
   dataset until the isolated check below succeeds.
6. On the MacBook, activate the reviewed nix-config branch and confirm both
   projected secret files exist with owner-only permissions. Run an isolated Restic
   test under a unique temporary repository path and a synthetic file: init,
   back up, list snapshots, restore to an empty staging directory, and compare
   the restored file hash. Remove only that test repository after verification.
   Then back up a real selected dataset, list it from the remote, restore it
   into staging, and compare representative file hashes before enabling its
   schedule.

Garage's [official CLI guide](https://garagehq.deuxfleurs.fr/documentation/quick-start/#creating-buckets-and-keys)
documents bucket creation, key creation, and bucket-level `read`/`write`
grants. The [Garage recovery guide](https://garagehq.deuxfleurs.fr/documentation/operations/recovering-from-failures/)
and local storage health evidence remain prerequisites for migration.

## Atuin client verification

The managed client declares `auto_sync = true` and only
`https://atuin.wheregrassdreams.top` as its sync address. There is no
`atuin import` command or shell-history import hook in this repository, so
activation does not bulk-import existing shell history. The Atuin shell
integration records commands entered after it is activated; `atuin import` is
a separate explicit CLI operation and was not run for acceptance.

On 2026-10-17 the Atuin service was Ready (1/1), its ESO credential was
synced, and an isolated disposable account completed encrypted sync of a
synthetic command between two clients. The managed MacBook Home Manager output
evaluates to the endpoint above with `auto_sync = true`. A strict HTTPS request
to `/healthz` returned 200; `/health` is not a supported health path and
returns 404. The disposable test does not contain real shell history. The
regular local client remains logged out, and its existing Atuin database was
not used for the test. Registration is currently closed. No recovery key
for the disposable account was retained; if a permanent account is later
authorized, preserve its generated recovery key under `atuin/sync-key` in the
approved single-recipient SOPS file before relying on it.
