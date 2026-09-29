#!/bin/bash
# Claude Code status line: bold, icon-prefixed, color-coded segments.
# Built from scratch (no PS1/Starship source) per explicit request.
#
# NOTE: the final output is emitted via `printf "%b" "$line"`. Every
# color code below is embedded as literal \033 text inside a `printf`
# format string (never a shell $'...' ANSI-C string), so each inner
# `printf` call resolves it to a real ESC byte before we ever get to
# the closing `printf "%b"` — that call just passes the already-resolved
# bytes through.

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
effort=$(echo "$input" | jq -r '.effort.level // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
rl_five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl_five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
rl_week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
rl_week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# --- record usage readings for Cooperage (github.com/oak-wildwood/cooperage) ---
# Claude Code only exposes subscription usage here, and only while a session is
# open, and often not at all (anthropics/claude-code#95918). So every non-empty
# reading is appended to a JSONL file for Cooperage to collect as an Official
# Reading. A reading identical to the last one is skipped to keep the file small.
# Any failure is swallowed: the status line must never break over this.
record_reading() {
  local dir="${XDG_DATA_HOME:-$HOME/.local/share}/cooperage"
  local key="$rl_five|$rl_five_reset|$rl_week|$rl_week_reset"
  mkdir -p "$dir" || return
  [ "$(cat "$dir/.last-reading" 2>/dev/null)" = "$key" ] && return
  jq -cn --argjson at "$(date +%s)" \
    --arg f "$rl_five" --arg fr "$rl_five_reset" \
    --arg w "$rl_week" --arg wr "$rl_week_reset" '
    def num: if . == "" or . == "null" then null else tonumber end;
    {at: $at,
     five_hour: {used_percentage: ($f | num), resets_at: ($fr | num)},
     seven_day: {used_percentage: ($w | num), resets_at: ($wr | num)}}' \
    >> "$dir/official-readings.jsonl" || return
  printf '%s' "$key" > "$dir/.last-reading"
}
if { [ -n "$rl_five" ] && [ "$rl_five" != "null" ]; } || { [ -n "$rl_week" ] && [ "$rl_week" != "null" ]; }; then
  record_reading 2>/dev/null
fi

RESET="\033[0m"
DIM="\033[2m"
BOLD_MAGENTA="\033[1;35m"
BOLD_CYAN="\033[1;36m"
BOLD_GREEN="\033[1;32m"
BOLD_YELLOW="\033[1;33m"
BOLD_RED="\033[1;31m"
BOLD_BLUE="\033[1;34m"

SEP=$(printf "${DIM} │ ${RESET}")

# --- moon-phase glyph + %, number color-coded green(<50) / yellow(50-79) / red(>=80) ---
# Emoji can't take ANSI color, so the color signal lives on the number.
make_bar() {
  local pct="$1"
  local rounded moon color
  rounded=$(printf '%.0f' "$pct")
  if   [ "$rounded" -ge 88 ]; then moon="🌕"
  elif [ "$rounded" -ge 63 ]; then moon="🌔"
  elif [ "$rounded" -ge 38 ]; then moon="🌓"
  elif [ "$rounded" -ge 13 ]; then moon="🌒"
  else moon="🌑"
  fi
  if [ "$rounded" -ge 80 ]; then
    color="$BOLD_RED"
  elif [ "$rounded" -ge 50 ]; then
    color="$BOLD_YELLOW"
  else
    color="$BOLD_GREEN"
  fi
  printf "%s ${color}%d%%${RESET}" "$moon" "$rounded"
}

# --- model (bold magenta, ✦) + effort level in dim parens, omitted when the model has none ---
model_segment=$(printf "${BOLD_MAGENTA}✦ %s${RESET}" "$model")
[ -n "$effort" ] && model_segment="${model_segment}$(printf " ${DIM}(%s)${RESET}" "$effort")"

# --- directory (bold cyan, ⌂): ~ for home, otherwise basename ---
if [ "$cwd" = "$HOME" ]; then
  dir_display="~"
else
  dir_display=$(basename "$cwd")
fi
dir_segment=$(printf "${BOLD_CYAN}⌂ %s${RESET}" "$dir_display")

# --- git branch (bold yellow, ⎇) + dirty indicator (bold red ●) ---
branch_segment=""
if git --no-optional-locks -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    dirty=""
    porcelain=$(git --no-optional-locks -C "$cwd" status --porcelain 2>/dev/null)
    [ -n "$porcelain" ] && dirty=$(printf "${BOLD_RED} ●${RESET}")
    branch_segment=$(printf " ${BOLD_YELLOW}⎇ %s${RESET}%s" "$branch" "$dirty")
  fi
fi

# --- context usage bar ---
context_segment=""
if [ -n "$used" ] && [ "$used" != "null" ]; then
  context_segment=$(printf "${DIM}ctx${RESET} %s" "$(make_bar "$used")")
fi

# --- session cost (bold blue, $X.XX) ---
cost_segment=""
if [ -n "$cost" ] && [ "$cost" != "null" ]; then
  cost_segment=$(printf "${BOLD_BLUE}\$%.2f${RESET}" "$cost")
fi

# --- rate limits: 5h + 7d bars, each silently omitted when absent ---
rl5_segment=""
if [ -n "$rl_five" ] && [ "$rl_five" != "null" ]; then
  reset_str=""
  if [ -n "$rl_five_reset" ] && [ "$rl_five_reset" != "null" ]; then
    reset_time=$(date -r "$rl_five_reset" +%H:%M 2>/dev/null)
    [ -n "$reset_time" ] && reset_str=$(printf " ${DIM}↻%s${RESET}" "$reset_time")
  fi
  rl5_segment=$(printf "${DIM}5h${RESET} %s%s" "$(make_bar "$rl_five")" "$reset_str")
fi

rl7_segment=""
if [ -n "$rl_week" ] && [ "$rl_week" != "null" ]; then
  rl7_segment=$(printf "${DIM}7d${RESET} %s" "$(make_bar "$rl_week")")
fi

# --- clock: current local time, far-right segment ---
clock_segment=$(printf "${DIM}⏱ %s${RESET}" "$(date +%H:%M)")

# --- assemble, responsive to terminal width ---
# Claude Code sets COLUMNS before running this script (tput cols can't see the
# terminal here). It only re-runs on events, so a resize shows up at the next one.
#   wide   (>= WIDE_COLS): 2 lines
#     model | dir branch | cost | clock
#     ctx | 5h | 7d
#   narrow (<  WIDE_COLS): 3 lines
#     model | dir branch | cost | clock
#     ctx
#     5h | 7d
WIDE_COLS=80

# Join the non-empty arguments with the separator.
join_segments() {
  local out="" seg
  for seg in "$@"; do
    [ -z "$seg" ] && continue
    out="${out:+${out}${SEP}}${seg}"
  done
  printf '%s' "$out"
}

line1=$(join_segments "$model_segment" "${dir_segment}${branch_segment}" "$cost_segment" "$clock_segment")

if [ "${COLUMNS:-$WIDE_COLS}" -ge "$WIDE_COLS" ]; then
  line2=$(join_segments "$context_segment" "$rl5_segment" "$rl7_segment")
  line3=""
else
  line2="$context_segment"
  line3=$(join_segments "$rl5_segment" "$rl7_segment")
fi

output="$line1"
[ -n "$line2" ] && output="${output}\n${line2}"
[ -n "$line3" ] && output="${output}\n${line3}"

printf "%b" "$output"
