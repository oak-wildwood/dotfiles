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
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
rl_five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl_five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
rl_week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

RESET="\033[0m"
DIM="\033[2m"
BOLD_MAGENTA="\033[1;35m"
BOLD_CYAN="\033[1;36m"
BOLD_GREEN="\033[1;32m"
BOLD_YELLOW="\033[1;33m"
BOLD_RED="\033[1;31m"
BOLD_BLUE="\033[1;34m"

SEP=$(printf "${DIM} │ ${RESET}")

# --- 10-char block bar + %, color-coded green(<50) / yellow(50-79) / red(>=80) ---
make_bar() {
  local pct="$1"
  local rounded filled empty bar_filled bar_empty color
  rounded=$(printf '%.0f' "$pct")
  filled=$(( (rounded + 5) / 10 ))
  [ "$filled" -gt 10 ] && filled=10
  [ "$filled" -lt 0 ] && filled=0
  empty=$((10 - filled))
  bar_filled=""
  [ "$filled" -gt 0 ] && bar_filled=$(printf '%0.s█' $(seq 1 "$filled"))
  bar_empty=""
  [ "$empty" -gt 0 ] && bar_empty=$(printf '%0.s░' $(seq 1 "$empty"))
  if [ "$rounded" -ge 80 ]; then
    color="$BOLD_RED"
  elif [ "$rounded" -ge 50 ]; then
    color="$BOLD_YELLOW"
  else
    color="$BOLD_GREEN"
  fi
  printf "${color}%s%s %d%%${RESET}" "$bar_filled" "$bar_empty" "$rounded"
}

# --- model (bold magenta, ✦) ---
model_segment=$(printf "${BOLD_MAGENTA}✦ %s${RESET}" "$model")

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

# --- assemble: model | dir branch | ctx | cost | 5h | 7d | clock ---
line="$model_segment"
line="${line}${SEP}${dir_segment}${branch_segment}"
[ -n "$context_segment" ] && line="${line}${SEP}${context_segment}"
[ -n "$cost_segment" ] && line="${line}${SEP}${cost_segment}"
[ -n "$rl5_segment" ] && line="${line}${SEP}${rl5_segment}"
[ -n "$rl7_segment" ] && line="${line}${SEP}${rl7_segment}"
line="${line}${SEP}${clock_segment}"

printf "%b" "$line"
