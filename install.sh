#!/usr/bin/env bash
# Installs usage-indicator as your status line for Claude Code, Antigravity CLI, or both.
# Safe to re-run: it only touches the "statusLine" key in the respective settings.json,
# and never overwrites an existing statusline.conf.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
AGY_DIR="$HOME/.gemini/antigravity-cli"
AGY_CONFIG_DIR="$HOME/.gemini/config"

echo "cli-usage-indicator installer (Claude Code & Antigravity CLI)"
echo "------------------------------------------------------------"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required but not found in PATH." >&2
  echo "  macOS:  brew install jq" >&2
  echo "  Linux:  sudo apt install jq   (or) sudo dnf install jq   (or) sudo pacman -S jq" >&2
  exit 1
fi

INSTALL_CLAUDE=0
INSTALL_AGY=0

# Parse CLI flags
for arg in "$@"; do
  case "$arg" in
    --claude) INSTALL_CLAUDE=1 ;;
    --agy|--antigravity) INSTALL_AGY=1 ;;
    --all|--both) INSTALL_CLAUDE=1; INSTALL_AGY=1 ;;
    -h|--help)
      echo "usage: ./install.sh [--claude | --agy | --all]"
      exit 0
      ;;
  esac
done

# If no target specified by flags, detect or ask
if [ "$INSTALL_CLAUDE" -eq 0 ] && [ "$INSTALL_AGY" -eq 0 ]; then
  has_claude=0
  has_agy=0
  [ -d "$CLAUDE_DIR" ] && has_claude=1
  ([ -d "$AGY_DIR" ] || command -v agy >/dev/null 2>&1) && has_agy=1

  if [ "$has_claude" -eq 1 ] && [ "$has_agy" -eq 1 ] && [ -t 0 ]; then
    echo "Detected both Claude Code and Antigravity CLI on your system."
    echo "Which AI CLI would you like to install the status line for?"
    echo "  1) Both Claude Code and Antigravity CLI (Recommended)"
    echo "  2) Claude Code only"
    echo "  3) Antigravity CLI only"
    read -rp "Choose 1, 2 or 3 [1]: " target_choice
    case "$target_choice" in
      2) INSTALL_CLAUDE=1 ;;
      3) INSTALL_AGY=1 ;;
      *) INSTALL_CLAUDE=1; INSTALL_AGY=1 ;;
    esac
  elif [ "$has_agy" -eq 1 ] && [ "$has_claude" -eq 0 ]; then
    INSTALL_AGY=1
  elif [ "$has_claude" -eq 1 ] && [ "$has_agy" -eq 0 ]; then
    INSTALL_CLAUDE=1
  else
    # Default to both if interactive, or Claude if neither explicitly found
    if [ -t 0 ]; then
      echo "Which AI CLI would you like to install the status line for?"
      echo "  1) Both Claude Code and Antigravity CLI"
      echo "  2) Claude Code only"
      echo "  3) Antigravity CLI only"
      read -rp "Choose 1, 2 or 3 [1]: " target_choice
      case "$target_choice" in
        2) INSTALL_CLAUDE=1 ;;
        3) INSTALL_AGY=1 ;;
        *) INSTALL_CLAUDE=1; INSTALL_AGY=1 ;;
      esac
    else
      INSTALL_CLAUDE=1
    fi
  fi
fi

# Sourcing claude-usage-indicator loads the helper functions
# shellcheck source=claude-usage-indicator
. "$REPO_DIR/claude-usage-indicator"

