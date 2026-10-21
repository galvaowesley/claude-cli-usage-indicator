#!/usr/bin/env bash
# Removes usage indicator statusLine wiring from Claude Code and/or Antigravity CLI.
# Leaves statusline.conf in place unless you pass --purge.
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
AGY_DIR="$HOME/.gemini/antigravity-cli"
AGY_CONFIG_DIR="$HOME/.gemini/config"

PURGE=0
TARGET_CLAUDE=0
TARGET_AGY=0

for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
    --claude) TARGET_CLAUDE=1 ;;
    --agy|--antigravity) TARGET_AGY=1 ;;
    --all|--both) TARGET_CLAUDE=1; TARGET_AGY=1 ;;
    -h|--help)
      echo "usage: ./uninstall.sh [--claude | --agy | --all] [--purge]"
      exit 0
      ;;
  esac
done

if [ "$TARGET_CLAUDE" -eq 0 ] && [ "$TARGET_AGY" -eq 0 ]; then
  has_claude=0
  has_agy=0
  [ -f "$CLAUDE_DIR/statusline.sh" ] && has_claude=1
  [ -f "$AGY_DIR/statusline.sh" ] && has_agy=1

  if [ "$has_claude" -eq 1 ] && [ "$has_agy" -eq 1 ] && [ -t 0 ]; then
    echo "Detected statusline installed for both Claude Code and Antigravity CLI."
    echo "Which would you like to uninstall?"
    echo "  1) Both Claude Code and Antigravity CLI"
    echo "  2) Claude Code only"
    echo "  3) Antigravity CLI only"
    read -rp "Choose 1, 2 or 3 [1]: " uninst_choice
    case "$uninst_choice" in
      2) TARGET_CLAUDE=1 ;;
      3) TARGET_AGY=1 ;;
      *) TARGET_CLAUDE=1; TARGET_AGY=1 ;;
    esac
  elif [ "$has_agy" -eq 1 ] && [ "$has_claude" -eq 0 ]; then
    TARGET_AGY=1
  elif [ "$has_claude" -eq 1 ] && [ "$has_agy" -eq 0 ]; then
    TARGET_CLAUDE=1
  else
    TARGET_CLAUDE=1
    TARGET_AGY=1
  fi
fi

# Uninstall Claude Code
if [ "$TARGET_CLAUDE" -eq 1 ]; then
  echo "Uninstalling from Claude Code..."
  SETTINGS="$CLAUDE_DIR/settings.json"
  if command -v jq >/dev/null 2>&1 && [ -f "$SETTINGS" ]; then
    TMP=$(mktemp)
    jq 'del(.statusLine)' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
    echo "-> removed statusLine from $SETTINGS"
  fi

  rm -f "$CLAUDE_DIR/statusline.sh"
  echo "-> removed $CLAUDE_DIR/statusline.sh"

  rm -f "$CLAUDE_DIR/claude-usage-indicator"
  if [ -L "$HOME/.local/bin/claude-usage-indicator" ]; then
    rm -f "$HOME/.local/bin/claude-usage-indicator"
  fi

  SKILL_DEST="$CLAUDE_DIR/skills/claude-usage-indicator"
  rm -f "$SKILL_DEST/SKILL.md"
  rmdir "$SKILL_DEST" 2>/dev/null || true
  rmdir "$CLAUDE_DIR/skills" 2>/dev/null || true
  echo "-> removed claude-usage-indicator command and /claude-usage-indicator skill"

  if [ "$PURGE" -eq 1 ]; then
    rm -f "$CLAUDE_DIR/statusline.conf" "$CLAUDE_DIR/.statusline-cpu-cache"
    echo "-> removed statusline.conf and cache in $CLAUDE_DIR (--purge)"
  else
    echo "-> kept $CLAUDE_DIR/statusline.conf (rerun with --purge to delete it too)"
  fi
fi

# Uninstall Antigravity CLI
if [ "$TARGET_AGY" -eq 1 ]; then
  echo
  echo "Uninstalling from Antigravity CLI..."
  AGY_SETTINGS="$AGY_DIR/settings.json"
  if command -v jq >/dev/null 2>&1 && [ -f "$AGY_SETTINGS" ]; then
    TMP=$(mktemp)
    jq 'del(.statusLine)' "$AGY_SETTINGS" > "$TMP" && mv "$TMP" "$AGY_SETTINGS"
    echo "-> removed statusLine from $AGY_SETTINGS"
  fi

  rm -f "$AGY_DIR/statusline.sh"
  echo "-> removed $AGY_DIR/statusline.sh"

  rm -f "$AGY_DIR/agy-usage-indicator"
  if [ -L "$HOME/.local/bin/agy-usage-indicator" ]; then
    rm -f "$HOME/.local/bin/agy-usage-indicator"
  fi

  AGY_SKILL_DEST="$AGY_CONFIG_DIR/skills/agy-usage-indicator"
  rm -f "$AGY_SKILL_DEST/SKILL.md"
  rmdir "$AGY_SKILL_DEST" 2>/dev/null || true
  rmdir "$AGY_CONFIG_DIR/skills" 2>/dev/null || true
  echo "-> removed agy-usage-indicator command and /agy-usage-indicator skill"

  if [ "$PURGE" -eq 1 ]; then
    rm -f "$AGY_DIR/statusline.conf" "$AGY_DIR/.statusline-cpu-cache"
    echo "-> removed statusline.conf and cache in $AGY_DIR (--purge)"
  else
    echo "-> kept $AGY_DIR/statusline.conf (rerun with --purge to delete it too)"
  fi
fi

echo
echo "Done."
