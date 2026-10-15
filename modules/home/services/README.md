# Local services

`my.services` is a lifecycle boundary for services running on the current
machine. It supports MySQL, PostgreSQL, and Redis with three modes:

- `external`: process lifecycle is managed elsewhere, for example Docker.
- `local-manual`: install the Nix-managed server and client tools without
  starting a daemon.
- `local-daemon`: declare the platform daemon.

The module may install client tools, but it does not own database data,
exports, backups, or restoration. Treat every local daemon as an independent
data system with a tested export and restore procedure.
