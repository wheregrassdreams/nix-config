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
choose operations or policy. The staging Reprise integration owns Git snapshot
creation, provisioning, and retention. `storage.backup` owns Restic datasets,
schedules, retention, checks, and restore behavior. Each product owns the paths
and recovery semantics for its data.

Keep this shared surface limited to operations with multiple real consumers.
Do not add a universal transfer command or job schema that hides each
product's different consistency and recovery semantics.

Atuin clients are configured to sync to `https://atuin.wheregrassdreams.top`.
Register/login on each client after the Atuin server is provisioned; the user
sync key is created by Atuin and is not stored in this repository.
