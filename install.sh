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

echo
echo "Done. Restart Claude Code (or open a new session) to see it."
echo "Customize indicators and colors in: $CLAUDE_DIR/statusline.conf"
echo "(created automatically the first time the status line renders)"
echo
echo "Tip: want the sharper code-branch icon instead of the default 🌿? See"
echo "the 'Optional: sharper branch icon' section in the README."
