# goto-code

A Claude Code skill: when you ask Claude to show you or point you to a
place in the code ("show me X", "point me to the bug"), it opens that
location directly in your own local editor — VS Code or Neovim — instead
of pasting a code excerpt into the terminal.

Why: code pasted into a terminal chat is disconnected from the surrounding
file and the project tree, and can't be edited in place. This puts you
where you actually want to be — in your editor, at the right line, ready
to work — without switching windows to go find it yourself.

Only useful when Claude is running as a local CLI process in your own
terminal. It has no effect in a hosted/web session, since there's no local
editor for it to reach.

## Install

Clone this repo directly into Claude's personal skills directory, under
the name `goto-code`:

```bash
git clone https://github.com/oscar-barlow/goto-code ~/.claude/skills/goto-code
```

Claude Code picks up any skill under `~/.claude/skills/` automatically —
no further registration needed. To update later, `git pull` inside that
directory.

If you'd rather keep the skill scoped to a single project instead of every
session, clone it to `.claude/skills/goto-code/` inside that project's repo
instead of your home directory.

## Configuration

Everything is controlled by two environment variables, set in your shell
profile (`.bashrc`, `.zshrc`, etc.) so Claude's shell inherits them.

### `GOTO_CODE_EDITOR`

Which editor to target. One of:

- `vscode` (the default if unset) — requires no setup beyond having VS
  Code installed; it registers the `vscode://` URI handler automatically.
- `nvim` — see the Neovim section below for the one extra step it needs.

```bash
export GOTO_CODE_EDITOR=vscode
```

### `GOTO_CODE_NVIM_SOCKET`

Neovim mode only. Path to the socket your persistent Neovim instance
listens on. Defaults to `/tmp/nvimsocket` if unset.

```bash
export GOTO_CODE_NVIM_SOCKET=/tmp/nvimsocket
```

## Using Neovim mode

Neovim mode talks to an **already-running** Neovim instance rather than
opening a new window each time — so you stay in one editor pane instead of
accumulating new ones. Start that instance with a listening socket before
asking Claude to jump anywhere:

```bash
nvim --listen /tmp/nvimsocket
```

(Match the path to `GOTO_CODE_NVIM_SOCKET` if you've overridden it.) Leave
that Neovim session running in a terminal tab or pane while you work with
Claude elsewhere. If Claude tries to jump somewhere and no instance is
listening on that socket, it'll tell you rather than failing silently, and
give you the exact `nvim --listen ...` command to start one.

## How it works

- **VS Code mode** prints a clickable terminal hyperlink (an OSC 8 escape
  sequence) wrapping a `vscode://file/<path>:<line>` URI. Clicking it asks
  your OS to open VS Code at that file and line. No `code` CLI invocation
  involved.
- **Neovim mode** uses `nvim --server <socket> --remote-send` to send the
  running instance an edit command for the target file and line.

Both paths are implemented in `scripts/goto.sh`, which Claude calls rather
than reconstructing the escape sequences or remote-control syntax from
memory each time.

See `SKILL.md` for the full instructions Claude follows, including how it
handles multiple locations at once (e.g. several findings from a code
review).
