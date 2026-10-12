#!/usr/bin/env bash
# Installs the devshop into a cloud environment (D-01 D). The root bootstrap.sh runs this right after
# the environment's setup script cloned the devshop into /opt/devshop.git. Usage: bootstrap.sh [ref]
# (default HEAD = main as cloned): the ref whose plugin is installed and which is the default version
# for projects without .devshop-version. Never prompts; every step runs even if an earlier one failed,
# and each failure is logged and makes the exit status non-zero (L-43). Log: /tmp/devshop-setup.log.
set -uo pipefail
MIRROR=/opt/devshop.git
VERSIONS=/opt/devshop-versions
PLUGIN=/opt/devshop-plugin
REF=${1:-HEAD}
LOG=/tmp/devshop-setup.log
failed=0
log() { echo "[$(date -u +%T)] $*" >>"$LOG"; }
step_failed() { log "FAILED: $*"; failed=1; }

log "bootstrap start ref=$REF copy-head=$(git --git-dir="$MIRROR" rev-parse --short "$REF" 2>&1)"

# The setup script clones with the token in the URL: keep the URL it used (no hard-coded account,
# L-01) but drop the credentials, so the token isn't left in the copy's config.
url=$(git --git-dir="$MIRROR" config --get remote.origin.url) || step_failed "no remote URL in $MIRROR"
clean=$(printf '%s' "${url:-}" | sed -E 's#^([A-Za-z][A-Za-z0-9+.-]*://)[^/@]*@#\1#')
[ -z "$clean" ] || git --git-dir="$MIRROR" remote set-url origin "$clean" || step_failed "remote set-url"

mkdir -p "$VERSIONS" || step_failed "mkdir $VERSIONS"
echo "$REF" >"$VERSIONS/default-ref" || step_failed "write default-ref"
# When the local copy was made: every DEVSHOP: line shows its age, since it refreshes only when the
# environment cache rebuilds.
date -u +%FT%TZ >"$VERSIONS/copy-date" || step_failed "write copy-date"

{ rm -rf "$PLUGIN" && mkdir -p "$PLUGIN"; } || step_failed "mkdir $PLUGIN"
git --git-dir="$MIRROR" archive "$REF:install/plugin" | tar -x -C "$PLUGIN" 2>>"$LOG" \
  || step_failed "extract install/plugin at $REF"

# Prime /opt/devshop-current with the default version, so the cached environment has one even
# before the first session; priming doesn't run the version's own session-start script.
DEVSHOP_PRIME_ONLY=1 CLAUDE_PROJECT_DIR=/nonexistent bash "$PLUGIN/devshop/hooks/dispatch.sh" >>"$LOG" 2>&1 \
  || step_failed "prime /opt/devshop-current"

claude plugin marketplace add "$PLUGIN" --scope user >>"$LOG" 2>&1 || step_failed "claude plugin marketplace add"
claude plugin install devshop@devshop --scope user >>"$LOG" 2>&1 || step_failed "claude plugin install"

if [ "$failed" = 0 ]; then
  log "RESULT: bootstrap done (current -> $(readlink /opt/devshop-current))"
else
  log "RESULT: bootstrap FAILED (see FAILED lines above)"
fi
exit "$failed"
