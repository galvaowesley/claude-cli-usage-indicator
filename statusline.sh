#!/usr/bin/env bash
# claude-usage-indicator — configurable status line for Claude Code.
# https://github.com/galvaowesley/claude-usage-indicator
# Original idea: Rodrigo Belém's LinkedIn post.
#
# Claude Code pipes one JSON object to this script's stdin every time the
# status line is (re)rendered (model, workspace, context_window,
# rate_limits, ...). This script turns that into a colored, single- or
# multi-row band.
#
# CUSTOMIZE what's shown (and in what order) by editing:
#   ~/.claude/statusline.conf
# It's auto-created on first run with every indicator enabled. Each
# indicator is its own `ind_*` function below — add one and list its name
# in the config to wire in something new.

export LC_NUMERIC=C   # jq must always see "." decimals, regardless of locale

OS=$(uname -s)

CLAUDE_DIR="$HOME/.claude"
CONFIG="$CLAUDE_DIR/statusline.conf"
CPU_CACHE="$CLAUDE_DIR/.statusline-cpu-cache"
# Which detail panel is expanded under the band: off | context | session.
# Written by the CLI mode below (and by the `ccx` wrapper), read on every
# render. Deliberately global rather than per-session: the toggling process
# has no way to learn the session id, so a toggle shows the panel in every
# open session on its next render.
PANEL_STATE="$CLAUDE_DIR/.statusline-panel"
# Current permission mode, cached by the companion hook. Claude Code sends
# it to hooks but not to the status line, so without that hook installed
# there is simply nothing to show.
MODE_CACHE="$CLAUDE_DIR/.statusline-mode"

# --- CLI mode: flip the panel state, then exit ---------------------------
# Claude Code always runs this script with the payload on stdin and no
# arguments, so any argument means a human invoked it from a shell to
# toggle a panel. That has to be handled before reading stdin: a CLI run
# has nothing piped in, and `cat` would block forever waiting for EOF.
panel_current() {
  local p=""
  [ -r "$PANEL_STATE" ] && IFS= read -r p < "$PANEL_STATE" 2>/dev/null
  case "$p" in context|session) printf '%s' "$p" ;; *) printf 'off' ;; esac
}

panel_usage() {
  cat >&2 <<'USAGE'
usage: statusline.sh --panel [context|session|off|status]

  context   expand the context detail panel (collapses it if already shown)
  session   expand the session detail panel (collapses it if already shown)
  off       collapse whichever panel is open
  status    print the current panel state without changing it

With no arguments the script renders the status line, reading Claude Code's
JSON payload from stdin.
USAGE
}

if [ "$#" -gt 0 ]; then
  case "$1" in
    --panel)
      panel_want="${2:-context}"
      panel_cur=$(panel_current)
      case "$panel_want" in
        status) printf 'panel: %s\n' "$panel_cur"; exit 0 ;;
        off)    panel_new="off" ;;
        context|session)
          # asking for the panel that is already up means "put it away"
          if [ "$panel_cur" = "$panel_want" ]; then
            panel_new="off"
          else
            panel_new="$panel_want"
          fi
          ;;
        *) panel_usage; exit 2 ;;
      esac
      mkdir -p "$CLAUDE_DIR" || exit 1
      if [ "$panel_new" = "off" ]; then
        rm -f "$PANEL_STATE"
      else
        printf '%s\n' "$panel_new" > "$PANEL_STATE" || exit 1
      fi
      printf 'panel: %s\n' "$panel_new"
      exit 0
      ;;
    -h|--help) panel_usage; exit 0 ;;
    *) panel_usage; exit 2 ;;
  esac
fi

input=$(cat)

JQ=$(command -v jq)
if [ -z "$JQ" ] || [ ! -x "$JQ" ]; then
  printf "statusline: jq not found — install it (see README) and reopen Claude Code"
  exit 0
fi
jqr() { printf '%s' "$input" | "$JQ" -r "$1"; }

DEFAULT_CONFIG='# Claude Code statusline — pick which indicators to show, and in what
# order. One per line. Comment lines start with #. Available indicators:
#   model      Claude model in use, highlighted (bold)
#   effort     current reasoning-effort level (low/medium/high/xhigh/max —
#              only shown when the active model supports it; higher levels
#              burn through the 5h/week limits faster). Right after
#              "model" in this list, it sits glued to the model name
#              with no separator between them, like a subtitle.
#   dir        current folder name
#   branch     git branch (+ "*" if there are uncommitted changes)
#   context    % of context window used in this session, + token count
#   five_hour  % of your 5h rate limit used (+ time to reset)
#   week       % of your weekly rate limit used (+ time to reset)
#   cpu        system CPU usage %
#   ram        system RAM usage %
#
# Visual style (key=value). Colors are 256-color codes — see a chart at
# https://www.ditig.com/256-colors-cheat-sheet. Thresholds are percentages;
# below threshold_mid = green, below threshold_high = yellow, else red.
#   bg=236            band background
#   sep_char=┃         separator glyph between indicators (try │ ▏ ◆ • » ->)
#   sep_color=73       separator color for indicators that aren'\''t grouped
#   color_low=114      "ok" value color   (green)
#   color_mid=221      "warn" value color (yellow)
#   color_high=203     "hot" value color  (red)
#   threshold_mid=50
#   threshold_high=80
#   model_color=255    model name color (bold)
#   branch_icon=🌿      glyph before the git branch name. Works anywhere by
#              default (emoji, no special font needed). If you have a Nerd
#              Font set as your terminal font, try branch_icon= for the
#              classic code-branch icon instead.
#   reset_format=relative   how five_hour/week show their reset time:
#              relative (default) -> "reset 3h45m"
#              absolute           -> "reset 14:32" (exact local clock time)
#              both               -> "reset 14:32 (3h45m)"
#   reset_clock=24h    clock style used by reset_format=absolute/both:
#              24h (default) -> "14:32"   12h -> "2:32pm"
#
# Expandable panels: extra rows of detail drawn under the band. Off by
# default; toggle one with `ccx` (or `~/.claude/statusline.sh --panel
# context|session|off`). The state is shared by every open session, and
# panels are skipped entirely on terminals narrower than 60 columns.
#   panel_border=240   box border and rule color
#   panel_label=245    row-label color inside a panel
# Context panel category colors, matching the swatch beside each row and
# its slice of the stacked bar:
#   cat_input=214        fresh input tokens (orange)
#   cat_cache_read=75    tokens read from cache (blue)
#   cat_cache_write=114  tokens written to cache (green)
#   cat_output=141       output tokens (purple)
#   cat_free=240         unused context (grey)
#
# Group colors: context/five_hour/week are tagged as Claude-usage,
# cpu/ram as machine-usage — their label AND the separator leading into
# them are tinted so the two kinds of indicator are visually distinct at
# a glance, independent of the green/yellow/red severity color.
#   claude_color=110   label + separator color for Claude-usage indicators
#   system_color=216   label + separator color for machine-usage indicators
#
# Effort level colors (bold), one per level, "faster" to "smarter":
#   effort_low=178     amber
#   effort_medium=114  green
#   effort_high=111    blue
#   effort_xhigh=141   purple
#   effort_max=203     red

