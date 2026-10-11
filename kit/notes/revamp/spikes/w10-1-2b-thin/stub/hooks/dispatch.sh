#!/usr/bin/env bash
# W10.1.2b stub dispatcher: point /opt/devshop-current at the version the project pins in
# .devshop-version (else the environment default), extracting it from the local devshop copy
# the setup script cloned. No network. Then run that version's own SessionStart script.
MIRROR=${DEVSHOP_MIRROR:-/opt/devshop.git}
VERSIONS=${DEVSHOP_VERSIONS:-/opt/devshop-versions}
CURRENT=${DEVSHOP_CURRENT:-/opt/devshop-current}
RUNTIME=kit/notes/revamp/spikes/w10-1-2b-thin/runtime   # v2: the runtime's path in the devshop repo

pinfile="${CLAUDE_PROJECT_DIR:-.}/.devshop-version"
if [ -f "$pinfile" ]; then
  pin=$(tr -d '[:space:]' < "$pinfile"); from="project .devshop-version"
else
  pin=$(cat "$VERSIONS/default-ref" 2>/dev/null); from="environment default (no .devshop-version)"
fi
sha=$(git --git-dir="$MIRROR" rev-parse -q --verify "$pin^{commit}" 2>/dev/null)
if [ -z "$sha" ]; then
  echo "DEVSHOP: version '$pin' ($from) is not in the cached devshop copy. It refreshes when the environment cache rebuilds (about weekly) or when the setup script is edited."
  exit 0
fi
dir="$VERSIONS/$sha"
if [ ! -d "$dir" ]; then
  rm -rf "$dir.tmp"; mkdir -p "$dir.tmp"
  if git --git-dir="$MIRROR" archive "$sha:$RUNTIME" 2>/dev/null | tar -x -C "$dir.tmp" 2>/dev/null \
     && [ -d "$dir.tmp/skills" ]; then
    mv "$dir.tmp" "$dir"
  else
    rm -rf "$dir.tmp"
    echo "DEVSHOP: version '$pin' (${sha:0:12}) has no devshop runtime at $RUNTIME — kept $(readlink "$CURRENT" 2>/dev/null || echo none)"
    exit 0
  fi
fi
ln -sfn "$dir" "$CURRENT"
echo "DEVSHOP: using $pin (${sha:0:12}) from $from"
[ -z "$DEVSHOP_PRIME_ONLY" ] && [ -x "$CURRENT/hooks/session-start.sh" ] && "$CURRENT/hooks/session-start.sh"
exit 0
