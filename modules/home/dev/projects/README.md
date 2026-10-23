# Reprise integration

The MacBook Home Manager configuration installs Reprise from its standalone
flake through `flakes/staging/reprise`. The `dev.projects` package resolves the
selected storage target and passes the resulting Git destination to that
temporary integration. It owns the local daemon plus scheduled inventory and
snapshot jobs. Snapshot storage is outside the projects tree; the configured
Gitea remote is a separate recovery destination. Reevaluate the staging
boundary when Reprise's API stabilizes.
