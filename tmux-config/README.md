# tmux-config

Konfiguracja tmuxa z paskiem statusu pokazującym stan agentów Claude Code:
animacja gdy agent pracuje, pytajnik gdy czeka na odpowiedź, zielone podświetlenie
gdy skończył — osobno dla każdego okna i każdej sesji.

## Zawartość

| Plik | Do czego |
|---|---|
| `tmux.conf` | cała konfiguracja: pasek statusu (3 linie), obsługa myszy, menu kontekstowe |
| `bin/tmux-agent-state` | ustawia flagi stanu agenta; wołany z hooków Claude Code |
| `bin/tmux-spinner` | jedna klatka animacji; tmux nie ma w formatach źródła czasu |

## Wymagania

- tmux 3.2+ (używane są `status-format[N]`, `display-menu`, `#{S:...}`)
- `jq` — `tmux-agent-state` czyta nim treść powiadomienia z hooka
- [TPM](https://github.com/tmux-plugins/tpm) w `~/.tmux/plugins/tpm` (ostatnia linia `tmux.conf`)
- terminal z truecolor (paleta Sonokai)

## Instalacja na nowej maszynie

```bash
git clone https://github.com/boldave/ai-agentic.git ~/ai-agentic
ln -s ~/ai-agentic/tmux-config/tmux.conf ~/.tmux.conf

# TPM, jeśli jeszcze nie ma
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Potem w tmuksie `prefix + I` (instalacja wtyczek) i `prefix + r` albo restart serwera.

### Jeśli klonujesz gdzie indziej niż `~/ai-agentic`

Do zmiany jest **jedna linia** na górze `tmux.conf`:

```tmux
set -g @agent_bin "~/ai-agentic/tmux-config/bin"
```

Tylda działa — tmux uruchamia te komendy przez `/bin/sh`.

## Podpięcie do Claude Code

Same skrypty nic nie robią, dopóki nie zawoła ich Claude Code. W `~/.claude/settings.json`:

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

## Jak to działa

`tmux-agent-state` ustawia flagi w opcjach tmuxa — osobno dla okna (`@agent_busy_w`,
`@agent_wait_w`, `@agent_done_w`) i dla sesji (`..._s`). Osobne nazwy nie są kosmetyką:
opcje sesji dziedziczą się do jej okien, więc wspólna nazwa zapaliłaby znacznik przy
każdym oknie oznaczonej sesji.

Pasek statusu czyta te flagi i rysuje odpowiedni stan. Kolejność ważności:
pytanie (pomarańczowy) > ukończenie (zielony) > aktywność (animacja).

Flagi `wait` i `done` gasną same przy wejściu w okno — żeby odpowiedzieć agentowi
i tak musisz tam wejść, więc samo wejście jest wiarygodnym sygnałem „już widzę".

Skrypt oznacza panel z `$TMUX_PANE`, czyli ten, w którym działa agent — a nie ten,
na który akurat patrzysz.

## Uwaga

Kopia tej konfiguracji żyje też w prywatnym repo `~/dotfiles` (tam `tmux.conf` ma
ścieżki wskazujące na `~/dotfiles/bin`). Przy zmianach trzeba pamiętać o obu miejscach
albo w końcu zdecydować, które jest źródłem prawdy.
