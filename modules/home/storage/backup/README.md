# Data backups

This package runs Restic over datasets registered by their owning capability.
Importing `storage.backup` adds the interface and commands; it does not start a
job until a dataset, policy, and repository are all declared.

The optional dataset class chooses one policy. Defaults are `valuable`, daily
at 02:00 local time, keeping 7 daily, 8 weekly, and 6 monthly snapshots.
`critical` runs daily and keeps 14 daily, 8 weekly, and 12 monthly snapshots.
`rebuildable` runs weekly and keeps 4 weekly and 2 monthly snapshots. A
repository is private to the configured Restic password and target path.

On macOS, a calendar run missed during sleep is coalesced and runs after wake;
a run missed while powered off is not replayed. On systemd hosts,
`Persistent = true` causes a missed calendar run to start when the user timer
becomes active again.

Example S3 setup:

```nix
my.storage.remote.targets.archive = {
  backend.s3 = {
    endpoint = "https://s3.example.net";
    bucket = "backups";
    prefix = "nix-config";
  };
};

my.storage.backup.repositories.valuable = {
  target = "archive";
  initIfMissing = true;
  passwordFile = config.sops.secrets."backup/restic-valuable".path;
  environmentFile = config.sops.secrets."backup/s3-environment".path;
};
my.storage.backup.policies.valuable.repository = "valuable";
my.storage.backup.datasets.tmux-resurrect.paths = [
  "${config.my.paths.xdg.data}/tmux/resurrect"
];
```

## Homelab S3 readiness

The `homelab-s3` target is currently endpoint metadata only. The MacBook has a
valuable-class Restic repository and policy declared, but its
`tmux-resurrect` and `codex-sessions` datasets remain disabled. The credential
source is not present, so no secret is currently materialized and no schedule
is generated. Do not enable a dataset until the Garage endpoint and bucket
have been verified with a Restic client.

The repository needs two separately provisioned secret files through the
existing Home Manager SOPS interface:

- `config.sops.secrets."backup/restic-valuable".path`: generated Restic
  repository password;
- `config.sops.secrets."backup/s3-environment".path`: `AWS_ACCESS_KEY_ID` and
  `AWS_SECRET_ACCESS_KEY` for a restricted S3 key with access to the selected
  bucket/prefix.

Neither secret is present in the current SOPS source. The MacBook declares the
secret projections conditionally: they become active only when
`secrets/users/remote-backups.yaml` exists. Add that file only after values
have been provisioned and encrypted; do not substitute sample values or a
plaintext source. The repository uses those fixed owner-only runtime paths and
does not initialize a missing repository automatically. Perform an isolated
initialize, backup, list, and restore check before enabling a scheduled dataset.

The standalone Home Manager output imports the pinned sops-nix Home Manager
module. On macOS that module uses a LaunchAgent to materialize declared secrets
at login and when Home Manager activates. This repository sets
`sops.defaultSopsFile` to the encrypted `secrets/common.yaml`; a secret with a
narrower recipient set should override `sopsFile` to its host-specific file.
The machine must have the age key at `~/.config/sops/age/keys.txt` or an
available unencrypted SSH key configured in `sops.age.sshKeyPaths`. SOPS
materializes the secret under its user runtime mount and exposes the configured
`.path` through a home-directory symlink; it does not put plaintext in the Nix
store. Verify the actual launchd projection and Restic invocation on the Mac
before enabling the dataset.

Use a single-line encrypted value for the Restic password secret. The S3
environment secret should decrypt to shell-compatible assignments for
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`; the Restic wrapper sources that
file only for the command. Keep the S3 key restricted to the backup bucket and
prefix. Do not store either value in Nix expressions, environment attributes,
or a plaintext file tracked by Git.

The default repository path is target prefix + host ID + repository ID. Set
`repositoryPath` only to replace the backend-relative suffix. S3 credentials
come from `environmentFile`; Restic's encryption password comes from
`passwordFile`. These are direct paths, usually from `config.sops.secrets`.

For WebDAV, Restic uses rclone. The SOPS-backed `rcloneConfigFile` must define
a remote whose section name matches the target ID and whose URL matches the
registered `backend.webdav.endpoint`. The target's `root` is appended before
the default host/repository suffix.

`initIfMissing` defaults to `false`. When enabled, a scheduled backup
checks the repository first and runs `restic init` only when Restic reports
that the repository is absent (exit code 10). Authentication, network, and
other failures stop the job and trigger its failure notification instead of
initializing. The check is repeated after a failed `init` to tolerate another
run initializing the repository concurrently. Use `backup-init REPOSITORY`
for explicit one-time initialization when automatic initialization is off.

`backup-check REPOSITORY` runs Restic's repository integrity check, while
`backup-snapshots REPOSITORY` lists snapshots for the current host.
`backup-status [CLASS]` shows the latest run result, including its start/end
time and exit code. Background jobs write logs and notify only on failure;
successful runs stay quiet.

`backup-restore REPOSITORY [SNAPSHOT] [--target PATH]` restores into a unique
directory under `~/.local/share/backup-restore/` by default. A custom target
must be absent or empty, so an accidental restore cannot mix with existing
files. Review the staged result before copying it into an application's live
data directory.

The capability that owns state should register its concrete paths in
`my.storage.backup.datasets`. Set `enable = false` to keep a dataset documented
without including it in a scheduled policy yet. Dataset registration does not
change path ownership or application settings; it only makes those paths
eligible for the chosen backup policy. Schedules are generated only when an
enabled dataset, its class policy, and that policy's repository are all
configured.
