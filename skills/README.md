# skills

Claude Code skills. Each one in its own directory with a `SKILL.md` and any scripts.

| Skill | What it is for |
|---|---|
| [`spawn-worker-tmux/`](spawn-worker-tmux/) | starting and retiring worker sessions in tmux windows (a replacement for `agent-crew:spawn-worker`, which needs cmux) |
| [`telegram-notify/`](telegram-notify/) | sending notifications to Telegram through a bot |

## Installing on a new machine

Claude Code reads skills from `~/.claude/skills/`. Symlinks rather than copies —
that way edits land in the repo straight away:

```bash
ln -s ~/ai-agentic/skills/spawn-worker-tmux ~/.claude/skills/spawn-worker-tmux
ln -s ~/ai-agentic/skills/telegram-notify   ~/.claude/skills/telegram-notify
```

The skills show up after restarting the Claude Code session.

## spawn-worker-tmux

Has to be run **inside tmux** — every worker gets its own background window
(`new-window -d`), so it appears on the current session's status bar without
taking focus. `--role` takes any agent definition, spelled exactly as the Agent
tool spells it (e.g. `agent-crew:backend-developer`).

It pairs well with [`../tmux-config/`](../tmux-config/) — the status bar then shows
which worker is busy and which one has finished.

## telegram-notify

**The credentials are not in the repo** and should not be. The script reads them
from a file outside it:

```bash
cat > ~/.claude/telegram-notify.env <<'EOF'
TELEGRAM_BOT_TOKEN=<token-from-BotFather>
TELEGRAM_CHAT_ID=<your-chat-id>
EOF
chmod 600 ~/.claude/telegram-notify.env
```

How to obtain both is described in [`telegram-notify/SKILL.md`](telegram-notify/SKILL.md).
Without that file the script exits with a clear error message.
