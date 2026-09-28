# tmux-config

A tmux configuration whose status bar shows the state of Claude Code agents:
an animation while an agent works, a question mark when it waits for an answer,
a green highlight when it is done — separately for every window and every session.

## Contents

| File | What it is for |
|---|---|
| `tmux.conf` | the whole configuration: status bar (3 lines), mouse support, context menus |
| `bin/tmux-agent-state` | sets the agent state flags; called from Claude Code hooks |
| `bin/tmux-spinner` | one frame of the animation; tmux has no source of time in its formats |

## Requirements

- tmux 3.2+ (it uses `status-format[N]`, `display-menu`, `#{S:...}`)
- `jq` — `tmux-agent-state` uses it to read the notification text from the hook
- [TPM](https://github.com/tmux-plugins/tpm) in `~/.tmux/plugins/tpm` (last line of `tmux.conf`)
- a truecolor terminal (Sonokai palette)

## Installing on a new machine

```bash
git clone https://github.com/boldave/ai-agentic.git ~/ai-agentic
ln -s ~/ai-agentic/tmux-config/tmux.conf ~/.tmux.conf

# TPM, if it is not there yet
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Then, inside tmux, `prefix + I` (install plugins) and `prefix + r`, or restart the server.

### If you clone somewhere other than `~/ai-agentic`

There is **one line** to change, at the top of `tmux.conf`:

```tmux
set -g @agent_bin "~/ai-agentic/tmux-config/bin"
```

The tilde works — tmux runs these commands through `/bin/sh`.

## Wiring it to Claude Code

The scripts do nothing until Claude Code calls them. In `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "~/ai-agentic/tmux-config/bin/tmux-agent-state busy", "timeout": 5 }] }
    ],
    "PostToolUse": [
      { "hooks": [{ "type": "command", "command": "~/ai-agentic/tmux-config/bin/tmux-agent-state busy", "timeout": 5, "async": true }] }
    ],
    "Notification": [
      { "hooks": [{ "type": "command", "command": "~/ai-agentic/tmux-config/bin/tmux-agent-state wait", "timeout": 5 }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "~/ai-agentic/tmux-config/bin/tmux-agent-state done", "timeout": 5 }] }
    ]
  }
}
```

## How it works

`tmux-agent-state` sets flags in tmux options — separately for the window
(`@agent_busy_w`, `@agent_wait_w`, `@agent_done_w`) and for the session (`..._s`).
The separate names are not cosmetic: session options are inherited by that
session's windows, so a shared name would light the marker up on every window of
a marked session.

The status bar reads those flags and draws the matching state. Order of
precedence: question (orange) > finished (green) > working (animation).

The `wait` and `done` flags clear themselves when you enter the window — to answer
the agent you have to go there anyway, so entering is a trustworthy "I can see it
now" signal.

The script marks the pane from `$TMUX_PANE`, that is the one the agent runs in —
not the one you happen to be looking at.

## Note

A copy of this configuration also lives in the private `~/dotfiles` repo (there
`tmux.conf` points its paths at `~/dotfiles/bin`, and its comments are in Polish).
Changes have to be made in both places, or you eventually have to decide which one
is the source of truth.
