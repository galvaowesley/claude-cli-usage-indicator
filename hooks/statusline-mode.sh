#!/usr/bin/env bash
# Caches the session's permission mode so the status line can show it.
#
# Claude Code sends `permission_mode` to hooks but not to statusLine
# scripts, so without this there is simply no way for the session panel to
# know whether you are in plan, acceptEdits, bypassPermissions, and so on.
#
# This writes one word to one file and does nothing else: no stdout, no
# stderr, always exit 0. A hook that fails or prints can block a tool call
# or clutter the transcript, and a status line nicety must never do either.
set -u

CACHE="$HOME/.claude/.statusline-mode"

input=$(cat 2>/dev/null) || exit 0
[ -n "$input" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

mode=$(printf '%s' "$input" | jq -r '.permission_mode // empty' 2>/dev/null) || exit 0
[ -n "$mode" ] && printf '%s\n' "$mode" > "$CACHE" 2>/dev/null

exit 0