model
effort
context
five_hour
week
dir
branch
cpu
ram

bg=236
sep_char=┃
sep_color=73
color_low=114
color_mid=221
color_high=203
threshold_mid=50
threshold_high=80
claude_color=216
system_color=110
model_color=255
effort_low=178
effort_medium=114
effort_high=111
effort_xhigh=141
effort_max=203
branch_icon=🌿
reset_format=relative
reset_clock=24h
panel_border=240
panel_label=245
cat_input=214
cat_cache_read=75
cat_cache_write=114
cat_output=141
cat_free=240
'

[ -f "$CONFIG" ] || printf '%s' "$DEFAULT_CONFIG" > "$CONFIG"

# --- style, read from config -------------------------------------------
BG_CODE=236
SEP_CHAR="┃"
SEP_CODE=73
GREEN_CODE=114
YELLOW_CODE=221
RED_CODE=203
THRESH_MID=50
THRESH_HIGH=80
CLAUDE_CODE=216
SYSTEM_CODE=110
MODEL_CODE=255
EFFORT_LOW_CODE=178
EFFORT_MEDIUM_CODE=114
EFFORT_HIGH_CODE=111
EFFORT_XHIGH_CODE=141
EFFORT_MAX_CODE=203
BRANCH_ICON="🌿"
RESET_FORMAT="relative"
RESET_CLOCK="24h"
PANEL_BORDER_CODE=240
PANEL_LABEL_CODE=245
CAT_INPUT_CODE=214
CAT_CACHE_READ_CODE=75
CAT_CACHE_WRITE_CODE=114
CAT_OUTPUT_CODE=141
CAT_FREE_CODE=240
while IFS= read -r cfg_line; do
  case "$cfg_line" in
    bg=*)             BG_CODE="${cfg_line#bg=}" ;;
    sep_char=*)       SEP_CHAR="${cfg_line#sep_char=}" ;;
    sep_color=*)      SEP_CODE="${cfg_line#sep_color=}" ;;
    color_low=*)      GREEN_CODE="${cfg_line#color_low=}" ;;
    color_mid=*)      YELLOW_CODE="${cfg_line#color_mid=}" ;;
    color_high=*)     RED_CODE="${cfg_line#color_high=}" ;;
    threshold_mid=*)  THRESH_MID="${cfg_line#threshold_mid=}" ;;
    threshold_high=*) THRESH_HIGH="${cfg_line#threshold_high=}" ;;
    claude_color=*)   CLAUDE_CODE="${cfg_line#claude_color=}" ;;
    system_color=*)   SYSTEM_CODE="${cfg_line#system_color=}" ;;
    model_color=*)    MODEL_CODE="${cfg_line#model_color=}" ;;
    effort_low=*)     EFFORT_LOW_CODE="${cfg_line#effort_low=}" ;;
    effort_medium=*)  EFFORT_MEDIUM_CODE="${cfg_line#effort_medium=}" ;;
    effort_high=*)    EFFORT_HIGH_CODE="${cfg_line#effort_high=}" ;;
    effort_xhigh=*)   EFFORT_XHIGH_CODE="${cfg_line#effort_xhigh=}" ;;
    effort_max=*)     EFFORT_MAX_CODE="${cfg_line#effort_max=}" ;;
    branch_icon=*)    BRANCH_ICON="${cfg_line#branch_icon=}" ;;
    reset_format=*)   RESET_FORMAT="${cfg_line#reset_format=}" ;;
    reset_clock=*)    RESET_CLOCK="${cfg_line#reset_clock=}" ;;
    panel_border=*)   PANEL_BORDER_CODE="${cfg_line#panel_border=}" ;;
    panel_label=*)    PANEL_LABEL_CODE="${cfg_line#panel_label=}" ;;
    cat_input=*)      CAT_INPUT_CODE="${cfg_line#cat_input=}" ;;
    cat_cache_read=*) CAT_CACHE_READ_CODE="${cfg_line#cat_cache_read=}" ;;
    cat_cache_write=*) CAT_CACHE_WRITE_CODE="${cfg_line#cat_cache_write=}" ;;
    cat_output=*)     CAT_OUTPUT_CODE="${cfg_line#cat_output=}" ;;
    cat_free=*)       CAT_FREE_CODE="${cfg_line#cat_free=}" ;;
  esac
done < "$CONFIG"

