#!/usr/bin/env bash
# The devshop's one installer of its pinned tools (L-45, specs/pinned-tools-survive-outage.md), and
# the one place install/tools.pin is parsed. Each pin line, "<name> <version> <sha256> <https URL>",
# is downloaded, checked against its sha256, unpacked into <tools dir>/<name>-<version> and linked as
# <tools dir>/bin/<name>, and <PATH dir>/<name> links to that, so every process finds it on the
# default PATH. An entry in <PATH dir> the devshop didn't make is left as it is and logged.
#
# Usage: tools.sh <build|repair> <tools.pin> <tools dir> <PATH dir> <log> [limit seconds]
#   build:  the bootstrap's step, at the environment cache build. Every tool, its old link removed
#           first (a failed install of a new version can't leave the old one running); each download
#           tried 4 times with backoff (2, 4, 8 s; DEVSHOP_TOOL_RETRY_DELAY sets the first wait, the
#           tests use 0), so a brief outage of the release host doesn't leave a tool missing (F-NEW-158).
#           A bad pin line is that tool's FAILED step; the others still install (L-43).
#   repair: at session start and by hand (hooks/repair-tools.sh). Only tools missing from
#           <tools dir>/bin (not an executable file: absent or a dangling link); each download tried
#           at most twice with curl --connect-timeout 10, all within one limit (default 60 s), after
#           which the tools not done count as missing. PATH is /usr/bin:/bin and DEVSHOP_* overrides
#           are ignored. A pin that can't be read, or any bad line, downloads nothing. Prints one
#           line per tool it acted on, "repaired <name>" or "missing <name>", or one
#           "unreadable <why>" line.
# Both log "[HH:MM:SS] <text>" lines to <log>, a failure as "FAILED: tool <name>: <why>", and take a
# lock on <tools dir>/.lock, so two runs in one container never write the same paths.
# Exit 0: every tool installed; 1: one isn't (or the pin can't be read); 2: bad usage.
# Feedback, not a wall: a session that can write /opt can change this script and what it installs.
set -uo pipefail
mode=${1:-} pinfile=${2:-} tools=${3:-} on_path=${4:-} logfile=${5:-}
case $mode in build | repair) ;; *) echo "usage: tools.sh <build|repair> <tools.pin> <tools dir> <PATH dir> <log> [limit seconds]" >&2; exit 2 ;; esac
[ -n "$pinfile" ] && [ -n "$tools" ] && [ -n "$on_path" ] && [ -n "$logfile" ] || { echo "tools.sh: missing arguments" >&2; exit 2; }
limit=${6:-60}
[[ $limit =~ ^[0-9]+$ ]] || { echo "tools.sh: limit '$limit' is not a number of seconds" >&2; exit 2; }
if [ "$mode" = repair ]; then
  export PATH=/usr/bin:/bin
  unset DEVSHOP_TOOL_RETRY_DELAY
fi
failed=0
log() { echo "[$(date -u +%T)] $*" >>"$logfile"; }
step_failed() { log "FAILED: $*"; failed=1; }
deadline=$(($(date +%s) + limit))
left() { echo $((deadline - $(date +%s))); }

