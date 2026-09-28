# skills

Skille Claude Code. Każdy w osobnym katalogu z `SKILL.md` i ewentualnymi skryptami.

| Skill | Do czego |
|---|---|
| [`spawn-worker-tmux/`](spawn-worker-tmux/) | uruchamianie i wygaszanie sesji-workerów w oknach tmuxa (zamiennik `agent-crew:spawn-worker`, który wymaga cmux) |
| [`telegram-notify/`](telegram-notify/) | wysyłka powiadomień na Telegram przez bota |

## Instalacja na nowej maszynie

Claude Code czyta skille z `~/.claude/skills/`. Dowiązania zamiast kopii — wtedy
zmiany od razu są w repo:

```bash
ln -s ~/ai-agentic/skills/spawn-worker-tmux ~/.claude/skills/spawn-worker-tmux
ln -s ~/ai-agentic/skills/telegram-notify   ~/.claude/skills/telegram-notify
```

Skille są widoczne po restarcie sesji Claude Code.

## spawn-worker-tmux

Wymaga uruchomienia **wewnątrz tmuxa** — każdy worker dostaje własne okno w tle
(`new-window -d`), więc pojawia się na pasku statusu bieżącej sesji bez zabierania
fokusu. Pod `--role` idzie dowolna definicja agenta, dokładnie tak, jak nazywa ją
narzędzie Agent (np. `agent-crew:backend-developer`).

Dobrze łączy się z [`../tmux-config/`](../tmux-config/) — pasek statusu pokazuje wtedy,
który worker pracuje, a który skończył.

## telegram-notify

**Poświadczeń nie ma w repo** i nie powinno być. Skrypt czyta je z pliku poza repem:

```bash
cat > ~/.claude/telegram-notify.env <<'EOF'
TELEGRAM_BOT_TOKEN=<token-od-BotFather>
TELEGRAM_CHAT_ID=<twoj-chat-id>
EOF
chmod 600 ~/.claude/telegram-notify.env
```

Jak zdobyć jedno i drugie — opisane w [`telegram-notify/SKILL.md`](telegram-notify/SKILL.md).
Bez tego pliku skrypt kończy się błędem z czytelnym komunikatem.