BG=$(printf '\033[48;5;%sm' "$BG_CODE")
SEP_COLOR=$(printf '\033[38;5;%sm' "$SEP_CODE")
FG_RESET=$'\033[39m'
DIM=$'\033[2m'
DIM_OFF=$'\033[22m'
GREEN=$(printf '\033[38;5;%sm' "$GREEN_CODE")
YELLOW=$(printf '\033[38;5;%sm' "$YELLOW_CODE")
RED=$(printf '\033[38;5;%sm' "$RED_CODE")
FULL_RESET=$'\033[0m'
# Bold text (model name, effort level) resets both weight and color in
# one shot so callers don't need two separate reset codes.
BOLD_OFF=$'\033[22;39m'
MODEL_TAG=$(printf '\033[1;38;5;%sm' "$MODEL_CODE")
# Group tags: Claude-usage indicators (context/five_hour/week) vs
# machine-usage indicators (cpu/ram) each get their own hue, applied to
# both the label text and the separator that leads into them — kept
# apart from GREEN/YELLOW/RED so severity and category never collide.
CLAUDE_TAG=$(printf '\033[38;5;%sm' "$CLAUDE_CODE")
SYSTEM_TAG=$(printf '\033[38;5;%sm' "$SYSTEM_CODE")
# Panel chrome and the context panel's per-category hues. Each category
# colors both its swatch and its slice of the stacked bar, so the bar can
# be read against the rows below it without a legend.
PANEL_BORDER=$(printf '\033[38;5;%sm' "$PANEL_BORDER_CODE")
PANEL_LABEL=$(printf '\033[38;5;%sm' "$PANEL_LABEL_CODE")
CAT_INPUT=$(printf '\033[38;5;%sm' "$CAT_INPUT_CODE")
CAT_CACHE_READ=$(printf '\033[38;5;%sm' "$CAT_CACHE_READ_CODE")
CAT_CACHE_WRITE=$(printf '\033[38;5;%sm' "$CAT_CACHE_WRITE_CODE")
CAT_OUTPUT=$(printf '\033[38;5;%sm' "$CAT_OUTPUT_CODE")
CAT_FREE=$(printf '\033[38;5;%sm' "$CAT_FREE_CODE")

# --- generic helpers -----------------------------------------------------
color_for() {
  awk -v p="$1" -v mid="$THRESH_MID" -v high="$THRESH_HIGH" 'BEGIN{
    if (p+0 < mid) print "green";
    else if (p+0 < high) print "yellow";
    else print "red";
  }'
}

fmt_pct() {
  local pct="$1"
  if [ -z "$pct" ]; then printf -- "--"; return; fi
  local c
  c=$(color_for "$pct")
  case "$c" in
    green)  printf "%s%.0f%%%s" "$GREEN" "$pct" "$FG_RESET" ;;
    yellow) printf "%s%.0f%%%s" "$YELLOW" "$pct" "$FG_RESET" ;;
    red)    printf "%s%.0f%%%s" "$RED" "$pct" "$FG_RESET" ;;
  esac
}

# unix epoch seconds -> "Xh Ym" / "Xd Yh" remaining
fmt_reset() {
  local epoch="$1"
  [ -z "$epoch" ] && return
  local now diff h m d rh
  now=$(date +%s)
  diff=$(( ${epoch%.*} - now ))
  [ "$diff" -le 0 ] && { printf "now"; return; }
  h=$(( diff / 3600 ))
  m=$(( (diff % 3600) / 60 ))
  if [ "$h" -ge 24 ]; then
    d=$(( h / 24 )); rh=$(( h % 24 ))
    printf "%dd%dh" "$d" "$rh"
  elif [ "$h" -gt 0 ]; then
    printf "%dh%02dm" "$h" "$m"
  else
    printf "%dm" "$m"
  fi
}

# unix epoch seconds -> exact local clock time ("14:32" or "2:32pm").
# Prefixes the weekday abbreviation when the reset falls on a different
# calendar day than "now", so a bare time doesn't read as "today" when
# it's actually tomorrow (or later).
fmt_reset_abs() {
  local epoch="$1"
  [ -z "$epoch" ] && return
  epoch="${epoch%.*}"
  local time_fmt="%H:%M"
  [ "$RESET_CLOCK" = "12h" ] && time_fmt="%I:%M%p"
  local today_day reset_day day_prefix="" time_str
  if [ "$OS" = "Darwin" ]; then
    today_day=$(date +%Y%m%d)
    reset_day=$(date -r "$epoch" +%Y%m%d 2>/dev/null) || return
    time_str=$(date -r "$epoch" +"$time_fmt" 2>/dev/null)
    [ "$today_day" != "$reset_day" ] && day_prefix=$(date -r "$epoch" +"%a " 2>/dev/null)
  else
    today_day=$(date +%Y%m%d)
    reset_day=$(date -d "@$epoch" +%Y%m%d 2>/dev/null) || return
    time_str=$(date -d "@$epoch" +"$time_fmt" 2>/dev/null)
    [ "$today_day" != "$reset_day" ] && day_prefix=$(date -d "@$epoch" +"%a " 2>/dev/null)
  fi
  # 12h only: lowercase the am/pm suffix, then drop the leading zero that
  # %I pads hours 1-9 with, so 14:32 reads "2:32pm" rather than "02:32pm".
  # Parameter expansion, not date's %-I, which isn't POSIX.
  if [ "$RESET_CLOCK" = "12h" ]; then
    time_str=$(printf '%s' "$time_str" | tr 'APM' 'apm')
    time_str="${time_str#0}"
  fi
  printf '%s%s' "$day_prefix" "$time_str"
}

