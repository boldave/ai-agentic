#!/usr/bin/env bash
# Close a worker's tmux pane, and optionally remove the git worktree it used.
#
# Refuses to remove a worktree that has uncommitted changes or commits the
# worker never pushed. The manual version is `git worktree remove --force`,
# which destroys work silently.
set -euo pipefail

NAME=""
REMOVE_WORKTREE=0
FORCE_WORKTREE=0

usage() {
  cat <<'USAGE'
Usage: retire-worker.sh --name <worker> [--remove-worktree] [--force-worktree]

  --name             the worker's name at spawn time (its @worker tag)
  --remove-worktree  also remove the git worktree the worker was started in
  --force-worktree   remove it even when it holds uncommitted or unpushed work

Killing the pane ends the claude process; its window closes with it unless
you split other panes into it. Idle notices already in flight
can still arrive afterwards; that is not an orphaned process.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="${2:-}"; shift 2 ;;
    --remove-worktree) REMOVE_WORKTREE=1; shift ;;
    --force-worktree)  FORCE_WORKTREE=1;  shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$NAME" ]] || { echo "--name is required" >&2; usage >&2; exit 2; }
[[ "$NAME" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || { echo "--name must start with a letter or digit and contain only letters, digits, _ and - — got: ${NAME}" >&2; exit 2; }
command -v tmux >/dev/null || { echo "tmux not on PATH; this skill requires tmux" >&2; exit 3; }

# Exact match on the @worker tag set at spawn: this path can delete a worktree,
# so tmux's prefix matching ("bob" hitting "bobby") is not acceptable here.
TARGET="$(tmux list-panes -a -F "#{@worker}"$'\t'"#{pane_id}" | awk -F'\t' -v n="$NAME" '$1 == n { print $2; exit }')"
[[ -n "$TARGET" ]] || {
  echo "no tmux pane tagged @worker=${NAME} — it may already be retired." >&2
  echo "Use the name the worker was spawned with, not a name it was /rename'd to." >&2
  exit 4
}

# The start directory is what spawn-worker.sh passed as --dir; unlike the pane's
# current path it does not move when the worker cd's somewhere else.
DIR="$(tmux display-message -p -t "$TARGET" '#{@worker_dir}')"
echo "matched worker ${NAME} in pane ${TARGET}, working directory: ${DIR:-unknown}"

# Closing the pane alone is not enough: the shell and claude have been seen to
# survive it, still holding the pty and still registered as a peer. So record
# the pane's shell and the job groups under it first, and signal them directly.
SHELL_PID="$(tmux display-message -p -t "$TARGET" '#{pane_pid}')"
JOB_PGIDS="$(ps -o pgid= --ppid "$SHELL_PID" 2>/dev/null | tr -d ' ' | sort -u || true)"

# The pane, not the window: a pane the user split in beside it stays.
tmux kill-pane -t "$TARGET"
echo "killed worker pane ${TARGET}"

for g in $JOB_PGIDS; do kill -TERM -- "-$g" 2>/dev/null || true; done
# An interactive shell ignores TERM; HUP is what ends it.
kill -HUP "$SHELL_PID" 2>/dev/null || true

alive() {
  kill -0 "$SHELL_PID" 2>/dev/null && return 0
  for g in $JOB_PGIDS; do kill -0 -- "-$g" 2>/dev/null && return 0; done
  return 1
}
for _ in $(seq 1 10); do alive || break; sleep 0.5; done
if alive; then
  for g in $JOB_PGIDS; do kill -KILL -- "-$g" 2>/dev/null || true; done
  kill -KILL "$SHELL_PID" 2>/dev/null || true
  echo "worker processes ignored TERM/HUP for 5s; sent KILL"
fi
sleep 0.5
if alive; then
  echo "WARNING: worker processes still running (shell ${SHELL_PID}, groups: ${JOB_PGIDS:-none})" >&2
  exit 7
fi
echo "worker processes ended"

[[ "$REMOVE_WORKTREE" -eq 1 ]] || { echo "worktree left in place: ${DIR:-unknown}"; exit 0; }

[[ -n "${DIR:-}" && -d "$DIR" ]] || { echo "no working directory recorded; nothing removed"; exit 0; }
git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "${DIR} is not a git worktree; nothing removed"; exit 0; }

# The main worktree cannot be removed by git anyway; say so instead of erroring.
if [[ "$(git -C "$DIR" rev-parse --path-format=absolute --git-dir)" == "$(git -C "$DIR" rev-parse --path-format=absolute --git-common-dir)" ]]; then
  echo "${DIR} is the repository's main worktree, not a linked one; nothing removed"
  exit 0
fi

# --ignored as well: a worker's .env or local scratch is invisible to a plain
# status and would be destroyed without ever being mentioned.
DIRTY="$(git -C "$DIR" status --porcelain --ignored)"
# Only commits reachable from THIS worktree's HEAD, not every stale local branch.
UNPUSHED="$(git -C "$DIR" log --oneline HEAD --not --remotes 2>/dev/null || true)"

if [[ -n "$DIRTY" || -n "$UNPUSHED" ]] && [[ "$FORCE_WORKTREE" -eq 0 ]]; then
  echo
  echo "NOT removing ${DIR} — it still holds work:"
  [[ -n "$DIRTY"    ]] && { echo "  uncommitted or ignored files:"; printf '%s\n' "$DIRTY" | cut -c4- | sed 's/^/    /'; }
  [[ -n "$UNPUSHED" ]] && { echo "  commits not on any remote:"; printf '%s\n' "$UNPUSHED" | sed 's/^/    /'; }
  echo
  echo "Salvage it first, or re-run with --force-worktree to discard it."
  exit 5
fi

if [[ "$FORCE_WORKTREE" -eq 1 ]]; then
  git -C "$DIR" worktree remove --force "$DIR"
else
  git -C "$DIR" worktree remove "$DIR"
fi
echo "removed worktree ${DIR}"
