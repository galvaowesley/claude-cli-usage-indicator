#!/usr/bin/env bash
# Installs claude-usage-indicator as your Claude Code status line.
# Safe to re-run: it only ever touches the "statusLine" key in
# ~/.claude/settings.json, and never overwrites an existing statusline.conf.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SCRIPT_DEST="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

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

# set_conf <key> <value>: set key=value in statusline.conf, replacing an
# existing line for that key or appending a new one.
set_conf() {
  if grep -q "^$1=" "$CONFIG"; then
    local tmp_conf
    tmp_conf=$(mktemp)
    awk -v k="$1" -v v="$2" '{ if ($0 ~ "^"k"=") print k"="v; else print }' "$CONFIG" > "$tmp_conf" && mv "$tmp_conf" "$CONFIG"
  else
    printf '%s=%s\n' "$1" "$2" >> "$CONFIG"
  fi
}

BRANCH_ICON_EMOJI="🌿"
BRANCH_ICON_NERD=$(printf '\xef\x84\xa6')   # U+F126, Nerd Font "code-branch"

if [ -f "$CONFIG" ] && [ -t 0 ]; then
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

  echo
  echo "How should the 5h/weekly rate-limit reset time be shown?"
  echo "  1) Relative, default. Ex: reset 3h45m"
  echo "  2) Exact clock time.  Ex: reset 14:32"
  echo "  3) Both.              Ex: reset 14:32 (3h45m)"
  read -rp "Choose 1, 2 or 3 [1]: " reset_choice
  case "$reset_choice" in
    2) chosen_reset_format="absolute" ;;
    3) chosen_reset_format="both" ;;
    *) chosen_reset_format="relative" ;;
  esac
  set_conf reset_format "$chosen_reset_format"

  chosen_reset_clock="24h"
  if [ "$chosen_reset_format" != "relative" ]; then
    echo
    echo "Clock style for that exact time?"
    echo "  1) 24h, default. Ex: 14:32"
    echo "  2) 12h.          Ex: 2:32pm"
    read -rp "Choose 1 or 2 [1]: " clock_choice
    [ "$clock_choice" = "2" ] && chosen_reset_clock="12h"
  fi
  set_conf reset_clock "$chosen_reset_clock"
  echo "-> set reset_format/reset_clock in $CONFIG"

  echo
  echo "How often should indicators auto-refresh on their own, on top of"
  echo "Claude Code's normal update events (new message, session start, ...)?"
  echo "This is what makes reset countdowns and usage %'s feel live while"
  echo "you're idle, instead of only updating when you send a message."
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
fi

echo
echo "Done. Restart Claude Code (or open a new session) to see it."
echo "Customize indicators and colors any time in: $CONFIG"
echo "See the README's 'Configure' section for the reset-time and refresh-interval details."
