#!/usr/bin/env bash
# Installs claude-usage-indicator as your Claude Code status line.
# Safe to re-run: it only ever touches the "statusLine" key in
# ~/.claude/settings.json, and never overwrites an existing statusline.conf.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SCRIPT_DEST="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
CONFIG_CMD_DEST="$CLAUDE_DIR/claude-usage-indicator"
SKILL_DEST="$CLAUDE_DIR/skills/claude-usage-indicator"

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

cp "$REPO_DIR/claude-usage-indicator" "$CONFIG_CMD_DEST"
chmod +x "$CONFIG_CMD_DEST"
echo "-> installed $CONFIG_CMD_DEST (change any of these settings later)"

# The skill turns the command above into /claude-usage-indicator inside Claude
# Code, which is the path most people will actually use: it asks what to
# change with a picker instead of needing a remembered path and flags.
mkdir -p "$SKILL_DEST"
cp "$REPO_DIR/skills/claude-usage-indicator/SKILL.md" "$SKILL_DEST/SKILL.md"
echo "-> installed the /claude-usage-indicator skill in $SKILL_DEST"

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
# helpers they share) live in claude-usage-indicator so this installer and that
# standalone command run the exact same prompts instead of two copies
# drifting apart. Sourcing only defines the functions - see the guard at
# the bottom of that file.
# shellcheck source=claude-usage-indicator
. "$REPO_DIR/claude-usage-indicator"

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

  configure_refresh

  echo
  echo "To change any of this later, run /claude-usage-indicator inside Claude Code."
  echo "It asks what you want to change and applies it, no paths to remember."
  echo "In a plain shell, the same thing is the 'claude-usage-indicator' command."
  if [ -d "$HOME/.local/bin" ]; then
    case ":${PATH}:" in
      *":$HOME/.local/bin:"*)
        read -rp "Also link it into ~/.local/bin for shell use? [Y/n]: " link_choice
        case "$link_choice" in
          [Nn]*) echo "   In a shell, run it as: $CONFIG_CMD_DEST" ;;
          *)
            if ln -sf "$CONFIG_CMD_DEST" "$HOME/.local/bin/claude-usage-indicator"; then
              echo "-> linked ~/.local/bin/claude-usage-indicator"
            fi
            ;;
        esac
        ;;
      *) echo "   In a shell, run it as: $CONFIG_CMD_DEST" ;;
    esac
  else
    echo "   In a shell, run it as: $CONFIG_CMD_DEST"
  fi
fi

echo
echo "Done. Restart Claude Code (or open a new session) to see it."
echo "Then /claude-usage-indicator reopens all of this from inside Claude Code:"
echo "which indicators show, their order, reset times, refresh rate, and a way"
echo "back to defaults. Colors and thresholds live in: $CONFIG"
echo "See the README's 'Configure' section for the full reference."