# unix epoch seconds -> reset time as configured by reset_format:
# relative ("3h45m"), absolute ("14:32"), or both ("14:32 (3h45m)")
reset_str() {
  local epoch="$1" rel abs
  [ -z "$epoch" ] && return
  case "$RESET_FORMAT" in
    absolute) fmt_reset_abs "$epoch" ;;
    both)
      abs=$(fmt_reset_abs "$epoch")
      rel=$(fmt_reset "$epoch")
      if [ -n "$abs" ]; then printf '%s (%s)' "$abs" "$rel"; else printf '%s' "$rel"; fi
      ;;
    *) fmt_reset "$epoch" ;;
  esac
}

# terminal width, best effort: real tty -> tput -> $COLUMNS -> fallback
term_width() {
  local w=""
  w=$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')
  [ -z "$w" ] && w=$(tput cols 2>/dev/null)
  [ -z "$w" ] && w="$COLUMNS"
  [ -z "$w" ] && w=80
  printf '%s' "$w"
}

# Drop SGR escapes so a string's visible width can be measured. Done with
# parameter expansion rather than sed: it's called once per row, and the
# panels multiply the row count, so forking a process each time adds up.
# Every sequence this script emits ends in "m", which is what lets the
# inner expansion cut to the terminator.
strip_ansi() {
  local s="$1" pre post
  local esc=$'\033['
  # "$esc" stays quoted inside every expansion below: unquoted, its
  # trailing "[" would open a bracket expression in the glob pattern.
  while [ "${s#*"$esc"}" != "$s" ]; do
    pre="${s%%"$esc"*}"
    post="${s#*"$esc"}"
    post="${post#*m}"
    s="$pre$post"
  done
  printf '%s' "$s"
}

# repeat a (possibly multi-byte) character n times
rep() {
  local n="$1" c="$2" s="" i=0
  [ "$n" -le 0 ] && return
  if [ "$c" = " " ]; then printf '%*s' "$n" ''; return; fi
  while [ "$i" -lt "$n" ]; do s="$s$c"; i=$(( i + 1 )); done
  printf '%s' "$s"
}

# visible (escape-free) width of a string
vislen() {
  local v
  v=$(strip_ansi "$1")
  printf '%s' "${#v}"
}

# pad a string with spaces until it is n columns wide
pad_vis() {
  local t="$1" n="$2" l
  l=$(vislen "$t")
  [ "$l" -lt "$n" ] && t="${t}$(rep $(( n - l )) ' ')"
  printf '%s' "$t"
}

# Force a string to exactly n visible columns, padding if it is short and
# cutting if it is long. Unlike trunc() this is safe on colored text: escape
# sequences are copied through without counting toward the width, and the cut
# end is closed with a reset so a clipped color can't bleed into the border.
fit_vis() {
  local s="$1" n="$2"
  [ "$n" -le 0 ] && return
  [ "$(vislen "$s")" -le "$n" ] && { pad_vis "$s" "$n"; return; }
  local out="" vis=0 i=0 j len ch esc=$'\033'
  len=${#s}
  while [ "$i" -lt "$len" ]; do
    ch="${s:$i:1}"
    if [ "$ch" = "$esc" ]; then
      j=$i
      while [ "$j" -lt "$len" ] && [ "${s:$j:1}" != "m" ]; do j=$(( j + 1 )); done
      out="${out}${s:$i:$(( j - i + 1 ))}"
      i=$(( j + 1 ))
      continue
    fi
    [ "$vis" -ge $(( n - 1 )) ] && break
    out="${out}${ch}"
    vis=$(( vis + 1 ))
    i=$(( i + 1 ))
  done
  printf '%s…%s' "$out" "$BOLD_OFF"
}

# shorten plain (un-colored) text to n columns, with an ellipsis
trunc() {
  local t="$1" n="$2"
  [ "$n" -le 0 ] && return
  [ "${#t}" -le "$n" ] && { printf '%s' "$t"; return; }
  [ "$n" -le 1 ] && { printf '%s' "${t:0:$n}"; return; }
  printf '%s…' "${t:0:$(( n - 1 ))}"
}

# compact token count: 84523 -> "85k", 1234567 -> "1.2M"
fmt_tokens() {
  local n="$1"
  [ -z "$n" ] && return
  awk -v n="$n" 'BEGIN{
    if (n >= 1000000) printf "%.1fM", n/1000000;
    else if (n >= 1000) printf "%.0fk", n/1000;
    else printf "%d", n;
  }'
}

# --- system stats: Linux (/proc) and macOS (top/vm_stat/sysctl) ----------
cpu_usage() {
  if [ "$OS" = "Darwin" ]; then
    command -v top >/dev/null 2>&1 || return
    top -l 1 -n 0 2>/dev/null | awk -F'[:,]' '
      /CPU usage/ {
        for (i=1;i<=NF;i++) {
          if ($i ~ /idle/) { gsub(/[^0-9.]/,"",$i); printf "%.0f", 100 - $i }
        }
      }'
    return
  fi

  [ -r /proc/stat ] || return
  local now_total now_idle prev_total prev_idle delta_total delta_idle
  read -r now_total now_idle < <(
    awk '/^cpu /{ idle=$5+$6; total=0; for(i=2;i<=NF;i++) total+=$i; print total, idle }' /proc/stat
  )

  if [ -f "$CPU_CACHE" ]; then
    read -r prev_total prev_idle < "$CPU_CACHE"
  else
    # no history yet: take a fast double-sample so this render isn't blank
    sleep 0.15
    prev_total=$now_total; prev_idle=$now_idle
    read -r now_total now_idle < <(
      awk '/^cpu /{ idle=$5+$6; total=0; for(i=2;i<=NF;i++) total+=$i; print total, idle }' /proc/stat
    )
  fi
  printf '%s %s\n' "$now_total" "$now_idle" > "$CPU_CACHE" 2>/dev/null

  delta_total=$(( now_total - prev_total ))
  delta_idle=$(( now_idle - prev_idle ))
  [ "$delta_total" -le 0 ] && return
  awk -v dt="$delta_total" -v di="$delta_idle" 'BEGIN{ printf "%.0f", (1 - di/dt) * 100 }'
}

