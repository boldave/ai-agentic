#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${HOME}/.claude/telegram-notify.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Brak pliku konfiguracyjnego: $CONFIG_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || "$TELEGRAM_BOT_TOKEN" == "twoj-bot-token" ]]; then
  echo "TELEGRAM_BOT_TOKEN nie jest ustawiony w $CONFIG_FILE" >&2
  exit 1
fi

if [[ -z "${TELEGRAM_CHAT_ID:-}" || "$TELEGRAM_CHAT_ID" == "twoj-chat-id" ]]; then
  echo "TELEGRAM_CHAT_ID nie jest ustawiony w $CONFIG_FILE" >&2
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Użycie: send.sh <treść wiadomości>" >&2
  exit 1
fi

MESSAGE="$*"

response=$(curl -sS -w '\n%{http_code}' -X POST \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  --data-urlencode text="${MESSAGE}")

http_code=$(tail -n1 <<< "$response")
body=$(sed '$d' <<< "$response")

if [[ "$http_code" != "200" ]]; then
  echo "Błąd wysyłki (HTTP $http_code): $body" >&2
  exit 1
fi

echo "Wysłano."
