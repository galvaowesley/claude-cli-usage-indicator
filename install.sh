#!/usr/bin/env bash
# Installs claude-usage-indicator as your Claude Code status line.
# Safe to re-run: it only ever touches the "statusLine" key in
# ~/.claude/settings.json, and never overwrites an existing statusline.conf.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SCRIPT_DEST="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
CONFIG_CMD_DEST="$CLAUDE_DIR/statusline-config"

echo "claude-usage-indicator installer"
echo "---------------------------------"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required but not found in PATH." >&2
  echo "  macOS:  brew install jq" >&2
  echo "  Linux:  sudo apt install jq   (or) sudo dnf install jq   (or) sudo pacman -S jq" >&2
  exit 1
fi

mkdir -p "$CLAUDE_DIR"
cp "$REPO_DIR/statusline.sh" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"
echo "-> installed $SCRIPT_DEST"

cp "$REPO_DIR/statusline-config" "$CONFIG_CMD_DEST"
chmod +x "$CONFIG_CMD_DEST"
echo "-> installed $CONFIG_CMD_DEST (indicators/reset-time settings, any time)"

if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

TMP=$(mktemp)
jq --arg cmd "$SCRIPT_DEST" \
  '.statusLine = ((.statusLine // {}) + {"type":"command","command":$cmd,"padding":0})' \
  "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
echo "-> wired up statusLine in $SETTINGS"

# Trigger one render so statusline.conf gets auto-created, then let the
# user pick a few display options right here instead of having to edit
# the config file (or settings.json) by hand afterwards.
CONFIG="$CLAUDE_DIR/statusline.conf"
[ -f "$CONFIG" ] || echo '{}' | "$SCRIPT_DEST" >/dev/null 2>&1 || true

# configure_indicators and configure_reset (plus the set_conf/set_indicators
# helpers they share) live in statusline-config so this installer and that
# standalone command run the exact same prompts instead of two copies
# drifting apart. Sourcing only defines the functions - see the guard at
# the bottom of that file.
# shellcheck source=statusline-config
. "$REPO_DIR/statusline-config"

BRANCH_ICON_EMOJI="🌿"
BRANCH_ICON_NERD=$(printf '\xef\x84\xa6')   # U+F126, Nerd Font "code-branch"

if [ -f "$CONFIG" ] && [ -t 0 ]; then
  configure_indicators

  echo
  echo "Which icon should the git branch indicator use?"
  echo "  1) ${BRANCH_ICON_EMOJI} emoji, default. Works in any terminal, no setup needed."
  echo "  2) ${BRANCH_ICON_NERD} code-branch icon. Sharper, but needs a Nerd Font set as"
  echo "     your terminal's font (see the README for how to set one up)."
  read -rp "Choose 1 or 2 [1]: " icon_choice
  case "$icon_choice" in
    2) chosen_icon="$BRANCH_ICON_NERD" ;;
    *) chosen_icon="$BRANCH_ICON_EMOJI" ;;
  esac
  set_conf branch_icon "$chosen_icon"
  echo "-> set branch_icon in $CONFIG"

  configure_reset

  echo
  echo "How often should indicators auto-refresh on their own, on top of"
  echo "Claude Code's normal update events (new message, session start, ...)?"
  echo "This is what makes reset countdowns and usage percentages feel live"
  echo "while you're idle, instead of only updating when you send a message."
  echo "  1) Off, default.          Only updates on Claude Code's own events."
  echo "  2) Every 5s, recommended. Feels live, no noticeable overhead."
  echo "  3) Every 10s.             Live, lighter touch."
  echo "  4) Custom (1-60s)."
  read -rp "Choose 1-4 [1]: " refresh_choice
  case "$refresh_choice" in
    2) refresh_interval=5 ;;
    3) refresh_interval=10 ;;
    4)
      read -rp "Seconds between refreshes (1-60): " refresh_interval
      case "$refresh_interval" in
        ''|*[!0-9]*) refresh_interval=5 ;;
      esac
      [ "$refresh_interval" -lt 1 ] && refresh_interval=1
      [ "$refresh_interval" -gt 60 ] && refresh_interval=60
      ;;
    *) refresh_interval=0 ;;
  esac
  if [ "$refresh_interval" -gt 0 ] && [ "$refresh_interval" -lt 3 ] && grep -qE '^(cpu|ram)$' "$CONFIG"; then
    echo "note: the cpu/ram indicators shell out to top/vm_stat on every"
    echo "      render, so refreshing faster than every 3s may add noticeable"
    echo "      overhead. Consider dropping cpu/ram from $CONFIG instead."
  fi
  TMP=$(mktemp)
  if [ "$refresh_interval" -gt 0 ]; then
    jq --argjson n "$refresh_interval" '.statusLine.refreshInterval = $n' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
    echo "-> set statusLine refreshInterval to ${refresh_interval}s in $SETTINGS"
  else
    jq 'del(.statusLine.refreshInterval)' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
  fi

  echo
  echo "'statusline-config' reopens the indicator and reset-time questions any"
  echo "time, without rerunning this whole installer."
  cmd_ready=0
  if [ -d "$HOME/.local/bin" ]; then
    case ":${PATH}:" in
      *":$HOME/.local/bin:"*)
        read -rp "Link it into ~/.local/bin so you can just type 'statusline-config'? [Y/n]: " link_choice
        case "$link_choice" in
          [Nn]*) ;;
          *)
            if ln -sf "$CONFIG_CMD_DEST" "$HOME/.local/bin/statusline-config"; then
              echo "-> linked ~/.local/bin/statusline-config"
              cmd_ready=1
            fi
            ;;
        esac
        ;;
    esac
  fi
  if [ "$cmd_ready" -eq 0 ]; then
    echo "   Use it as: !$CONFIG_CMD_DEST"
    echo "   Or add this to your shell rc to shorten it to 'statusline-config':"
    echo "     alias statusline-config='$CONFIG_CMD_DEST'"
  fi
fi

echo
echo "Done. Restart Claude Code (or open a new session) to see it."
echo "Customize indicators and colors any time in: $CONFIG"
echo "See the README's 'Configure' section for the reset-time and refresh-interval details."
