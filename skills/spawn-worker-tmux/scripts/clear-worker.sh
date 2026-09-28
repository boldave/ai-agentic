#!/usr/bin/env bash
# Clear a worker's conversation between tasks, keeping the session alive.
#
# /clear is a CLI command, not a tool, so it cannot be delivered as a message —
# it has to be typed into the pane. That is keystroke injection: Enter sent at a
# permission dialog answers the dialog. Hence the screen checks below.
set -euo pipefail

NAME=""
LABEL=""
FORCE=0

usage() {
  cat <<'USAGE'
Usage: clear-worker.sh --name <worker> [--label <task>] [--force]

  --name   the worker's name at spawn time (its @worker tag) — never changes
  --label  short name of the next task; the claude session is renamed to
           "<worker> · <task>" so workers in one role can be told apart
  --force  skip the busy/dialog checks and clear regardless

Refuses while the worker is mid-turn or showing anything other than the plain
input box.

NOTE: with --label the SendMessage address changes to "<worker> · <task>".
The @worker tag does not, so --name keeps working here.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)  NAME="${2:-}";  shift 2 ;;
    --label) LABEL="${2:-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$NAME" ]] || { echo "--name is required" >&2; usage >&2; exit 2; }
command -v tmux >/dev/null || { echo "tmux not on PATH; this skill requires tmux" >&2; exit 3; }
# Both end up typed into the pane, where a newline submits whatever precedes it.
[[ "$NAME" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || { echo "--name must start with a letter or digit and contain only letters, digits, _ and - — got: ${NAME}" >&2; exit 2; }
[[ -z "$LABEL" || "$LABEL" =~ ^[A-Za-z0-9][A-Za-z0-9\ ._:/-]*$ ]] || { echo "--label must start with a letter or digit and contain only letters, digits, spaces and . _ - : / — got: ${LABEL}" >&2; exit 2; }

# Exact match on the @worker tag set at spawn, never a prefix-matching tmux target.
TARGET="$(tmux list-panes -a -F "#{@worker}"$'\t'"#{pane_id}" | awk -F'\t' -v n="$NAME" '$1 == n { print $2; exit }')"
[[ -n "$TARGET" ]] || { echo "no tmux pane tagged @worker=${NAME}" >&2; exit 4; }
WINDOW="$(tmux display-message -p -t "$TARGET" '#{session_name}:#{window_index}')"

SCREEN="$(tmux capture-pane -p -t "$TARGET" 2>/dev/null)" || SCREEN=""

if [[ "$FORCE" -eq 0 ]]; then
  # A guard that cannot see the screen has abstained, not passed.
  if [[ -z "${SCREEN//[[:space:]]/}" ]]; then
    echo "could not read ${NAME}'s screen — not clearing. Look first: window ${WINDOW}" >&2
    exit 5
  fi
  # Spinner line, e.g. "✻ Noodling… (24s · ↓ 291 tokens)", or the interrupt hint.
  if printf '%s' "$SCREEN" | grep -qE '…[[:space:]]*\([0-9]+[smh]|esc to interrupt'; then
    echo "${NAME} is mid-turn — not clearing. Wait for its report; clearing now discards its working state." >&2
    exit 5
  fi
  # Any chooser replaces the plain input box; Enter there answers it.
  if printf '%s' "$SCREEN" | grep -qiE 'do you want|allow this|enter to confirm|❯[[:space:]]*[0-9]+\.'; then
    echo "${NAME} is showing a chooser or permission prompt — not clearing. Typing Enter would answer it." >&2
    exit 5
  fi
fi

# C-u first: leftover input would concatenate with the command and be submitted
# as an ordinary prompt. -l sends the text literally, not as key names.
tmux send-keys -t "$TARGET" C-u
tmux send-keys -t "$TARGET" -l "/clear"
tmux send-keys -t "$TARGET" Enter
sleep 3

# Keep the worker's own name even with a label: /rename changes the SendMessage
# address, and an address that is only a task id loses who is doing the work.
SESSION_NAME="$NAME"
[[ -n "$LABEL" ]] && SESSION_NAME="${NAME} · ${LABEL}"

tmux send-keys -t "$TARGET" C-u
tmux send-keys -t "$TARGET" -l "/rename ${SESSION_NAME}"
tmux send-keys -t "$TARGET" Enter
sleep 2

echo "cleared ${NAME}"

if tmux capture-pane -p -t "$TARGET" | grep -qF -- "$SESSION_NAME"; then
  echo "pane now shows session name: ${SESSION_NAME}"
else
  echo "WARNING: the pane does not show '${SESSION_NAME}' — the rename may not have" >&2
  echo "landed. Check ListAgents before dispatching to the address below." >&2
fi

echo "SendMessage address is now: ${SESSION_NAME}"
echo
echo "The role survives a clear; only the conversation goes. Send the next brief in"
echo "full — nothing told to the worker before this point still exists."
