#!/usr/bin/env bash
# Jump to a file:line in the user's configured editor.
# Usage: goto.sh <path> <line> [description] [--list-only]
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: goto.sh <path> <line> [description] [--list-only]" >&2
  exit 1
fi

PATH_ARG="$1"
LINE="$2"
DESC="${3:-}"
LIST_ONLY="${4:-}"

ABS_PATH=$(realpath "$PATH_ARG")
LABEL="${PATH_ARG}:${LINE}"
EDITOR_MODE="${GOTO_CODE_EDITOR:-vscode}"

case "$EDITOR_MODE" in
  vscode)
    URI="vscode://file/${ABS_PATH}:${LINE}:1"
    if [ -n "$DESC" ]; then
      printf '\e]8;;%s\e\\%s\e]8;;\e\\  — %s\n' "$URI" "$LABEL" "$DESC"
    else
      printf '\e]8;;%s\e\\%s\e]8;;\e\\\n' "$URI" "$LABEL"
    fi
    ;;

  nvim|neovim)
    SOCKET="${GOTO_CODE_NVIM_SOCKET:-/tmp/nvimsocket}"

    if [ "$LIST_ONLY" = "--list-only" ]; then
      if [ -n "$DESC" ]; then
        echo "  ${LABEL}  — ${DESC}"
      else
        echo "  ${LABEL}"
      fi
      exit 0
    fi

    if nvim --server "$SOCKET" --remote-expr '1' >/dev/null 2>&1; then
      nvim --server "$SOCKET" --remote-send "<C-\\><C-n>:edit +${LINE} ${ABS_PATH}<CR>"
      if [ -n "$DESC" ]; then
        echo "-> jumped to ${LABEL} in your running Neovim  — ${DESC}"
      else
        echo "-> jumped to ${LABEL} in your running Neovim"
      fi
    else
      echo "No running Neovim server found at ${SOCKET}."
      echo "Start one with: nvim --listen ${SOCKET}"
      echo "Then open manually: nvim +${LINE} ${ABS_PATH}"
    fi
    ;;

  *)
    echo "Unknown GOTO_CODE_EDITOR=${EDITOR_MODE} (expected 'vscode' or 'nvim')" >&2
    exit 1
    ;;
esac
