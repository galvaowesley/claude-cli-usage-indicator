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

input=$(cat)

JQ=$(command -v jq)
if [ -z "$JQ" ] || [ ! -x "$JQ" ]; then
  printf "statusline: jq not found — install it (see README) and reopen Claude Code"
  exit 0
fi
jqr() { printf '%s' "$input" | "$JQ" -r "$1"; }

OS=$(uname -s)

CONFIG="$HOME/.claude/statusline.conf"
CPU_CACHE="$HOME/.claude/.statusline-cpu-cache"

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
#   branch_icon=       glyph before the git branch name (needs a Nerd Font: https://nerdfonts.com — falls back to a blank/box glyph without one)
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
branch_icon=
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
BRANCH_ICON=""
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

# terminal width, best effort: real tty -> tput -> $COLUMNS -> fallback
term_width() {
  local w=""
  w=$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')
  [ -z "$w" ] && w=$(tput cols 2>/dev/null)
  [ -z "$w" ] && w="$COLUMNS"
  [ -z "$w" ] && w=80
  printf '%s' "$w"
}

strip_ansi() {
  printf '%s' "$1" | sed -E 's/\x1b\[[0-9;]*m//g'
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
  r=$(fmt_reset "$reset")
  [ -n "$r" ] && out="${out}${DIM} (reset ${r})${DIM_OFF}"
  printf '%s' "$out"
}

ind_week() {
  local pct reset out r
  pct=$(jqr '.rate_limits.seven_day.used_percentage // empty')
  reset=$(jqr '.rate_limits.seven_day.resets_at // empty')
  out="${CLAUDE_TAG}Week${FG_RESET} $(fmt_pct "$pct")"
  r=$(fmt_reset "$reset")
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

# --- build the line from the config's indicator list ---------------------
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
