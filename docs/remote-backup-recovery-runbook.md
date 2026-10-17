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

1. Confirm the repository is private. In its Gitea settings, add the public
   key from `/Users/zanelu/.ssh/homelab-backups.pub` as a deploy key with write
   access. Its local private key is dedicated to this use and must never be
   copied or transmitted.
2. Obtain the Gitea SSH host key fingerprint from a trusted operator channel.
   Compare it with `ssh-keyscan -p 30222 ssh.gitea.wheregrassdreams.top` output
   before accepting it. Then connect once as the configured `gitea-backups`
   alias and accept the verified key so `StrictHostKeyChecking=ask` has a
   trusted entry. The private endpoint and port match the Gitea SSH Service;
   the HTTPS API host does not carry SSH.
3. Validate the repository-scoped key from the MacBook using the configured
   `gitea-backups` alias. Against a synthetic Git repository, push one test
   project timeline, verify its hashed ref with `git ls-remote`, fetch it into
   an empty bare repository, and confirm the snapshot commit is readable. Test
   a second synthetic project and confirm it writes a distinct ref in the same
   repository. Do not enable the LaunchAgent schedule until both read-backs and
   host-key trust pass.

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
integration records commands entered after it is activated; do not enable it
until the account's sync behavior and data scope are accepted. `atuin import`
is a separate explicit CLI operation and must not be run for this acceptance.

The local client is currently not logged in. After an authorized account
exists, log in interactively and preserve its generated sync recovery key under
`atuin/sync-key` in the approved single-recipient SOPS file. Then run
`atuin sync` and verify a synthetic command appears on a second client or after
a clean login. Do not include real shell history in this test.
