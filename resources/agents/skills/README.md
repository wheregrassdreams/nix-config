# Shared agent skills

This directory is the versioned source for skills managed by this repository.
Put locally authored skills here directly. Each skill is a child directory
containing `SKILL.md`.

Use `just agent-skills-find <query>` to discover skills and
`just agent-skills-add <source> <skill> [name]` to fetch one with the `skills`
CLI. The fetched files are copied into this directory and committed with their
source record in `sources.json`. The checked-in files are the installed
version; adding a skill does not make Home Manager fetch from the network.
Run these commands inside `nix develop` to get the required Node.js and Python
runtimes on either supported host.

Use `just agent-skills-update <name>` to explicitly fetch the recorded source
again. Review the resulting skill and manifest diff before committing. Skills
are executable instructions, so inspect third-party content before adding or
updating it.

Home Manager links each child directory containing `SKILL.md` into
`~/.agents/skills/`. It manages only names present here; other skills already
in that directory remain user-owned.
