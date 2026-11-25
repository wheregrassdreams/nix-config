# fork-pane

Open a forked agent session in a neighbouring Rex or tmux pane.

Both agents already fork; this package only decides where the fork runs.

- Codex: `codex fork <thread-id> [prompt]` creates a new thread from the
  current one.
- dsh-tui: `/fork` creates a resumable copy and prints the command that enters
  it (`DSH_TUI_RESUME_SESSION=<id> dsh --profile dsh-tui`).

## Usage

From a Codex shell escape:

```text
!fork-pane
!fork-pane -- "why would that cache miss?"
```

With the `$fork` hook installed, type it as a prompt instead:

```text
$fork why would that cache miss?
```

The hook runs before the prompt reaches the model, forks into a pane beside
the current one, and blocks the original prompt.

For dsh-tui, run `/fork`, then pass the id it prints:

```sh
fork-pane --harness dsh --session <fork-id>
```

Options:

```text
--target rex|tmux        force a backend (default: detect)
--tab                    open a tab/window instead of a split
--bg                     keep focus in the current pane
--left|--right|--up|--down
--block BLOCK            split beside this Rex block
--dry-run                print the plan as JSON
```

## Install the Codex hook

```sh
fork-pane install-hook codex
```

This merges one `UserPromptSubmit` entry into `~/.codex/hooks.json` and leaves
the other hooks alone. Restart Codex, open `/hooks` once, and trust the new
hook. Remove it with `fork-pane uninstall-hook codex`.

## How the pane is found

- Rex: uses `REX_BLOCK` when it still names a live block. If it does not (the
  Codex app-server daemon keeps the environment from the first pane that
  started it), it looks for a block whose foreground process is `codex` and
  whose working directory matches the agent's, newest process first.
- tmux: uses `TMUX_PANE` when it is live, otherwise the pane whose current
  command and directory match.
- When several candidates match, pass `--block` (Rex) or run from the target
  pane.

## Limits

- dsh-tui has no headless fork. `/fork` is the only way to create the copy;
  this command only opens it in a pane.
- Codex records no link from a TUI process to its thread, so the fork must
  start from inside the agent (the hook or `!`). A tmux keybinding cannot find
  a plain `codex` pane's thread id.
- The daemon fallback is a heuristic: running Codex with `--no-daemon` keeps
  `REX_BLOCK` accurate.
