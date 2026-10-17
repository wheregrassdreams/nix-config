# Remote backup credential and acceptance runbook

This runbook covers the remaining operator steps for the MacBook's Gitea
project snapshots and Garage-backed Restic repository. It contains no
credentials. The exact single SOPS recipient below was compared with the
workstation age identity; keep that identity recoverable from the password
manager before storing any recovery secret here.

## Gitea project snapshots

The private `homelab-backups` organization and `snapshot-writers` team already
exist. The team has `repo.code=write`, includes all organization repositories,
and can create organization repositories; it has no Owner or administrator
role. Create one dedicated unprivileged account, `homelab-backup-bot`, and add
it to this team. Do not use `zane`'s personal token or SSH key.

1. As a Gitea administrator, create and activate `homelab-backup-bot`; do not
   grant site-admin or organization-owner rights.
2. Add the account to `homelab-backups/snapshot-writers`.
3. Sign in as the bot and create a personal access token with exactly these
   scopes: `write:organization`, `read:repository`. Gitea 1.27.1 scopes API
   routes by their URL prefix: this provisioner POSTs `/orgs/{org}/repos` and
   GETs `/repos/{owner}/{repo}` to create a private repository and verify its
   privacy/push permission. Do not select `all`. Gitea's `write:organization`
   scope covers organization API routes broadly, but the bot's organization
   team membership still limits its effective role.
4. Add the public key from `/Users/zanelu/.ssh/homelab-backups.pub` to the bot's
   SSH keys. Its local private key is already present and is dedicated to this
   use. Never copy or transmit the private half.
5. Obtain the Gitea SSH host key fingerprint from a trusted operator channel.
   Compare it with `ssh-keyscan gitea.wheregrassdreams.top` output before
   accepting it. Then connect once as the configured `gitea-backups` alias and
   accept the verified key so `StrictHostKeyChecking=ask` has a trusted entry.
6. Store the API token in OpenBao at the agreed KV path
   `homelab/apps/nix-config-backups/gitea`, then place its workstation copy as
   `gitea-backup-token` in the encrypted SOPS file described below. Configure
   Home Manager to materialize it at
   `~/.config/nix-config/secrets/gitea-backup-token` with owner-only mode. The
   snapshot tool rejects a token file readable by group or others.
7. Validate API provisioning with a disposable test project: run
   `project-snapshot --help` to confirm the installed command's flags, then
   invoke its remote snapshot path against a synthetic repository. Confirm it
   creates one private repository below `homelab-backups`, pushes the
   `snapshots` branch, and can list/check that snapshot. Remove only the test
   repository after recording the successful read-back. Do not enable the
   LaunchAgent schedule until this check and host-key trust both pass.

The scopes follow Gitea's official [token-scope reference](https://docs.gitea.com/1.27/development/oauth2-provider/#scopes)
and [organization repository API](https://docs.gitea.com/api/operations/create-org-repo/).

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

   Store these YAML string keys in the encrypted file: `gitea-backup-token`,
   `backup/s3-environment` (two shell-compatible assignments named
   `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`), and
   `backup/restic-valuable` (the Restic password). When an Atuin account is
   authorized and registered, also store its recovery key as `atuin/sync-key`.
   The SOPS creation rule uses only the password-manager-backed workstation
   age recipient. Verify
   `sops filestatus secrets/users/remote-backups.yaml` reports encrypted and
   `sops --decrypt secrets/users/remote-backups.yaml >/dev/null` succeeds; do
   not print decrypted values. Never commit a plaintext staging file.
5. The MacBook declaration already conditionally projects the three SOPS
   entries from `../../secrets/users/remote-backups.yaml` to owner-only files
   under `~/.config/nix-config/secrets/`. Those declarations become active
   only when the encrypted source exists. The valuable Restic repository and
   policy are also declared, with automatic initialization disabled. After
   creating the encrypted source, evaluate the MacBook Home Manager output and
   confirm the projected file paths and modes. Do not enable an existing
   dataset until the isolated check below succeeds.
6. On the MacBook, activate the reviewed nix-config branch and confirm all
   three projected secret files exist with owner-only permissions. Run an isolated Restic
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
