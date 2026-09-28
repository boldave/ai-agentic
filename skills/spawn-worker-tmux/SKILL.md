---
name: spawn-worker-tmux
description: >-
  Use when coordinating parallel work across several Claude Code sessions under tmux (no cmux) —
  "spawn a worker", "give me another agent", "start two workers on this", "shut that worker down",
  "close the agent and clean up its worktree", "wipe its context before the next task", or when
  about to hand a task over SendMessage to a session that does not exist yet. Any agent definition
  the session can resolve works as a role. tmux replacement for agent-crew:spawn-worker; pairs with
  agent-crew:coordinate-workers. ONLY for a session that coordinates others — if your current task
  arrived as a message from another Claude session, you are a worker: report back instead.
allowed-tools: Bash(bash ${CLAUDE_SKILL_DIR}/scripts/spawn-worker.sh *), Bash(bash ${CLAUDE_SKILL_DIR}/scripts/retire-worker.sh *), Bash(bash ${CLAUDE_SKILL_DIR}/scripts/clear-worker.sh *)
---

# Spawn a worker (tmux)

Each worker opens as a new background window (`new-window -d`) in the tmux session the spawn
script is run from, so it shows up on that session's status bar without taking focus. The script
must run inside tmux. At spawn, four names are the same string: the window name, the pane tag
`@worker`, the `claude -n` name, and the SendMessage address. The `@worker` pane tag never changes
and is what the scripts look workers up by; window names can repeat and be renamed, so they are
not a key.

| Action | Command |
|---|---|
| Spawn | `bash ${CLAUDE_SKILL_DIR}/scripts/spawn-worker.sh --role <agent> --name <name> --dir <path>` |
| Retire | `bash ${CLAUDE_SKILL_DIR}/scripts/retire-worker.sh --name <name> [--remove-worktree]` |
| Clear between tasks | `bash ${CLAUDE_SKILL_DIR}/scripts/clear-worker.sh --name <name> [--label "<task>"]` |
| Watch one | switch to its window: prefix + its number (the spawn prints `window=<session>:<index>`) |

Each script takes `--help`.

`--role` is any agent definition, spelled exactly as the Agent tool's list spells it — plugin
roles are namespaced, e.g. `agent-crew:backend-developer`, `agent-crew:tester`. An invalid name
makes the CLI refuse and print the names it does know.

**After spawning:** confirm the name in `ListAgents` (a worker in a window may be listed without
a `tmux …` location — the name is what counts), then ask
the worker for its working directory and branch **before** assigning work. The CLI is normally up
in 1–3 s; registration trails it by a moment, so an absent name right after launch means "not yet".

## Names

`--name` accepts letters, digits, `_` and `-` only. tmux silently rewrites `.` and `:` to `_` in
names, which would split the window name from the SendMessage address — so the scripts
refuse those characters rather than let the two drift.

Scripts find a worker by exact match on its `@worker` pane tag, never through a tmux `-t <name>`
lookup: that prefix-matches, so `bob` would hit `bobby`, which is unacceptable on the path that
deletes worktrees.

## Choosing a working directory

Give each worker its own git worktree when they will build concurrently — a shared build output
means one agent's clean step deletes another's artefacts mid-run. Separate *branches* usually are
not needed: for review or verification, put everyone on the same commit and tell them not to
commit. Git refuses one branch in two worktrees, so extra reviewers sit detached; that is fine.

**The directory must already be trusted by the CLI.** An untrusted one stops the launch at "Is
this a project you trust?"; the script detects it and exits 6 instead of pressing Enter, because
answering grants read/write/execute there. Switch to its window and answer it yourself, or pick a trusted
directory. Your home directory is never persisted as trusted, and a fresh worktree path is new to
the CLI even when its repository is trusted.

## Retiring

Kills the worker's pane (its window closes with it, unless you split other panes into it), then
signals the pane's shell and its job groups directly — TERM, HUP for the shell, KILL after 5 s —
because closing the pane alone was seen to leave the shell and claude running and still listed
as a peer. Exits 7 if anything survives. `--remove-worktree` removes the directory the worker was
*started* in (the `@worker_dir` pane tag recorded at spawn, not wherever it cd'd to). It refuses when that
worktree holds uncommitted or ignored files, or commits not on any remote, and lists them; it will
not touch the repository's main worktree. `--force-worktree` overrides — only after you have looked.

Queued idle notices can still arrive after a retire; that is not an orphaned process.

## Clearing between tasks

`/clear` is a CLI command, not a tool, so it must be typed into the pane — keystroke injection.
The script reads the pane first and exits 5 while the worker is mid-turn or showing any chooser,
because **Enter typed at a dialog answers the dialog**. `--force` skips the checks.

**The role survives; the conversation does not.** Send the next brief in full afterwards.

`--label` renames the claude session to `<name> · <task>` so workers in one role are distinguishable.
**That changes the SendMessage address** — the script prints the new one. The `@worker` tag and the
window name stay `<name>`, so `--name` keeps working for later clears and the retire.

## Gotchas

- **Typing a command is not submitting it.** Scripts send text with `send-keys -l` (literal, so a
  word like `Enter` inside it stays text) and then `Enter` as a separate key.
- **`/rename` typed by hand changes the address too**, and messages to the old name stop arriving.
  Keep the worker's identity in any new name.
- **`--permission-mode auto` is required** (otherwise the worker stalls on prompts nobody answers),
  but it nudges the worker toward shell edits (`sed`, `python`) over `Edit`/`Write`. Counter it with
  a line in the role body, not by listing `Edit`/`Write` in `tools`.
- **A role's `tools` only grants what the harness offers**; naming a disabled tool is a silent
  no-op. Have a new worker *use* a tool you are unsure of rather than describe its toolset.
- **`Bash` in `tools` is unrestricted shell** — `Bash(git log:*)` there grants the whole tool — and
  `Skill` is a second write path. A role with either is not read-only.
- **A launch flag beats a hook**: a skill denied by `--disallowed-tools` stays denied even when a
  hook tells the session to load it.

## Keeping workers from spawning workers

By default the spawn script denies this skill plus `agent-crew:spawn-worker` and
`agent-crew:coordinate-workers` via `--disallowed-tools 'Skill(...)'`; `--guard` takes a different
comma-separated list. A worker that coordinates peers makes its reports untraceable. A role whose
`tools` omits `Agent` cannot fan out through subagents either — check the definition before
spawning rather than assuming. Do not drop `Skill` or use `--disable-slash-commands`: workers need
the rest of the catalogue.