link_on_path() { # link_on_path <name>
  local link="$on_path/$1" target="$tools/bin/$1"
  [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ] && return 0
  if [ -e "$link" ] || [ -L "$link" ]; then
    step_failed "tool $1: $link exists and isn't the devshop's link to $target; left as it is, so the pinned $1 isn't the one on PATH"
    return 0
  fi
  ln -s "$target" "$link" || step_failed "tool $1: link $link to $target"
}
# fetch <name> <out> <url>: build: 4 tries with backoff; repair: 2 tries, each within the time left.
fetch() {
  local try tries=4 delay=${DEVSHOP_TOOL_RETRY_DELAY:-2} t
  [ "$mode" = build ] || { tries=2 delay=1; }
  [[ $delay =~ ^[0-9]+$ ]] || delay=2
  for ((try = 1; try <= tries; try++)); do
    if [ "$mode" = build ]; then
      curl -fsSL -o "$2" "$3" 2>>"$logfile" && return 0
    else
      t=$(left)
      [ "$t" -gt 0 ] || { log "tool $1: the repair's ${limit}s limit ran out"; return 1; }
      timeout "$t" curl -fsSL --connect-timeout 10 -o "$2" "$3" 2>>"$logfile" && return 0
    fi
    [ "$try" -lt "$tries" ] || return 1
    log "retrying tool $1 in ${delay}s (try $try of $tries failed): $3"
    sleep "$delay"
    delay=$((delay * 2))
  done
}
# valid <name> <version> <sha256> <url>: the pin line's shape; a version can't leave <tools dir>.
valid() {
  [[ $1 =~ ^[a-z0-9-]+$ && $2 =~ ^[0-9A-Za-z][0-9A-Za-z.+-]*$ && $2 != *..* \
    && $3 =~ ^[0-9a-f]{64}$ && $4 =~ ^https://[^@[:space:]]+$ ]]
}
BAD="is not '<name> <version> <sha256> <https URL>'"
# install <name> <version> <sha256> <url>: download, verify, unpack and link one tool.
install() {
  local dir="$tools/$1-$2" tmp="$tools/$1.download" bin tries=4
  [ "$mode" = build ] || tries=2
  rm -rf "$dir" "$tmp" && mkdir -p "$dir"
  fetch "$1" "$tmp" "$4" || { rm -f "$tmp"; step_failed "tool $1: download $4 ($tries tries)"; return 1; }
  echo "$3  $tmp" | sha256sum -c - >/dev/null 2>&1 \
    || { rm -f "$tmp"; step_failed "tool $1: checksum of $4 is not the pinned $3"; return 1; }
  { tar --no-same-owner -xf "$tmp" -C "$dir" 2>>"$logfile" && rm -f "$tmp"; } \
    || { rm -f "$tmp"; step_failed "tool $1: unpack $4"; return 1; }
  bin=$(find "$dir" -type f -name "$1" -perm -u+x | head -1)
  { [ -n "$bin" ] && ln -sfn "$bin" "$tools/bin/$1"; } || { step_failed "tool $1: no executable '$1' in $4"; return 1; }
}

mkdir -p "$tools/bin" || { step_failed "tools: mkdir $tools/bin"; [ "$mode" = build ] || echo "unreadable can't create $tools/bin"; exit 1; }
if [ ! -f "$pinfile" ] || [ ! -r "$pinfile" ]; then
  step_failed "tools: can't read $pinfile"
  [ "$mode" = build ] || echo "unreadable can't read $pinfile"
  exit 1
fi
lines=$(grep -v '^#' "$pinfile")
exec 9>"$tools/.lock" || { step_failed "tools: can't open $tools/.lock"; exit 1; }

if [ "$mode" = build ]; then
  flock 9
  [ -n "$lines" ] || exit 0
  while read -r name version sum url; do
    [[ $name =~ ^[a-z0-9-]+$ ]] || { step_failed "tool ${name:-?}: install/tools.pin line $BAD"; continue; }
    rm -f "$tools/bin/$name"
    link_on_path "$name"
    valid "$name" "$version" "$sum" "$url" || { step_failed "tool $name: install/tools.pin line $BAD"; continue; }
    install "$name" "$version" "$sum" "$url" || true
  done <<<"$lines"
  exit "$failed"
fi

# repair: the whole pin is checked before anything is downloaded.
n=0 names=() versions=() sums=() urls=()
while IFS= read -r line; do
  n=$((n + 1))
  read -r name version sum url extra <<<"$line"
  if [ -n "${extra:-}" ] || ! valid "${name:-}" "${version:-}" "${sum:-}" "${url:-}"; then
    log "FAILED: tools: install/tools.pin line $n $BAD"
    echo "unreadable install/tools.pin line $n $BAD"
    exit 1
  fi
  names+=("$name") versions+=("$version") sums+=("$sum") urls+=("$url")
done <<<"$lines"
[ -n "$lines" ] && [ "$n" -gt 0 ] || { log "FAILED: tools: install/tools.pin has no tool"; echo "unreadable install/tools.pin has no tool"; exit 1; }

# Another run in this container holds the lock: wait for it within the limit; past it, write nothing.
if ! flock -w "$(left)" 9; then
  log "FAILED: tools: another run held $tools/.lock past the ${limit}s limit"
  for name in "${names[@]}"; do [ -f "$tools/bin/$name" ] && [ -x "$tools/bin/$name" ] || echo "missing $name"; done
  exit 1
fi
started=0
for i in "${!names[@]}"; do
  name=${names[$i]}
  [ -f "$tools/bin/$name" ] && [ -x "$tools/bin/$name" ] && continue
  [ "$started" = 1 ] || { log "tools repair start"; started=1; }
  if install "$name" "${versions[$i]}" "${sums[$i]}" "${urls[$i]}"; then
    link_on_path "$name"
    echo "repaired $name"
  else
    echo "missing $name"
  fi
done
if [ "$started" = 1 ]; then
  missing=0
  for name in "${names[@]}"; do [ -f "$tools/bin/$name" ] && [ -x "$tools/bin/$name" ] || missing=1; done
  if [ "$missing" = 0 ]; then log "RESULT: tools repair done"; else log "RESULT: tools repair FAILED"; fi
  exit "$missing"
fi
exit 0