ram_usage() {
  if [ "$OS" = "Darwin" ]; then
    command -v vm_stat >/dev/null 2>&1 || return
    local page_size total_bytes
    page_size=$(vm_stat | awk '/page size of/{print $8}')
    [ -z "$page_size" ] && page_size=4096
    total_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    [ -z "$total_bytes" ] && return
    vm_stat | awk -v ps="$page_size" -v total="$total_bytes" '
      /Pages active/     { active=$3 }
      /Pages wired down/ { wired=$4 }
      /Pages occupied by compressor/ { comp=$5 }
      END {
        gsub(/\./,"",active); gsub(/\./,"",wired); gsub(/\./,"",comp);
        used = (active+wired+comp) * ps;
        if (total > 0) printf "%.0f", used/total*100;
      }'
    return
  fi

  [ -r /proc/meminfo ] || return
  awk '
    /^MemTotal:/     { total = $2 }
    /^MemAvailable:/ { avail = $2 }
    END { if (total > 0) printf "%.0f", (1 - avail/total) * 100 }
  ' /proc/meminfo
}

# --- indicators: one function per config keyword -------------------------
ind_model() {
  printf '%s%s%s' "$MODEL_TAG" "$(jqr '.model.display_name // "Claude"')" "$BOLD_OFF"
}

ind_dir() {
  basename "$(jqr '.workspace.current_dir // .cwd // "."')"
}

ind_branch() {
  command -v git >/dev/null 2>&1 || return
  local d b
  d=$(jqr '.workspace.current_dir // .cwd // "."')
  b=$(git -C "$d" branch --show-current 2>/dev/null)
  [ -z "$b" ] && return
  [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ] && b="${b}*"
  printf '%s %s' "$BRANCH_ICON" "$b"
}

ind_context() {
  local pct used size out toks
  pct=$(jqr '.context_window.used_percentage // empty')
  used=$(jqr '.context_window.total_input_tokens // empty')
  size=$(jqr '.context_window.context_window_size // empty')
  out="${CLAUDE_TAG}Ctx${FG_RESET} $(fmt_pct "$pct")"
  if [ -n "$used" ] && [ -n "$size" ]; then
    toks="$(fmt_tokens "$used")/$(fmt_tokens "$size")"
    out="${out}${DIM} (${toks})${DIM_OFF}"
  fi
  printf '%s' "$out"
}

ind_five_hour() {
  local pct reset out r
  pct=$(jqr '.rate_limits.five_hour.used_percentage // empty')
  reset=$(jqr '.rate_limits.five_hour.resets_at // empty')
  out="${CLAUDE_TAG}5h${FG_RESET} $(fmt_pct "$pct")"
  r=$(reset_str "$reset")
  [ -n "$r" ] && out="${out}${DIM} (reset ${r})${DIM_OFF}"
  printf '%s' "$out"
}

ind_week() {
  local pct reset out r
  pct=$(jqr '.rate_limits.seven_day.used_percentage // empty')
  reset=$(jqr '.rate_limits.seven_day.resets_at // empty')
  out="${CLAUDE_TAG}Week${FG_RESET} $(fmt_pct "$pct")"
  r=$(reset_str "$reset")
  [ -n "$r" ] && out="${out}${DIM} (reset ${r})${DIM_OFF}"
  printf '%s' "$out"
}

ind_cpu() { printf '%sCPU%s %s' "$SYSTEM_TAG" "$FG_RESET" "$(fmt_pct "$(cpu_usage)")"; }
ind_ram() { printf '%sRAM%s %s' "$SYSTEM_TAG" "$FG_RESET" "$(fmt_pct "$(ram_usage)")"; }

# one color per effort level, "faster" (low) to "smarter" (max) — a
# 5-step scale, not the 3-step green/yellow/red severity one, since this
# is a setting, not a percentage.
effort_tag() {
  local code
  case "$1" in
    low)    code="$EFFORT_LOW_CODE" ;;
    medium) code="$EFFORT_MEDIUM_CODE" ;;
    high)   code="$EFFORT_HIGH_CODE" ;;
    xhigh)  code="$EFFORT_XHIGH_CODE" ;;
    max)    code="$EFFORT_MAX_CODE" ;;
    *)      code="$SEP_CODE" ;;
  esac
  printf '\033[1;38;5;%sm' "$code"
}

ind_effort() {
  local level
  level=$(jqr '.effort.level // empty')
  [ -z "$level" ] && return
  printf '%s%s%s' "$(effort_tag "$level")" "$level" "$BOLD_OFF"
}

# which color group an indicator belongs to, for the label tint above and
# the leading-separator tint below: "claude" usage, "system" usage, or
# neutral "id" (model/dir/branch — identity, not a usage metric)
category_of() {
  case "$1" in
    context|five_hour|week|effort) printf 'claude' ;;
    cpu|ram)                       printf 'sys' ;;
    *)                             printf 'id' ;;
  esac
}

# --- expandable panels ---------------------------------------------------
# Extra rows of detail drawn under the band when ~/.claude/.statusline-panel
# asks for one. These are read-only: no script can change the model, effort
# or permission mode of a running session, so the session panel reports
# state and lists the keys that do perform the switch.
#
# BOXW/IW are set from the terminal width just before these run.