# 1. Install for Claude Code if selected
if [ "$INSTALL_CLAUDE" -eq 1 ]; then
  echo
  echo "Installing for Claude Code..."
  mkdir -p "$CLAUDE_DIR" "$CLAUDE_DIR/skills/claude-usage-indicator"
  SCRIPT_DEST="$CLAUDE_DIR/statusline.sh"
  CONFIG_CMD_DEST="$CLAUDE_DIR/claude-usage-indicator"
  SETTINGS="$CLAUDE_DIR/settings.json"
  CONFIG="$CLAUDE_DIR/statusline.conf"

  cp "$REPO_DIR/statusline.sh" "$SCRIPT_DEST"
  chmod +x "$SCRIPT_DEST"
  echo "-> installed $SCRIPT_DEST"

  cp "$REPO_DIR/claude-usage-indicator" "$CONFIG_CMD_DEST"
  chmod +x "$CONFIG_CMD_DEST"
  echo "-> installed $CONFIG_CMD_DEST"

  cp "$REPO_DIR/skills/claude-usage-indicator/SKILL.md" "$CLAUDE_DIR/skills/claude-usage-indicator/SKILL.md"
  echo "-> installed the /claude-usage-indicator skill"

  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  TMP=$(mktemp)
  jq --arg cmd "$SCRIPT_DEST" \
    '.statusLine = ((.statusLine // {}) + {"type":"command","command":$cmd,"padding":0})' \
    "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
  echo "-> wired up statusLine in $SETTINGS"

  [ -f "$CONFIG" ] || STATUSLINE_CONFIG="$CONFIG" echo '{}' | "$SCRIPT_DEST" >/dev/null 2>&1 || true
fi

# 2. Install for Antigravity CLI if selected
if [ "$INSTALL_AGY" -eq 1 ]; then
  echo
  echo "Installing for Antigravity CLI..."
  mkdir -p "$AGY_DIR" "$AGY_CONFIG_DIR/skills/agy-usage-indicator"
  AGY_SCRIPT_DEST="$AGY_DIR/statusline.sh"
  AGY_CONFIG_CMD_DEST="$AGY_DIR/agy-usage-indicator"
  AGY_SETTINGS="$AGY_DIR/settings.json"
  AGY_CONFIG="$AGY_DIR/statusline.conf"

  cp "$REPO_DIR/statusline.sh" "$AGY_SCRIPT_DEST"
  chmod +x "$AGY_SCRIPT_DEST"
  echo "-> installed $AGY_SCRIPT_DEST"

  cp "$REPO_DIR/claude-usage-indicator" "$AGY_CONFIG_CMD_DEST"
  chmod +x "$AGY_CONFIG_CMD_DEST"
  echo "-> installed $AGY_CONFIG_CMD_DEST"

  cp "$REPO_DIR/skills/agy-usage-indicator/SKILL.md" "$AGY_CONFIG_DIR/skills/agy-usage-indicator/SKILL.md"
  echo "-> installed the /agy-usage-indicator skill in $AGY_CONFIG_DIR/skills/agy-usage-indicator"

  [ -f "$AGY_SETTINGS" ] || echo '{}' > "$AGY_SETTINGS"
  TMP=$(mktemp)
  jq --arg cmd "$AGY_SCRIPT_DEST" \
    '.statusLine = ((.statusLine // {}) + {"command":$cmd,"enabled":true,"padding":0})' \
    "$AGY_SETTINGS" > "$TMP" && mv "$TMP" "$AGY_SETTINGS"
  echo "-> wired up statusLine in $AGY_SETTINGS"

  [ -f "$AGY_CONFIG" ] || STATUSLINE_CONFIG="$AGY_CONFIG" echo '{}' | "$AGY_SCRIPT_DEST" >/dev/null 2>&1 || true
fi

# Configure display options interactively
BRANCH_ICON_EMOJI="🌿"
BRANCH_ICON_NERD=$(printf '\xef\x84\xa6')   # U+F126, Nerd Font "code-branch"

PRIMARY_CONFIG=""
[ "$INSTALL_CLAUDE" -eq 1 ] && PRIMARY_CONFIG="$CLAUDE_DIR/statusline.conf"
[ -z "$PRIMARY_CONFIG" ] && [ "$INSTALL_AGY" -eq 1 ] && PRIMARY_CONFIG="$AGY_DIR/statusline.conf"

