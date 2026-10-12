#!/usr/bin/env bash
# SessionStart hook of the devshop plugin (D-01 D). Points /opt/devshop-current at the devshop
# version the project pins in .devshop-version (else the environment default: HEAD = main as of the
# local copy), extracting that version's runtime/ from the local copy the setup script cloned (no
# network). Then runs the version's own runtime/hooks/session-start.sh, if it has one. Prints one
# DEVSHOP: line, as hook JSON that asks Claude to repeat it to the owner (see the end).
# Never fails the session: problems go in that line.
MIRROR=/opt/devshop.git
VERSIONS=/opt/devshop-versions
CURRENT=/opt/devshop-current
RUNTIME=runtime

# Every line ends with the local copy's date, time and age (HEAD means main as of then; a same-day
# stale copy shows by its time) and the project the session runs in (one environment per project,
# and the session can't read the environment's name).
copied=$(cat "$VERSIONS/copy-date" 2>/dev/null)
if [ -n "$copied" ] && copied_s=$(date -u -d "$copied" +%s 2>/dev/null); then
  days=$((($(date -u +%s) - copied_s) / 86400))
  [ "$days" = 1 ] && age="1 day old" || age="$days days old"
  copy="devshop copy of $(date -u -d "@$copied_s" '+%F %H:%M') UTC ($age)"
else
  copy="devshop copy of unknown date ($VERSIONS/copy-date missing or unreadable)"
fi
project_dir=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-$PWD}")
# say <message> [<tail after the copy's date and the project>]
say() { echo "DEVSHOP: $1 · $copy · project ${project_dir##*/}${2:+; $2}"; }
kept() {
  local c
  if c=$(readlink "$CURRENT" 2>/dev/null); then c=${c##*/}; echo "kept version ${c:0:12}"
  else echo "no devshop version is active, so no devshop skills this session"; fi
}

# dispatch: picks and primes the version, runs its session-start script; prints the lines.
dispatch() {
  pinfile="${CLAUDE_PROJECT_DIR:-.}/.devshop-version"
  if [ -f "$pinfile" ]; then
    pin=$(tr -d '[:space:]' <"$pinfile"); from="project .devshop-version"
  else
    pin=$(cat "$VERSIONS/default-ref" 2>/dev/null); from="environment default (no .devshop-version)"
  fi
  # Pins are commit SHAs for now (tags once CI makes releases); refuse anything that could be read as
  # an option or a revision expression.
  case "$pin" in
    '' | -* | *[!A-Za-z0-9._/-]*)
      say "'$pin' ($from) is not a devshop version (a commit SHA) — $(kept)"; return 0 ;;
  esac
  sha=$(git --git-dir="$MIRROR" rev-parse -q --verify "$pin^{commit}" 2>/dev/null)
  if [ -z "$sha" ]; then
    say "version '$pin' ($from) is not in the local devshop copy — $(kept)" \
      "the copy refreshes when the environment cache rebuilds (about weekly) or when the setup script is edited"
    return 0
  fi
  dir="$VERSIONS/$sha"
  if [ ! -d "$dir" ]; then
    rm -rf "$dir.tmp" && mkdir -p "$dir.tmp"
    if git --git-dir="$MIRROR" archive "$sha:$RUNTIME" 2>/dev/null | tar -x -C "$dir.tmp" 2>/dev/null \
      && [ -d "$dir.tmp/skills" ]; then
      mv "$dir.tmp" "$dir"
    else
      rm -rf "$dir.tmp"
      say "version '$pin' (${sha:0:12}) has no devshop runtime at $RUNTIME/ (older than the v2 install?) — $(kept)"
      return 0
    fi
  fi
  ln -sfn "$dir" "$CURRENT"
  say "using $pin (${sha:0:12}) from $from"
  if [ -z "${DEVSHOP_PRIME_ONLY:-}" ] && [ -x "$CURRENT/hooks/session-start.sh" ]; then
    "$CURRENT/hooks/session-start.sh" || say "version ${sha:0:12}'s session-start script failed (exit $?)"
  fi
}

# Hook output reaches only Claude, and a project carries no devshop rule to repeat it (LOG #43). So
# the lines go out as Claude Code's hook JSON: additionalContext gives Claude the lines plus the ask
# to repeat them, which is how the owner sees them; systemMessage carries them too, for surfaces that
# display it (the web app doesn't at session start, LOG #45). Malformed JSON would be
# dropped whole, so jq builds it; without jq, the plain lines and the ask go out instead.
ask="Repeat every DEVSHOP: line above to the owner word for word in your first reply."
out=$(dispatch)
[ -n "$out" ] || exit 0
if command -v jq >/dev/null 2>&1 \
  && json=$(jq -n --arg msg "$out" --arg ask "$ask" \
    '{systemMessage: $msg, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: ($msg + "\n\n" + $ask)}}'); then
  printf '%s\n' "$json"
else
  printf '%s\n\n%s\n' "$out" "$ask"
fi
exit 0
