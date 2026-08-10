#!/usr/bin/env bash
# Removes claude-usage-indicator's statusLine wiring from Claude Code.
# Leaves ~/.claude/statusline.conf in place unless you pass --purge.
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SCRIPT_DEST="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
CCX_DEST="$CLAUDE_DIR/ccx"
MODE_HOOK_DEST="$CLAUDE_DIR/statusline-mode.sh"

if command -v jq >/dev/null 2>&1 && [ -f "$SETTINGS" ]; then
  TMP=$(mktemp)
  jq 'del(.statusLine)' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
  echo "-> removed statusLine from $SETTINGS"

  # Drop only the hook entries pointing at our own script. Anything else
  # registered on PreToolUse or Stop belongs to something else and stays.
  # An event key is deleted only if removing ours emptied it, and .hooks
  # itself only if that emptied the object.
  TMP=$(mktemp)
  if jq --arg cmd "$MODE_HOOK_DEST" '
        # Entries that do not mention our command pass through byte for
        # byte, including odd ones with no "hooks" array. An event key, and
        # .hooks itself, are removed only when our own removal is what
        # emptied them.
        def strip_ours:
          map(
            if ((.hooks // []) | any(.command == $cmd))
            then ( .hooks = ((.hooks // []) | map(select(.command != $cmd)))
                   | if (.hooks | length) == 0 then empty else . end )
            else .
            end
          );
        . as $orig
        | if (.hooks | type) == "object" then
            (if (.hooks | has("PreToolUse")) then .hooks.PreToolUse |= strip_ours else . end)
            | (if (.hooks | has("Stop")) then .hooks.Stop |= strip_ours else . end)
            | (if (.hooks | has("PreToolUse")) and ((.hooks.PreToolUse | length) == 0)
               then del(.hooks.PreToolUse) else . end)
            | (if (.hooks | has("Stop")) and ((.hooks.Stop | length) == 0)
               then del(.hooks.Stop) else . end)
            | (if ((.hooks | length) == 0) and (($orig.hooks | length) > 0)
               then del(.hooks) else . end)
          else . end
      ' "$SETTINGS" > "$TMP"; then
    mv "$TMP" "$SETTINGS"
    echo "-> removed the permission-mode hook from $SETTINGS (other hooks kept)"
  else
    rm -f "$TMP"
    echo "warning: could not clean hooks in $SETTINGS, left it unchanged" >&2
  fi
fi

rm -f "$SCRIPT_DEST"
echo "-> removed $SCRIPT_DEST"

rm -f "$CCX_DEST" "$MODE_HOOK_DEST"
# only our own symlink, never a real file someone else put there
if [ -L "$HOME/.local/bin/ccx" ]; then
  rm -f "$HOME/.local/bin/ccx"
fi
echo "-> removed ccx and the permission-mode hook script"

rm -f "$CLAUDE_DIR/.statusline-panel" "$CLAUDE_DIR/.statusline-mode"

if [ "${1:-}" = "--purge" ]; then
  rm -f "$CLAUDE_DIR/statusline.conf" "$CLAUDE_DIR/.statusline-cpu-cache"
  echo "-> removed statusline.conf and cache (--purge)"
else
  echo "-> kept $CLAUDE_DIR/statusline.conf (rerun with --purge to delete it too)"
fi

echo "Done."
