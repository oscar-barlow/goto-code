---
name: goto-code
description: Open specific code locations directly in the user's local editor (VS Code or Neovim, configurable) instead of pasting code excerpts into chat. Use this whenever the user asks to be shown, pointed to, or taken to a specific place in the code ("show me X", "point me to X", "where is X", "take me to the bug") — especially when the answer is one or more concrete file:line locations. Also use it any time you are about to reference multiple locations at once (several call sites of a symbol, several findings from a code review, several places touched by a refactor) so the user can work through them at their own pace instead of reading pasted snippets they won't actually look at. Does not apply to short one-line diffs you are already showing inline as part of an edit, or to purely conceptual/architectural discussion with no single line to point at.
---

# goto-code

## Why this exists

Pasting code into a terminal chat produces text the user reports they don't
actually read — it's disconnected from the surrounding file, there's no
project tree, and it can't be edited in place. What the user actually wants
is to land in their own editor, at the right line, with full context and the
ability to start typing immediately.

This only applies when you (Claude) are running as a local CLI process in
the user's own terminal — it has no effect in a hosted/web session, since
there's no local OS, editor, or terminal to hand a link or command to.

## Use the bundled script — don't hand-roll the escape codes

`scripts/goto.sh` handles both editors. Always call it via the Bash tool
rather than reconstructing the OSC 8 hyperlink escape sequence or the
Neovim remote-control incantation from memory — both are the kind of thing
that's easy to get subtly wrong (a stray slash, a missing terminator), and
getting it wrong either does nothing or, worse, prints garbled escape codes
into the chat.

```bash
scripts/goto.sh <path> <line> [description] [--list-only]
```

- `<path>` — can be relative to the repo; the script resolves it to an
  absolute path itself (both editors need absolute paths internally).
- `<line>` — required. Column isn't exposed; it isn't worth the complexity
  unless you already have a precise one from a linter/type-checker.
- `[description]` — optional, one short clause on what's at that location.
  Keep it to a single clause — it's there to help triage a list, not to
  substitute for opening the file.
- `--list-only` — Neovim mode only, see below.

## Which editor it targets

Controlled by the `GOTO_CODE_EDITOR` environment variable in the user's
shell: `vscode` (the default if unset) or `nvim`. This is a per-user,
per-machine setting — it lives in their shell profile, not in this skill —
so don't try to guess or override it; just call the script and let it read
the variable.

### VS Code mode (`GOTO_CODE_EDITOR=vscode` or unset)

The script prints one clickable line using VS Code's `vscode://file/` URI
scheme wrapped in an OSC 8 terminal hyperlink. Clicking it asks the OS to
open VS Code at that file and line — no `code` CLI invocation involved, and
nothing to have installed beyond VS Code itself (it registers the URI
scheme automatically).

The visible label is always the human-readable `path:line`, not the raw
URI — that's deliberate. In a terminal that doesn't support OSC 8 the
escape codes are simply invisible and the label still reads as useful plain
text, rather than either a wall of garbage or a bare unclickable URI.

### Neovim mode (`GOTO_CODE_EDITOR=nvim`)

This assumes the user keeps one **persistent** Neovim instance running,
started with a listening socket:

```bash
nvim --listen /tmp/nvimsocket
```

(the path is configurable via `GOTO_CODE_NVIM_SOCKET`, defaulting to
`/tmp/nvimsocket`). The script talks to that already-running instance over
the socket and tells it to jump — it does **not** spawn a new terminal
window or a new Neovim process. That's the point: the user stays in one
editor pane instead of accumulating new windows every time you point at
something. If they haven't started an instance this way, the script
detects that cleanly and tells them how to, rather than failing silently.

For a single location, just call the script — it jumps immediately and
prints a one-line confirmation.

## Multiple locations

If "show me X" resolves to several candidates, or the task naturally
produces a list (several call sites, several review findings, several files
touched by a refactor), don't guess a single winner — surface all of them,
in a stable and meaningful order (file order, or severity order for review
findings):

- **VS Code mode**: call the script once per location, with no
  `--list-only` flag — every line becomes its own independently clickable
  hyperlink, so the user picks what to open and in what order.
- **Neovim mode**: there's only one instance to jump, so pick the single
  most relevant location (top of a severity-ordered list, or the first
  call site encountered) and call the script on it *without*
  `--list-only` so it jumps there now. Call the script on every other
  location *with* `--list-only`, which just prints `path:line —
  description` as plain reference text, and mention the user can ask you
  to jump to any of the others next.

## What not to do

- Don't paste the actual code excerpt in chat alongside the link "just in
  case" — that defeats the point. A short one-clause description is fine;
  a reproduced code block is not.
- Don't shell out to `code --goto` — that's a different mechanism (CLI
  invocation, requires `code` on PATH) and isn't what this skill uses even
  in VS Code mode.
- In Neovim mode, don't open a new Neovim process or a new terminal window
  as a substitute for the remote-control approach — that's exactly the
  back-and-forth window-switching this skill exists to avoid.
