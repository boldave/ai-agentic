# telegram-notify

A Claude Code skill that sends a message to your phone over Telegram — useful when
an agent finishes a long task and you are not watching the terminal.

```
Claude Code  →  scripts/send.sh  →  Telegram Bot API  →  your phone
```

The skill holds no credentials. They live in `~/.claude/telegram-notify.env`,
outside the repo.

---

## 1. The Telegram side

You need two values: a **bot token** and a **chat id**. Both are obtained inside
the Telegram app, in about two minutes.

### 1.1 Create the bot

1. In Telegram, search for **@BotFather** (the one with the blue checkmark) and open it.
2. Send `/newbot`.
3. It asks for a **display name** — anything, e.g. `Claude Code notifier`.
4. It asks for a **username** — must be unique across Telegram and must end in
   `bot`, e.g. `dawid_claude_notify_bot`.
5. BotFather replies with a token that looks like this:

   ```
   8123456789:AAH1a2B3c4D5e6F7g8H9i0JkLmNoPqRsTuV
   ```

   That is `TELEGRAM_BOT_TOKEN`. Treat it like a password — anyone holding it can
   send messages as your bot.

### 1.2 Start a chat with the bot

**This step is not optional.** A Telegram bot cannot write to someone who has not
written to it first. Open your new bot (BotFather gives you a `t.me/...` link) and
press **Start**, or just send it any message.

Skip this and every send fails with `400 Bad Request: chat not found`, even though
the token is perfectly valid.

### 1.3 Find your chat id

Easiest way — message **@userinfobot** in Telegram. It replies with your numeric
id, e.g. `123456789`. For a private chat, your user id *is* the chat id.

Alternative, straight from the API — after step 1.2, open this in a browser,
substituting your token:

```
https://api.telegram.org/bot<TOKEN>/getUpdates
```

In the JSON, find `result[0].message.chat.id`. If `result` is empty, you have not
actually sent the bot a message yet — go back to step 1.2.

That number is `TELEGRAM_CHAT_ID`.

> **Sending to a group instead of yourself:** add the bot to the group, send a
> message there, and read the id the same way. Group ids are **negative**
> (e.g. `-1001234567890`) — keep the minus sign.

---

## 2. The machine side

### 2.1 The config file

```bash
cat > ~/.claude/telegram-notify.env <<'EOF'
TELEGRAM_BOT_TOKEN=8123456789:AAH1a2B3c4D5e6F7g8H9i0JkLmNoPqRsTuV
TELEGRAM_CHAT_ID=123456789
EOF
chmod 600 ~/.claude/telegram-notify.env
```

No quotes around the values, no spaces around the `=`. The file is sourced by
bash, so quotes would become part of the value.

`chmod 600` matters: the token is a credential, and this file is the only place
it is written down.

### 2.2 Install the skill

Claude Code reads skills from `~/.claude/skills/`:

```bash
ln -s ~/ai-agentic/skills/telegram-notify ~/.claude/skills/telegram-notify
```

Restart the Claude Code session for it to be picked up.

### 2.3 Check that it works

```bash
bash ~/ai-agentic/skills/telegram-notify/scripts/send.sh "test"
```

Expected: `Sent.` and the message on your phone.

---

## 3. Using it

Ask for it in plain language — "wyślij mi na Telegrama, jak skończysz", "notify me
on Telegram". The skill's trigger phrases are deliberately Polish as well as
English, so both work.

Directly:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/send.sh "message text"
```

### Notifying on every finished turn

To get a message every time an agent stops, without asking each time, add a `Stop`
hook in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/skills/telegram-notify/scripts/send.sh \"Agent finished.\"",
            "timeout": 15,
            "async": true
          }
        ]
      }
    ]
  }
}
```

`async: true` keeps a slow network from holding the session up; `|| true` is worth
appending if you would rather a failed send never surfaced as an error.

---

## 4. When it does not work

| Message | What it means |
|---|---|
| `Config file missing: ...` | `~/.claude/telegram-notify.env` does not exist — section 2.1 |
| `TELEGRAM_BOT_TOKEN is not set in ...` | the file exists but the value is empty or still a placeholder |
| `Send failed (HTTP 401): ... Unauthorized` | wrong or revoked token — check for a truncated copy-paste |
| `Send failed (HTTP 400): ... chat not found` | wrong chat id, or you never pressed **Start** on the bot (section 1.2) |
| `Send failed (HTTP 403): ... bot was blocked by the user` | you blocked the bot in Telegram; unblock it |
| nothing arrives, no error | the message went to a different chat id — verify it via `getUpdates` |

### Rotating the token

If the token leaks: message **@BotFather** → `/revoke` → pick the bot. The old
token dies immediately and you get a new one. Put it in the config file and you
are done — nothing else references it.
