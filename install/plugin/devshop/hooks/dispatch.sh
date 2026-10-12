#!/usr/bin/env bash
# SessionStart hook of the devshop plugin (D-01 D). Points /opt/devshop-current at the devshop
# version the project pins in .devshop-version (else the environment default: HEAD = main as of the
# local copy), extracting that version's runtime/ from the local copy the setup script cloned (no
# network). Then runs the version's own runtime/hooks/session-start.sh, if it has one. Prints one
# DEVSHOP: line for Claude to repeat to the owner. Never fails the session: problems go in that line.
MIRROR=/opt/devshop.git
VERSIONS=/opt/devshop-versions
CURRENT=/opt/devshop-current
RUNTIME=runtime

# Every line ends with the local copy's date and age: HEAD means main as of that date.
copied=$(cat "$VERSIONS/copy-date" 2>/dev/null)
if [ -n "$copied" ] && copied_s=$(date -u -d "$copied" +%s 2>/dev/null); then
  days=$((($(date -u +%s) - copied_s) / 86400))
  [ "$days" = 1 ] && age="1 day old" || age="$days days old"
  copy="devshop copy of ${copied%%T*} ($age)"
else
  copy="devshop copy of unknown date ($VERSIONS/copy-date missing or unreadable)"
fi
# say <message> [<tail after the copy's date>]
say() { echo "DEVSHOP: $1 · $copy${2:+; $2}"; }
kept() {
  local c
  if c=$(readlink "$CURRENT" 2>/dev/null); then c=${c##*/}; echo "kept version ${c:0:12}"
  else echo "no devshop version is active, so no devshop skills this session"; fi
}

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
    say "'$pin' ($from) is not a devshop version (a commit SHA) — $(kept)"; exit 0 ;;
esac
sha=$(git --git-dir="$MIRROR" rev-parse -q --verify "$pin^{commit}" 2>/dev/null)
if [ -z "$sha" ]; then
  say "version '$pin' ($from) is not in the local devshop copy — $(kept)" \
    "the copy refreshes when the environment cache rebuilds (about weekly) or when the setup script is edited"
  exit 0
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
    exit 0
  fi
fi
ln -sfn "$dir" "$CURRENT"
say "using $pin (${sha:0:12}) from $from"
if [ -z "${DEVSHOP_PRIME_ONLY:-}" ] && [ -x "$CURRENT/hooks/session-start.sh" ]; then
  "$CURRENT/hooks/session-start.sh" || say "version ${sha:0:12}'s session-start script failed (exit $?)"
fi
exit 0
