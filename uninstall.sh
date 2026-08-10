#!/usr/bin/env bash
# Removes claude-usage-indicator's statusLine wiring from Claude Code.
# Leaves ~/.claude/statusline.conf in place unless you pass --purge.
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SCRIPT_DEST="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
CONFIG_CMD_DEST="$CLAUDE_DIR/statusline-config"
SKILL_DEST="$CLAUDE_DIR/skills/statusline-config"

if command -v jq >/dev/null 2>&1 && [ -f "$SETTINGS" ]; then
  TMP=$(mktemp)
  jq 'del(.statusLine)' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
  echo "-> removed statusLine from $SETTINGS"
fi

rm -f "$SCRIPT_DEST"
echo "-> removed $SCRIPT_DEST"

rm -f "$CONFIG_CMD_DEST"
# only our own symlink, never a real file someone else put there
if [ -L "$HOME/.local/bin/statusline-config" ]; then
  rm -f "$HOME/.local/bin/statusline-config"
fi
# Remove our skill, then the skills/ directory itself only if that left it
# empty: other skills may well live there.
rm -f "$SKILL_DEST/SKILL.md"
rmdir "$SKILL_DEST" 2>/dev/null || true
rmdir "$CLAUDE_DIR/skills" 2>/dev/null || true
echo "-> removed the statusline-config command and its /statusline-config skill"

if [ "${1:-}" = "--purge" ]; then
  rm -f "$CLAUDE_DIR/statusline.conf" "$CLAUDE_DIR/.statusline-cpu-cache"
  echo "-> removed statusline.conf and cache (--purge)"
else
  echo "-> kept $CLAUDE_DIR/statusline.conf (rerun with --purge to delete it too)"
fi

echo "Done."
