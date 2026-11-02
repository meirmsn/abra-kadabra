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
# The project's directory. After a worker restart the hook starts in the session's base directory
# (in a cloud session, /home/user, which holds the repo's clone), not in the repo (F-NEW-77): there,
# the one git repo directly below is the project, and the line says where the session started. With
# none or several below, nothing names the project, and the line says no pin was read.
start=${CLAUDE_PROJECT_DIR:-$PWD}
started="" unread=""
if ! project_dir=$(git -C "$start" rev-parse --show-toplevel 2>/dev/null); then
  project_dir=$start
  if [ ! -f "$start/.devshop-version" ]; then
    repos=()
    for d in "$start"/*/; do
      [ ! -e "$d.git" ] || repos+=("${d%/}")
    done
    if [ "${#repos[@]}" = 1 ]; then
      project_dir=${repos[0]}; started="the session started in $start, not in the repo"
    else
      unread="the session's directory $start is not a git repo and holds ${#repos[@]} repos, so no project .devshop-version was read"
    fi
  fi
fi
# The bootstrap's result (specs/bootstrap-result-at-session-start.md): the setup log survives into
# sessions, and a failed bootstrap otherwise goes unsaid. Only the bootstrap's own log() lines count
# ("[HH:MM:SS] <text>"), from its last "bootstrap start" (the log is appended to, and the priming run
# reads it before its own RESULT): a RESULT that says FAILED names each failed step once, in order,
# as the text after "FAILED: " up to the first colon. A missing log, a done run or a run with no
# RESULT line adds nothing; a log that can't be read is said. Feedback for the owner, guarding nothing.
SETUP_LOG=/tmp/devshop-setup.log
bootstrap_note() {
  local text
  [ -e "$SETUP_LOG" ] || return 0
  text=$(cat -- "$SETUP_LOG" 2>/dev/null) || { echo "couldn't read $SETUP_LOG to check the bootstrap's result"; return 0; }
  awk -v logfile="$SETUP_LOG" '
    function reset() { n = 0; split("", seen); result = "" }
    BEGIN { reset() }
    /^\[[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\] bootstrap start / { reset(); next }
    /^\[[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\] FAILED: / {
      s = $0; sub(/^\[[0-9:]*\] FAILED: /, "", s); sub(/:.*/, "", s)
      if (!(s in seen)) { seen[s] = 1; steps[++n] = s }
      next
    }
    /^\[[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\] RESULT: bootstrap FAILED/ { result = "FAILED"; next }
    /^\[[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\] RESULT: bootstrap done/ { result = "done"; next }
    END {
      if (result != "FAILED") exit
      list = ""
      for (i = 1; i <= n; i++) list = list (i > 1 ? ", " : "") steps[i]
      printf "bootstrap FAILED%s: see %s\n", (list == "" ? "" : " (" list ")"), logfile
    }' <<<"$text"
}
boot=$(bootstrap_note)
# say <message> [<tail after the copy's date and the project>] [main]: the main line (the one naming
# the version, or that it was kept) ends with the bootstrap's result, so it is said once.
say() {
  local tail=${2:-}
  [ -z "$started" ] || tail=${tail:+$tail; }$started
  [ "${3:-}" != main ] || [ -z "$boot" ] || tail=${tail:+$tail; }$boot
  echo "DEVSHOP: $1 · $copy · project ${project_dir##*/}${tail:+; $tail}"
}
kept() {
  local c
  if c=$(readlink "$CURRENT" 2>/dev/null); then c=${c##*/}; echo "kept version ${c:0:12}"
  else echo "no devshop version is active, so no devshop skills this session"; fi
}

# is_release <name>: a release tag, vX.Y.Z with X >= 2 (v1's tags never count).
is_release() { [[ $1 =~ ^v([2-9]|[1-9][0-9]+)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; }

# dispatch: picks and primes the version, runs its session-start script; prints the lines.
dispatch() {
  pinfile="$project_dir/.devshop-version"
  if [ -f "$pinfile" ]; then
    pin=$(tr -d '[:space:]' <"$pinfile"); from="project .devshop-version"
  else
    pin=$(cat "$VERSIONS/default-ref" 2>/dev/null); from="environment default (${unread:-no .devshop-version})"
  fi
  # A pin is a release tag (vX.Y.Z, made by CI: specs/devshop-releases.md) or a commit SHA (to try a
  # branch); refuse anything that could be read as an option or a revision expression.
  case "$pin" in
    '' | -* | *[!A-Za-z0-9._/-]*)
      say "'$pin' ($from) is not a devshop version (a release tag or commit SHA) — $(kept)" "" main; return 0 ;;
  esac
  sha=$(git --git-dir="$MIRROR" rev-parse -q --verify "$pin^{commit}" 2>/dev/null)
  if [ -z "$sha" ]; then
    say "version '$pin' ($from) is not in the local devshop copy — $(kept)" \
      "the copy refreshes when the environment cache rebuilds (about weekly) or when the setup script is edited" main
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
      say "version '$pin' (${sha:0:12}) has no devshop runtime at $RUNTIME/ (older than the v2 install?) — $(kept)" "" main
      return 0
    fi
  fi
  ln -sfn "$dir" "$CURRENT"
  # A project pinning a release learns of a newer one in the copy (feedback; vX.Y.Z tags from v2 on).
  newer=""
  if [ "$from" = "project .devshop-version" ] && is_release "$pin"; then
    newest=$(git --git-dir="$MIRROR" tag -l 'v*' 2>/dev/null | while read -r t; do ! is_release "$t" || echo "$t"; done | sort -V | tail -1)
    if [ -n "$newest" ] && [ "$newest" != "$pin" ] && [ "$(printf '%s\n%s\n' "$pin" "$newest" | sort -V | tail -1)" = "$newest" ]; then
      newer="newer release $newest in the copy (/devshop:upgrade)"
    fi
  fi
  say "using $pin (${sha:0:12}) from $from" "$newer" main
  if [ -z "${DEVSHOP_PRIME_ONLY:-}" ] && [ -x "$CURRENT/hooks/session-start.sh" ]; then
    CLAUDE_PROJECT_DIR=$project_dir "$CURRENT/hooks/session-start.sh" || say "version ${sha:0:12}'s session-start script failed (exit $?)"
  fi
}

# Hook output reaches only Claude, and a project carries no devshop rule to repeat it (LOG #43). So
# the lines go out as Claude Code's hook JSON: additionalContext gives Claude the lines plus the ask
# to repeat them, which is how the owner sees them; systemMessage carries them too, for surfaces that
# display it (the macOS desktop and web apps don't at session start, LOG #45). Malformed JSON would be
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
