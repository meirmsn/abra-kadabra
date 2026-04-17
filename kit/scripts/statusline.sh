#!/bin/sh
# Claude Code status line — 2-line display
# Line 1: @user ➜ cwd (branch) | model [ctx-bar] used%
# Line 2: 5h: XX% (time ↻ remaining) | 7d: XX% (day ↻ remaining)

input=$(cat)

# --- user / cwd ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$cwd" ] && cwd=$(pwd)

trimmed=$(echo "$cwd" | awk -F/ '{
  n=NF; start=n-3; if(start<1) start=1;
  out=""; for(i=start;i<=n;i++){out=out"/"$i}; print out
}' | sed 's|^/||')
[ -z "$trimmed" ] && trimmed="/"

# --- git branch ---
branch=$(git --no-optional-locks -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
  || git --no-optional-locks -C "$cwd" rev-parse --short HEAD 2>/dev/null)

# --- model ---
model=$(echo "$input" | jq -r '.model.display_name // empty')

# --- context used ---
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# --- rate limits ---
rl5_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl5_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
rl7_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
rl7_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# --- colors ---
GREEN='\033[0;32m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
RED='\033[1;31m'
ORANGE='\033[38;5;208m'
RESET='\033[0m'


# Build context bar: [████░░░░] XX%
context_bar() {
  pct="$1"
  if [ -z "$pct" ]; then
    printf '[░░░░░░░░] -%%'
    return
  fi
  rounded=$(printf '%.0f' "$pct")
  filled=$(( rounded / 12 ))  # 8 slots, each ~12.5%
  [ "$filled" -gt 8 ] && filled=8
  empty=$(( 8 - filled ))
  bar=""
  i=0; while [ "$i" -lt "$filled" ]; do bar="${bar}█"; i=$((i+1)); done
  i=0; while [ "$i" -lt "$empty" ]; do bar="${bar}░"; i=$((i+1)); done
  printf '[%s] %s%%' "$bar" "$rounded"
}

# Format reset time
# 5h window: "2:30pm ↻ 1h20m" — always show minutes if non-zero
# 7d window: "Thu ↻ 2d6h" — show hours if non-zero; under 6h show minutes like "5h45m"
format_reset() {
  iso="$1"
  window="$2"  # "5h" or "7d"
  if [ -z "$iso" ]; then
    printf '?'
    return
  fi
  now_epoch=$(date +%s)
  # resets_at can be epoch seconds or ISO string
  case "$iso" in
    *[!0-9]*) reset_epoch=$(date -d "$iso" +%s 2>/dev/null) ;;
    *)        reset_epoch="$iso" ;;
  esac
  if [ -z "$reset_epoch" ]; then
    printf '?'
    return
  fi
  diff_sec=$(( reset_epoch - now_epoch ))
  [ "$diff_sec" -lt 0 ] && diff_sec=0

  if [ "$window" = "5h" ]; then
    time_str=$(date -d "@$reset_epoch" +'%-I:%M%P' 2>/dev/null)
    diff_h=$(( diff_sec / 3600 ))
    diff_m=$(( (diff_sec % 3600) / 60 ))
    if [ "$diff_h" -gt 0 ] && [ "$diff_m" -gt 0 ]; then
      printf '%s ↻ %dh%dm' "$time_str" "$diff_h" "$diff_m"
    elif [ "$diff_h" -gt 0 ]; then
      printf '%s ↻ %dh' "$time_str" "$diff_h"
    else
      printf '%s ↻ %dm' "$time_str" "$diff_m"
    fi
  else
    diff_d=$(( diff_sec / 86400 ))
    diff_h=$(( (diff_sec % 86400) / 3600 ))
    diff_m=$(( (diff_sec % 3600) / 60 ))
    if [ "$diff_d" -ge 3 ]; then
      # Far out: just days with refresh icon
      printf '↻ %dd' "$diff_d"
    elif [ "$diff_d" -gt 0 ]; then
      # Under 3 days: show deadline + rounded-up days
      deadline=$(date -d "@$reset_epoch" +'%a@%-I:%M%P' 2>/dev/null)
      round_d=$diff_d
      [ "$diff_h" -gt 0 ] || [ "$diff_m" -gt 0 ] && round_d=$(( diff_d + 1 ))
      printf '%s ↻ %dd' "$deadline" "$round_d"
    elif [ "$diff_h" -ge 6 ]; then
      # Under 1 day, 6h+: show deadline + hours
      deadline=$(date -d "@$reset_epoch" +'%a@%-I:%M%P' 2>/dev/null)
      printf '%s ↻ %dh' "$deadline" "$diff_h"
    elif [ "$diff_h" -gt 0 ] && [ "$diff_m" -gt 0 ]; then
      # Under 6h: show deadline + hours+minutes
      deadline=$(date -d "@$reset_epoch" +'%a@%-I:%M%P' 2>/dev/null)
      printf '%s ↻ %dh%dm' "$deadline" "$diff_h" "$diff_m"
    elif [ "$diff_h" -gt 0 ]; then
      deadline=$(date -d "@$reset_epoch" +'%a@%-I:%M%P' 2>/dev/null)
      printf '%s ↻ %dh' "$deadline" "$diff_h"
    else
      deadline=$(date -d "@$reset_epoch" +'%a@%-I:%M%P' 2>/dev/null)
      printf '%s ↻ %dm' "$deadline" "$diff_m"
    fi
  fi
}

