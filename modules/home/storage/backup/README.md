# Data backups

This package runs Restic over datasets registered by their owning capability.
Importing `storage.backup` adds the interface and commands; it does not start a
job until a dataset, policy, and repository are all declared.

The optional dataset class chooses one policy. Defaults are `valuable`, daily
at 02:00 local time, keeping 7 daily, 8 weekly, and 6 monthly snapshots.
`critical` runs daily and keeps 14 daily, 8 weekly, and 12 monthly snapshots.
`rebuildable` runs weekly and keeps 4 weekly and 2 monthly snapshots. A
repository is private to the configured Restic password and target path.

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

`backup-check REPOSITORY` runs Restic's repository integrity check. It does
not restore data. `backup-restore REPOSITORY [SNAPSHOT] [--target PATH]`
restores into a unique directory under `~/.local/share/backup-restore/` by
default; supplying `--target` selects another explicit destination. Background
jobs log output and notify only on failure. Successful runs stay quiet.

The capability that owns state should register its concrete paths in
`my.storage.backup.datasets`. Dataset registration does not change path ownership or
application settings; it only makes those paths eligible for the chosen
backup policy.
