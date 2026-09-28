---
name: telegram-notify
description: >-
  Use when the user asks to be notified on Telegram — "wyślij mi na Telegrama",
  "powiadom mnie na Telegramie", "napisz mi jak skończysz" with Telegram implied,
  or any request to send a message to the user's phone via Telegram bot.
allowed-tools: Bash(bash ${CLAUDE_SKILL_DIR}/scripts/send.sh *)
---

# Telegram Notify

Sends a text message to the user's Telegram via a bot, using credentials from
`~/.claude/telegram-notify.env`.

| Action | Command |
|---|---|
| Send message | `bash ${CLAUDE_SKILL_DIR}/scripts/send.sh "message text"` |

Full setup walkthrough, including the Telegram side and troubleshooting:
[README.md](README.md).

## One-time setup (user does this, not Claude)

1. Message `@BotFather` on Telegram → `/newbot` → get the bot token.
2. Send any message to the new bot (so it can message back).
3. Get your `chat_id`:
   - open `https://api.telegram.org/bot<TOKEN>/getUpdates` in a browser after
     step 2, and read `message.chat.id` from the JSON, or
   - message `@userinfobot` to get your numeric user id (same as chat_id for a
     private chat).
4. Fill in `~/.claude/telegram-notify.env`:
   ```
   TELEGRAM_BOT_TOKEN=<token>
   TELEGRAM_CHAT_ID=<chat_id>
   ```

## Notes

- The script exits non-zero with a clear message if the config file is
  missing or still has placeholder values.
- `send.sh` takes the message as its remaining arguments (no quoting pitfalls
  needed beyond normal shell quoting of the whole message).
- The Polish phrases in the description above are deliberate: they are the
  trigger examples that make the skill fire when the user writes in Polish.
