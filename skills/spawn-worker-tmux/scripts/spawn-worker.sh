#!/usr/bin/env bash
# Spawn a Claude Code worker in a new background window of the current tmux session.
#
# The worker name, the tmux window name, the claude -n name and the SendMessage
# address all start out identical. The worker's pane is tagged with the pane
# option @worker=<name>; that tag never changes afterwards and is the lookup key
# for the other scripts (window names can repeat and be renamed, so they are not). The script cannot confirm the worker
# registered as a peer — that is ListAgents, a tool the coordinator holds.
set -euo pipefail

ROLE=""
NAME=""
DIR=""
WAIT=15
GUARD="spawn-worker-tmux,agent-crew:spawn-worker,agent-crew:coordinate-workers"

usage() {
  cat <<'USAGE'
Usage: spawn-worker.sh --role <agent> --name <name> --dir <path> [--wait <seconds>] [--guard <skills>]

  --role   agent definition to run the session as, spelled exactly as the Agent
           tool lists it, e.g. agent-crew:backend-developer
  --name   worker name: tmux window name, @worker tag AND SendMessage address.
           Letters, digits, _ and - only (tmux rewrites . and : to _).
  --dir    working directory, normally a dedicated git worktree
  --wait   timeout in seconds for the CLI to come up (default 15); the script
           returns as soon as the prompt appears
  --guard  comma-separated skills the worker must not load
           (default: the coordination skills); pass "" to disable

Must run inside tmux: the window is opened in the session of the calling pane.
Prints the worker's tmux pane and window on success.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role)  ROLE="${2:-}";  shift 2 ;;
    --name)  NAME="${2:-}";  shift 2 ;;
    --dir)   DIR="${2:-}";   shift 2 ;;
    --wait)  WAIT="${2:-}";  shift 2 ;;
    --guard) GUARD="${2-}";  shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$ROLE" && -n "$NAME" && -n "$DIR" ]] || { echo "--role, --name and --dir are required" >&2; usage >&2; exit 2; }
[[ -d "$DIR" ]] || { echo "no such directory: $DIR" >&2; exit 2; }

# The launch line is TYPED INTO A LIVE SHELL, so anything interpolated into it
# is executable. No spaces and an alphanumeric first character keep a name from
# smuggling in flags or a starting prompt.
ROLE_TOKEN='^[A-Za-z0-9][A-Za-z0-9._:-]*$'
# Stricter for names: tmux silently turns . and : into _ in names,
# which would split the window name from the SendMessage address.
NAME_TOKEN='^[A-Za-z0-9][A-Za-z0-9_-]*$'
[[ "$ROLE" =~ $ROLE_TOKEN ]] || { echo "--role must start with a letter or digit and contain only letters, digits and . _ - : — got: ${ROLE}" >&2; exit 2; }
[[ "$NAME" =~ $NAME_TOKEN ]] || { echo "--name must start with a letter or digit and contain only letters, digits, _ and - — got: ${NAME}" >&2; exit 2; }
# WAIT reaches $(( ... )), where bash evaluates command substitution.
[[ "$WAIT" =~ ^[0-9]+$ ]] || { echo "--wait must be a whole number of seconds — got: ${WAIT}" >&2; exit 2; }
command -v tmux >/dev/null || { echo "tmux not on PATH; this skill requires tmux" >&2; exit 3; }
[[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]] || { echo "not inside tmux — run this from a tmux pane; the worker opens as a window in that session" >&2; exit 3; }

# Exact match on the tag, never a tmux target lookup: "-t bob" prefix-matches "bobby".
EXISTING="$(tmux list-panes -a -F "#{@worker}"$'\t'"#{pane_id}" | awk -F'\t' -v n="$NAME" '$1 == n { print $2 }')"
if [[ -n "$EXISTING" ]]; then
  echo "a worker named '${NAME}' already exists (pane ${EXISTING}) — pick another name or retire it first" >&2
  exit 4
fi

SESSION="$(tmux display-message -p -t "$TMUX_PANE" '#{session_id}')"
# -d: open in the background so the user's current window keeps focus.
TARGET="$(tmux new-window -d -P -F '#{pane_id}' -t "${SESSION}:" -n "$NAME" -c "$DIR")"
tmux set-option -p -t "$TARGET" @worker "$NAME"
# The start directory, for retire --remove-worktree; the pane's current path
# moves whenever the worker cd's.
tmux set-option -p -t "$TARGET" @worker_dir "$DIR"
# Keep the window name fixed so the user can find the worker on the status bar.
tmux set-option -w -t "$TARGET" automatic-rename off >/dev/null 2>&1 || true
tmux set-option -w -t "$TARGET" allow-rename off >/dev/null 2>&1 || true
WINDOW="$(tmux display-message -p -t "$TARGET" '#{session_name}:#{window_index}')"

LAUNCH="claude --agent '${ROLE}' -n '${NAME}' --permission-mode auto"
if [[ -n "$GUARD" ]]; then
  IFS=',' read -ra GUARDED <<< "$GUARD"
  for g in "${GUARDED[@]}"; do
    g="$(printf '%s' "$g" | tr -d '[:space:]')"
    [[ -n "$g" ]] || continue
    [[ "$g" =~ $ROLE_TOKEN ]] || { echo "--guard entry is not a plain skill name: ${g}" >&2; exit 2; }
    LAUNCH="${LAUNCH} --disallowed-tools 'Skill(${g})'"
  done
fi

# -l sends the text literally, so words like "Enter" or "C-c" inside it are not
# read as key names. Enter goes separately, as a key.
tmux send-keys -t "$TARGET" -l "$LAUNCH"
tmux send-keys -t "$TARGET" Enter

READY=0
TRUST=0
TICKS=0
MAX_TICKS=$(( WAIT * 2 ))
while (( TICKS < MAX_TICKS )); do
  SCREEN="$(tmux capture-pane -p -t "$TARGET" 2>&1 || true)"
  if printf '%s' "$SCREEN" | grep -qiE 'is this a project you|trust this folder'; then
    TRUST=1; break
  fi
  # The mode line only renders once the CLI is up and taking input.
  if printf '%s' "$SCREEN" | grep -qiE 'auto mode on|shift\+tab to cycle'; then
    READY=1; break
  fi
  sleep 0.5
  TICKS=$(( TICKS + 1 ))
done
ELAPSED="$(( TICKS / 2 )).$(( (TICKS % 2) * 5 ))"

if [[ "$TRUST" -eq 1 ]]; then
  echo "tmux_pane=${TARGET} window=${WINDOW}" >&2
  echo >&2
  echo "${NAME} is waiting on a trust-this-folder prompt and has NOT started." >&2
  echo "${DIR} is new to the CLI. Answering grants read, write and execute there," >&2
  echo "so answer it yourself in window ${WINDOW}. This script will not" >&2
  echo "press Enter on a permission decision for you." >&2
  exit 6
fi

printf 'tmux_pane=%s\nwindow=%s\nname=%s\nrole=%s\ndir=%s\nready_after=%ss\n' \
  "$TARGET" "$WINDOW" "$NAME" "$ROLE" "$DIR" "$ELAPSED"

if [[ "$READY" -eq 0 ]]; then
  echo >&2
  echo "NOTE: no prompt within ${WAIT}s. It may still be starting, or the launch" >&2
  echo "failed. Look: tmux capture-pane -p -t '${TARGET}'" >&2
fi

echo
echo "Now verify with ListAgents that '${NAME}' is present (location tmux ...${TARGET}),"
echo "then ask it for its working directory and branch before assigning work."
