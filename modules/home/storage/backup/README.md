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
