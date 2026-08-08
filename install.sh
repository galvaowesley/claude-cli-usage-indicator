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
jq --arg cmd "$SCRIPT_DEST" '.statusLine = {"type":"command","command":$cmd,"padding":0}' \
  "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
echo "-> wired up statusLine in $SETTINGS"

# Trigger one render so statusline.conf gets auto-created, then let the
# user pick the branch icon right here instead of having to edit the
# config file by hand afterwards.
CONFIG="$CLAUDE_DIR/statusline.conf"
[ -f "$CONFIG" ] || echo '{}' | "$SCRIPT_DEST" >/dev/null 2>&1 || true

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
  if grep -q '^branch_icon=' "$CONFIG"; then
    TMP_CONF=$(mktemp)
    awk -v icon="$chosen_icon" '{ if ($0 ~ /^branch_icon=/) print "branch_icon=" icon; else print }' "$CONFIG" > "$TMP_CONF" && mv "$TMP_CONF" "$CONFIG"
  else
    printf 'branch_icon=%s\n' "$chosen_icon" >> "$CONFIG"
  fi
  echo "-> set branch_icon in $CONFIG"
fi

echo
echo "Done. Restart Claude Code (or open a new session) to see it."
echo "Customize indicators and colors any time in: $CONFIG"
echo "See the README's 'Configure' section for the branch icon walkthrough."