if [ -n "$PRIMARY_CONFIG" ] && [ -f "$PRIMARY_CONFIG" ] && [ -t 0 ]; then
  CONFIG="$PRIMARY_CONFIG"
  configure_indicators

  # Sync to both configs if both installed
  if [ "$INSTALL_CLAUDE" -eq 1 ] && [ "$INSTALL_AGY" -eq 1 ]; then
    CONFIG="$AGY_DIR/statusline.conf"
    set_indicators $(current_indicators) 2>/dev/null || true
    CONFIG="$PRIMARY_CONFIG"
  fi

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
  if [ "$INSTALL_CLAUDE" -eq 1 ] && [ "$INSTALL_AGY" -eq 1 ]; then
    CONFIG="$AGY_DIR/statusline.conf"
    set_conf branch_icon "$chosen_icon"
    CONFIG="$PRIMARY_CONFIG"
  fi
  echo "-> set branch_icon"

  configure_reset
  if [ "$INSTALL_CLAUDE" -eq 1 ] && [ "$INSTALL_AGY" -eq 1 ]; then
    reset_fmt=$(grep -E '^reset_format=' "$PRIMARY_CONFIG" | tail -1 | cut -d= -f2-)
    reset_clk=$(grep -E '^reset_clock=' "$PRIMARY_CONFIG" | tail -1 | cut -d= -f2-)
    CONFIG="$AGY_DIR/statusline.conf"
    set_conf reset_format "$reset_fmt"
    set_conf reset_clock "$reset_clk"
    CONFIG="$PRIMARY_CONFIG"
  fi

  # Refresh interval configuration
  echo
  echo "How often should indicators auto-refresh on their own, on top of normal update events?"
  echo "This is what makes reset countdowns and usage percentages feel live while you're idle."
  echo "  1) Off.                   Only updates on CLI's own events."
  echo "  2) Every 5s, recommended. Feels live, no noticeable overhead."
  echo "  3) Every 10s.             Live, lighter touch."
  echo "  4) Custom (1-60s)."
  read -rp "Choose 1-4 [2]: " refresh_choice
  case "$refresh_choice" in
    1) refresh_val=0 ;;
    3) refresh_val=10 ;;
    4)
      read -rp "Seconds between refreshes (1-60): " refresh_val
      case "$refresh_val" in ''|*[!0-9]*) refresh_val=5 ;; esac
      [ "$refresh_val" -lt 1 ] && refresh_val=1
      [ "$refresh_val" -gt 60 ] && refresh_val=60
      ;;
    *) refresh_val=5 ;;
  esac

  if [ "$INSTALL_CLAUDE" -eq 1 ]; then
    TARGET="claude"
    SETTINGS="$CLAUDE_DIR/settings.json"
    apply_refresh "$refresh_val" || true
  fi
  if [ "$INSTALL_AGY" -eq 1 ]; then
    TARGET="antigravity"
    SETTINGS="$AGY_DIR/settings.json"
    apply_refresh "$refresh_val" || true
  fi

  echo
  if [ -d "$HOME/.local/bin" ]; then
    case ":${PATH}:" in
      *":$HOME/.local/bin:"*)
        read -rp "Link command(s) into ~/.local/bin for shell use? [Y/n]: " link_choice
        case "$link_choice" in
          [Nn]*) ;;
          *)
            if [ "$INSTALL_CLAUDE" -eq 1 ]; then
              ln -sf "$CLAUDE_DIR/claude-usage-indicator" "$HOME/.local/bin/claude-usage-indicator"
              echo "-> linked ~/.local/bin/claude-usage-indicator"
            fi
            if [ "$INSTALL_AGY" -eq 1 ]; then
              ln -sf "$AGY_DIR/agy-usage-indicator" "$HOME/.local/bin/agy-usage-indicator"
              echo "-> linked ~/.local/bin/agy-usage-indicator"
            fi
            ;;
        esac
        ;;
    esac
  fi
fi

echo
echo "Installation complete!"
[ "$INSTALL_CLAUDE" -eq 1 ] && echo "· Claude Code: restart Claude Code (or open a new session) to see it. Use /claude-usage-indicator to change settings."
[ "$INSTALL_AGY" -eq 1 ] && echo "· Antigravity CLI: restart agy (or open a new session) to see it. Use /agy-usage-indicator to change settings."
echo "See the README for full configuration reference."