# Compute expected linear usage % and print: "5h" colored + "30%" plain + "(/63%)" colored
# Usage: rate_segment "5h" pct resets_at
rate_segment() {
  window="$1"
  pct="$2"
  iso="$3"
  label="$window"

  # No data — plain label + dashes
  if [ -z "$pct" ] || [ -z "$iso" ]; then
    printf '%s --%%' "$label"
    return
  fi

  now_epoch=$(date +%s)
  case "$iso" in
    *[!0-9]*) reset_epoch=$(date -d "$iso" +%s 2>/dev/null) ;;
    *)        reset_epoch="$iso" ;;
  esac
  if [ -z "$reset_epoch" ]; then
    printf '%s --%%' "$label"
    return
  fi

  diff_sec=$(( reset_epoch - now_epoch ))
  [ "$diff_sec" -lt 0 ] && diff_sec=0

  # Window duration in seconds
  if [ "$window" = "5h" ]; then
    total_sec=18000   # 5 * 3600
  else
    total_sec=604800  # 7 * 86400
  fi

  elapsed_sec=$(( total_sec - diff_sec ))
  [ "$elapsed_sec" -lt 0 ] && elapsed_sec=0

  # Expected linear usage %
  expected=$(( elapsed_sec * 100 / total_sec ))
  rounded_pct=$(printf '%.0f' "$pct")
  delta=$(( rounded_pct - expected ))

  # Suppress pace coloring when absolute usage is under 5% — the pace delta
  # against a tiny expected value is noisy early in a window.
  if [ "$rounded_pct" -lt 5 ]; then
    color=""
  elif [ "$delta" -ge 15 ]; then
    color="$RED"
  elif [ "$delta" -ge 5 ]; then
    color="$ORANGE"
  elif [ "$delta" -ge -5 ]; then
    color="$GREEN"
  elif [ "$delta" -ge -10 ]; then
    color="$BLUE"
  else
    color=""
  fi

  # Print: pace-colored label + pace-colored actual% + plain /expected%
  # When pace is outside colored bands, hide /expected (signal is noisy).
  if [ -n "$color" ]; then
    printf "${color}%s${RESET} ${color}%s%%${RESET}/%d%%" "$label" "$rounded_pct" "$expected"
  else
    printf "%s %s%%" "$label" "$rounded_pct"
  fi
}

user=$(whoami)

# === LINE 1 ===
printf "${GREEN}@%s${RESET} ➜ ${BLUE}%s${RESET}" "$user" "$trimmed"

if [ -n "$branch" ]; then
  printf " ${CYAN}(${RED}%s${CYAN})${RESET}" "$branch"
fi

if [ -n "$model" ]; then
  printf " | %s" "$model"
fi

printf " %s" "$(context_bar "$used")"
echo

# === LINE 2 ===
rate_segment "5h" "$rl5_pct" "$rl5_resets"
if [ -n "$rl5_resets" ]; then
  printf " (%s)" "$(format_reset "$rl5_resets" "5h")"
fi

printf " | "
rate_segment "7d" "$rl7_pct" "$rl7_resets"
if [ -n "$rl7_resets" ]; then
  printf " (%s)" "$(format_reset "$rl7_resets" "7d")"
fi