# Every field the panels need, in one jq pass. Individually these would be
# a dozen more forks per render, on top of the ind_* calls.
panel_load() {
  panel_data=()
  local pd_line
  while IFS= read -r pd_line; do
    panel_data+=("$pd_line")
  done < <(jqr '[
      (.context_window.total_input_tokens // 0),
      (.context_window.context_window_size // 0),
      (.context_window.used_percentage // ""),
      (.context_window.current_usage.input_tokens // ""),
      (.context_window.current_usage.output_tokens // ""),
      (.context_window.current_usage.cache_creation_input_tokens // ""),
      (.context_window.current_usage.cache_read_input_tokens // ""),
      (.model.display_name // "Claude"),
      (.effort.level // ""),
      (if .thinking.enabled then "on" else "off" end),
      (if .fast_mode then "on" else "off" end),
      (.cost.total_cost_usd // 0),
      (.cost.total_duration_ms // 0),
      (.cost.total_lines_added // 0),
      (.cost.total_lines_removed // 0)
    ] | .[] | tostring')
  P_USED="${panel_data[0]:-0}"
  P_SIZE="${panel_data[1]:-0}"
  P_PCT="${panel_data[2]:-}"
  P_IN="${panel_data[3]:-}"
  P_OUT="${panel_data[4]:-}"
  P_CWRITE="${panel_data[5]:-}"
  P_CREAD="${panel_data[6]:-}"
  P_MODEL="${panel_data[7]:-Claude}"
  P_EFFORT="${panel_data[8]:-}"
  P_THINK="${panel_data[9]:-off}"
  P_FAST="${panel_data[10]:-off}"
  P_COST="${panel_data[11]:-0}"
  P_DUR="${panel_data[12]:-0}"
  P_ADD="${panel_data[13]:-0}"
  P_DEL="${panel_data[14]:-0}"
  # The band's fmt_tokens rounds to whole units, which is right when space
  # is tight but loses too much here (8500 reading as "8k"). One awk pass
  # for both totals; the per-category rows format themselves.
  local both
  both=$(awk -v u="$P_USED" -v s="$P_SIZE" '
    function f(n) {
      if (n >= 1000000) return sprintf("%.1fM", n/1000000);
      if (n >= 1000)    return sprintf("%.1fk", n/1000);
      return sprintf("%d", n);
    }
    BEGIN { printf "%s\t%s", f(u), f(s) }')
  P_USED_F="${both%%	*}"
  P_SIZE_F="${both##*	}"
}

box_top() {
  local title="$1" fill
  # " ╭─ " + title + " " + fill + "╮" has to come to BOXW + 1 columns
  fill=$(( BOXW - 5 - ${#title} ))
  [ "$fill" -lt 0 ] && fill=0
  printf ' %s╭─ %s%s %s%s╮%s' \
    "$PANEL_BORDER" "$FG_RESET" "$title" "$PANEL_BORDER" "$(rep "$fill" '─')" "$FG_RESET"
}

box_bottom() {
  printf ' %s╰%s╯%s' "$PANEL_BORDER" "$(rep $(( BOXW - 2 )) '─')" "$FG_RESET"
}

# Every panel row goes through here, so forcing the content to exactly IW
# columns at this one point is what keeps the right-hand border aligned no
# matter how long a model name or shortcut hint turns out to be.
box_row() {
  printf ' %s│%s %s %s│%s' \
    "$PANEL_BORDER" "$FG_RESET" "$(fit_vis "$1" "$IW")" "$PANEL_BORDER" "$FG_RESET"
}

box_rule() {
  box_row "$PANEL_BORDER$(rep "$IW" '─')$FG_RESET"
}

# ms -> "42m" / "1h22m" / "3d4h"
fmt_dur() {
  local s=$(( ${1%.*} / 1000 )) h m d
  h=$(( s / 3600 )); m=$(( (s % 3600) / 60 ))
  if [ "$h" -ge 24 ]; then
    d=$(( h / 24 )); printf '%dd%dh' "$d" "$(( h % 24 ))"
  elif [ "$h" -gt 0 ]; then
    printf '%dh%02dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
}

# Permission mode, from the cache the companion hook writes. Claude Code
# never sends it to the status line, so without that hook there is nothing
# to report. It refreshes on tool use, so it can trail a Shift+Tab briefly;
# a "~" suffix marks a value old enough to distrust.
mode_str() {
  [ -r "$MODE_CACHE" ] || { printf -- '--'; return; }
  local m="" mtime now
  IFS= read -r m < "$MODE_CACHE" 2>/dev/null
  [ -z "$m" ] && { printf -- '--'; return; }
  if [ "$OS" = "Darwin" ]; then
    mtime=$(stat -f %m "$MODE_CACHE" 2>/dev/null)
  else
    mtime=$(stat -c %Y "$MODE_CACHE" 2>/dev/null)
  fi
  now=$(date +%s)
  if [ -n "$mtime" ] && [ $(( now - mtime )) -gt 300 ]; then
    printf '%s~' "$m"
  else
    printf '%s' "$m"
  fi
}

# Split the stacked bar into per-category cell counts that always sum to
# exactly the bar width, giving any non-zero category at least one cell so
# a small-but-real slice never vanishes.
bar_cells() {
  awk -v a="$1" -v b="$2" -v c="$3" -v d="$4" -v total="$5" -v w="$6" 'BEGIN{
    if (total <= 0 || w <= 0) { printf "0 0 0 0 %d", (w > 0 ? w : 0); exit }
    v[1]=a; v[2]=b; v[3]=c; v[4]=d;
    sum=0;
    for (i=1; i<=4; i++) {
      cells[i] = int(v[i]/total*w + 0.5);
      if (v[i] > 0 && cells[i] < 1) cells[i] = 1;
      sum += cells[i];
    }
    while (sum > w) {                 # never overflow the bar
      mx=1; for (i=2; i<=4; i++) if (cells[i] > cells[mx]) mx=i;
      if (cells[mx] <= 0) break;
      cells[mx]--; sum--;
    }
    printf "%d %d %d %d %d", cells[1], cells[2], cells[3], cells[4], w - sum;
  }'
}

# "8.5k" plus its share of the window, right-aligned into fixed columns.
# Token count and percentage come from one awk call, not two: this runs
# once per category row, on every render.
cat_row() {
  local color="$1" label="$2" val="$3" swatch="$4"
  local both toks pct lw
  both=$(awk -v v="$val" -v t="$P_SIZE" 'BEGIN{
    if (v >= 1000000)  printf "%.1fM", v/1000000;
    else if (v >= 1000) printf "%.1fk", v/1000;
    else                printf "%d", v;
    printf "\t";
    if (t <= 0) { printf "--"; }
    else {
      p = v/t*100;
      if (p > 0 && p < 0.1) printf "<0.1%%"; else printf "%.1f%%", p;
    }
  }')
  toks="${both%%	*}"
  pct="${both##*	}"
  lw=$(( IW - 4 - 9 - 8 ))
  [ "$lw" -lt 1 ] && lw=1
  printf '%s%s%s %s%s%s%9s%8s' \
    "  " "$color" "$swatch" \
    "$PANEL_LABEL" "$(pad_vis "$(trunc "$label" "$lw")" "$lw")" "$FG_RESET" \
    "$toks" "$pct"
}

panel_context() {
  panel_load
  local head_l head_r free have_breakdown=1
  case "$P_IN$P_OUT$P_CWRITE$P_CREAD" in '') have_breakdown=0 ;; esac

  rows+=("$(box_top "Context")")

  # header: model and window size on the left, used/total and % on the right
  head_l="${MODEL_TAG}$(trunc "$P_MODEL" 30)${BOLD_OFF}${DIM} · ${P_SIZE_F} window${DIM_OFF}"
  if [ -n "$P_PCT" ]; then
    head_r="${P_USED_F} / ${P_SIZE_F}  $(fmt_pct "$P_PCT")"
  else
    head_r="${P_USED_F} / ${P_SIZE_F}  --"
  fi
  local lpad
  lpad=$(( IW - $(vislen "$head_l") - $(vislen "$head_r") ))
  [ "$lpad" -lt 1 ] && lpad=1
  rows+=("$(box_row "${head_l}$(rep "$lpad" ' ')${head_r}")")

  if [ "$have_breakdown" = "1" ]; then
    free=$(awk -v t="$P_SIZE" -v u="$P_USED" -v o="$P_OUT" 'BEGIN{ f=t-u-o; if (f<0) f=0; printf "%d", f }')
    local cells c1 c2 c3 c4 c5 bar
    cells=$(bar_cells "$P_IN" "$P_CREAD" "$P_CWRITE" "$P_OUT" "$P_SIZE" "$IW")
    read -r c1 c2 c3 c4 c5 <<EOF
$cells
EOF
    bar="${CAT_INPUT}$(rep "$c1" '█')${CAT_CACHE_READ}$(rep "$c2" '█')"
    bar="${bar}${CAT_CACHE_WRITE}$(rep "$c3" '█')${CAT_OUTPUT}$(rep "$c4" '█')"
    bar="${bar}${CAT_FREE}$(rep "$c5" '░')${FG_RESET}"
    rows+=("$(box_row "$bar")")
    rows+=("$(box_row "$(cat_row "$CAT_INPUT" "Fresh input" "$P_IN" '█')")")
    rows+=("$(box_row "$(cat_row "$CAT_CACHE_READ" "Cache read" "$P_CREAD" '█')")")
    rows+=("$(box_row "$(cat_row "$CAT_CACHE_WRITE" "Cache write" "$P_CWRITE" '█')")")
    rows+=("$(box_row "$(cat_row "$CAT_OUTPUT" "Output" "$P_OUT" '█')")")
    rows+=("$(box_row "$(cat_row "$CAT_FREE" "Free space" "$free" ' ')")")
  else
    # current_usage is null before the first API call, and again right
    # after /compact until the next one repopulates it
    rows+=("$(box_row "${CAT_FREE}$(rep "$IW" '░')${FG_RESET}")")
    rows+=("$(box_row "${DIM}breakdown available after the first message of the session${DIM_OFF}")")
  fi
  rows+=("$(box_bottom)")
}

# label/value cell: dim fixed-width label so values line up in a column
cell() {
  printf '%s%s%s%s' "$PANEL_LABEL" "$(pad_vis "$1" 9)" "$FG_RESET" "$2"
}

# Lay label/value pairs across one panel row as equal columns. The last
# column absorbs the division remainder, so a row always comes to exactly
# IW and the right border stays put.
grid_row() {
  local n=$(( $# / 2 )) i=0 out="" w cwidth
  [ "$n" -le 0 ] && return
  w=$(( IW / n ))
  while [ "$#" -gt 0 ]; do
    i=$(( i + 1 ))
    if [ "$i" -eq "$n" ]; then cwidth=$(( IW - (n - 1) * w )); else cwidth="$w"; fi
    out="${out}$(fit_vis "$(cell "$1" "$2")" "$cwidth")"
    shift 2
  done
  printf '%s' "$out"
}

panel_session() {
  panel_load
  local effort_val cost_val lines_val ncols cw

  if [ -n "$P_EFFORT" ]; then
    effort_val="$(effort_tag "$P_EFFORT")${P_EFFORT}${BOLD_OFF}"
  else
    effort_val="--"
  fi
  cost_val=$(awk -v c="$P_COST" 'BEGIN{ printf "$%.2f", c }')
  lines_val="${GREEN}+${P_ADD}${FG_RESET}/${RED}-${P_DEL}${FG_RESET}"

  # A 9-column label plus a useful value needs roughly 22 columns. Below
  # that, three across would clip every value, so fall back to two.
  if [ $(( IW / 3 )) -ge 22 ]; then ncols=3; else ncols=2; fi
  cw=$(( IW / ncols ))

  rows+=("$(box_top "Session")")
  if [ "$ncols" -eq 3 ]; then
    rows+=("$(box_row "$(grid_row Model "${MODEL_TAG}$(trunc "$P_MODEL" $(( cw - 10 )))${BOLD_OFF}" Effort "$effort_val" Mode "$(mode_str)")")")
    rows+=("$(box_row "$(grid_row Thinking "$P_THINK" Fast "$P_FAST" Cost "$cost_val")")")
    rows+=("$(box_row "$(grid_row Time "$(fmt_dur "$P_DUR")" Lines "$lines_val" "" "")")")
  else
    rows+=("$(box_row "$(grid_row Model "${MODEL_TAG}$(trunc "$P_MODEL" $(( cw - 10 )))${BOLD_OFF}" Effort "$effort_val")")")
    rows+=("$(box_row "$(grid_row Mode "$(mode_str)" Thinking "$P_THINK")")")
    rows+=("$(box_row "$(grid_row Fast "$P_FAST" Cost "$cost_val")")")
    rows+=("$(box_row "$(grid_row Time "$(fmt_dur "$P_DUR")" Lines "$lines_val")")")
  fi
  rows+=("$(box_rule)")
  # Nothing above can perform a switch: no script, hook or setting can
  # change a running session's model, effort or mode. These keys can, and
  # they work mid-generation, so the panel points at them instead of
  # pretending to be a picker. Meta is Option on macOS, Alt elsewhere.
  local keys
  if [ "$IW" -ge 78 ]; then
    keys="$(cell switch "${DIM}Meta+P model + effort   Shift+Tab mode   Meta+T think   Meta+O fast${DIM_OFF}")"
  else
    keys="${DIM}Meta+P model  Shift+Tab mode  Meta+T/O think/fast${DIM_OFF}"
  fi
  rows+=("$(box_row "$keys")")
  rows+=("$(box_bottom)")
}

# --- build the line from the config's indicator list ---------------------
PANEL_MODE=$(panel_current)
segments=()
cats=()
tights=()   # "1" -> glue to the previous segment with just a space, no ┃
prev_name=""
while IFS= read -r name; do
  case "$name" in
    ''|'#'*|*=*) continue ;;
  esac
  case "$name" in
    model)     out=$(ind_model) ;;
    dir)       out=$(ind_dir) ;;
    branch)    out=$(ind_branch) ;;
    context)   out=$(ind_context) ;;
    five_hour) out=$(ind_five_hour) ;;
    week)      out=$(ind_week) ;;
    effort)    out=$(ind_effort) ;;
    cpu)       out=$(ind_cpu) ;;
    ram)       out=$(ind_ram) ;;
    *) printf 'statusline: unknown indicator "%s" in %s\n' "$name" "$CONFIG" >&2; continue ;;
  esac
  if [ -n "$out" ]; then
    segments+=("$out")
    cats+=("$(category_of "$name")")
    # "effort" right after "model" reads as its subtitle, not a separate
    # metric — glue it on instead of putting the graphic separator between
    if [ "$name" = "effort" ] && [ "$prev_name" = "model" ]; then
      tights+=("1")
    else
      tights+=("0")
    fi
    prev_name="$name"
  fi
done < "$CONFIG"

# Merge tight pairs (model+effort) into single display units first, so
# wrapping below can never split them onto different lines.
units=()
unit_cats=()
for i in "${!segments[@]}"; do
  if [ "$i" -gt 0 ] && [ "${tights[$i]}" = "1" ]; then
    last=$(( ${#units[@]} - 1 ))
    units[$last]="${units[$last]} ${segments[$i]}"
  else
    units+=("${segments[$i]}")
    unit_cats+=("${cats[$i]}")
  fi
done

# Lay units out left to right; when the next one wouldn't fit in the
# terminal's width anymore, start a new row instead of overflowing —
# each row gets its own full-width band, so the whole thing re-flows as
# the window is resized instead of getting cut off mid-indicator.
width=$(term_width)
rows=()
current=""
for i in "${!units[@]}"; do
  seg="${units[$i]}"
  if [ -z "$current" ]; then
    piece=" ${seg}"
  else
    case "${unit_cats[$i]}" in
      claude) sc="$CLAUDE_TAG" ;;
      sys)    sc="$SYSTEM_TAG" ;;
      *)      sc="$SEP_COLOR" ;;
    esac
    piece=" ${sc}${SEP_CHAR}${FG_RESET} ${seg}"
  fi
  piece_vis=$(strip_ansi "$piece")
  piece_len=${#piece_vis}
  cur_len=0
  if [ -n "$current" ]; then
    cur_vis=$(strip_ansi "$current")
    cur_len=${#cur_vis}
  fi

  if [ -n "$current" ] && [ $(( cur_len + piece_len )) -gt "$width" ]; then
    rows+=("$current")
    current=" ${seg}"
  else
    current="${current}${piece}"
  fi
done
[ -n "$current" ] && rows+=("$current")

# Expanded panel, if any, appended as further rows before the padding pass
# below, so it picks up the same background and full-width padding as the
# band. Panels are wide by nature; on a narrow terminal the box would wrap
# and shred the layout, so say so instead of drawing it.
if [ "$PANEL_MODE" != "off" ]; then
  if [ "$width" -lt 60 ]; then
    rows+=(" ${DIM}panel: needs a terminal at least 60 columns wide${DIM_OFF}")
  else
    BOXW=$(( width - 2 ))
    IW=$(( BOXW - 4 ))
    case "$PANEL_MODE" in
      context) panel_context ;;
      session) panel_session ;;
    esac
  fi
fi

output=""
for i in "${!rows[@]}"; do
  vis=$(strip_ansi "${rows[$i]}")
  pad=$(( width - ${#vis} ))
  [ "$pad" -lt 0 ] && pad=0
  padding=$(printf '%*s' "$pad" '')
  row_out="${BG}${rows[$i]}${padding}${FULL_RESET}"
  if [ -z "$output" ]; then
    output="$row_out"
  else
    output="${output}"$'\n'"${row_out}"
  fi
done

printf '%s' "$output"
