#!/bin/bash
# Captures Claude Code's statusline JSON payload (which includes
# rate_limits.five_hour / seven_day from the API) so ClaudeBar.app
# can read plan-quota usage without scraping ccusage.
#
# Renders a compact, colored statusline:
#   <model> | <cwd> <branch>[●] | 5h [▰▰▱▱▱▱▱▱] 25% | 7d [▰▱▱▱▱▱▱▱] 12%

set -u

OUT="$HOME/.claude/last-status.json"
TMP="$OUT.tmp.$$"

INPUT="$(cat)"
printf '%s' "$INPUT" > "$TMP" && mv -f "$TMP" "$OUT"

# Colors
PURPLE=$'\033[38;5;141m'
ORANGE=$'\033[38;5;208m'
GREEN=$'\033[38;5;114m'
YELLOW=$'\033[38;5;221m'
RED=$'\033[38;5;203m'
CYAN=$'\033[38;5;81m'
GREY=$'\033[38;5;245m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET=$'\033[0m'
SEP="${GREY}│${RESET}"

JQ=/usr/bin/env

read_json() { /usr/bin/env jq -r "$1 // \"\"" 2>/dev/null <<<"$INPUT"; }

MODEL="$(read_json '.model.display_name')"
CWD="$(read_json '.workspace.current_dir')"
[ -z "$CWD" ] && CWD="$(read_json '.cwd')"
[ -z "$CWD" ] && CWD="$PWD"
OUTPUT_STYLE="$(read_json '.output_style.name')"

DISPLAY_DIR="${CWD/#$HOME/~}"

BRANCH=""
DIRTY=""
if git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH="$(git -C "$CWD" symbolic-ref --short HEAD 2>/dev/null \
            || git -C "$CWD" rev-parse --short HEAD 2>/dev/null)"
  if [ -n "$(git -C "$CWD" status --porcelain 2>/dev/null)" ]; then
    DIRTY="●"
  fi
fi

# Progress bar: 10 segments, color by threshold
make_bar() {
  local pct="$1"
  [ -z "$pct" ] && { printf ''; return; }
  local segs=10
  local filled=$(( (pct * segs + 50) / 100 ))
  [ "$filled" -gt "$segs" ] && filled=$segs
  [ "$filled" -lt 0 ] && filled=0
  local color="$GREEN"
  [ "$pct" -ge 50 ] && color="$YELLOW"
  [ "$pct" -ge 80 ] && color="$RED"
  local bar=""
  local i=0
  while [ "$i" -lt "$segs" ]; do
    if [ "$i" -lt "$filled" ]; then
      bar="${bar}▰"
    else
      bar="${bar}▱"
    fi
    i=$((i+1))
  done
  printf '%s%s%s' "$color" "$bar" "$RESET"
}

FIVE_PCT="$(/usr/bin/env jq -r '.rate_limits.five_hour.used_percentage // empty | floor' 2>/dev/null <<<"$INPUT")"
SEVEN_PCT="$(/usr/bin/env jq -r '.rate_limits.seven_day.used_percentage // empty | floor' 2>/dev/null <<<"$INPUT")"

# Build line
PARTS=()

[ -n "$MODEL" ] && PARTS+=("${PURPLE}${BOLD}${MODEL}${RESET}")

LOC="${GREEN}${DISPLAY_DIR}${RESET}"
if [ -n "$BRANCH" ]; then
  LOC="${LOC} ${CYAN}${BRANCH}${RESET}"
  [ -n "$DIRTY" ] && LOC="${LOC}${ORANGE}${DIRTY}${RESET}"
fi
PARTS+=("$LOC")

if [ -n "$FIVE_PCT" ]; then
  PARTS+=("${DIM}5h${RESET} $(make_bar "$FIVE_PCT") ${GREY}${FIVE_PCT}%${RESET}")
fi
if [ -n "$SEVEN_PCT" ]; then
  PARTS+=("${DIM}7d${RESET} $(make_bar "$SEVEN_PCT") ${GREY}${SEVEN_PCT}%${RESET}")
fi

if [ -n "$OUTPUT_STYLE" ] && [ "$OUTPUT_STYLE" != "default" ]; then
  PARTS+=("${DIM}${OUTPUT_STYLE}${RESET}")
fi

# Join with separator
LINE=""
for i in "${!PARTS[@]}"; do
  if [ "$i" -eq 0 ]; then
    LINE="${PARTS[$i]}"
  else
    LINE="${LINE} ${SEP} ${PARTS[$i]}"
  fi
done

printf '%s' "$LINE"
