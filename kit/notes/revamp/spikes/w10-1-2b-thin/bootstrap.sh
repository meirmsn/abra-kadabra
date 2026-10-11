#!/usr/bin/env bash
# W10.1.2b bootstrap — run by the environment's setup script after it cloned the devshop
# into /opt/devshop.git. Usage: bootstrap.sh <default-ref>. Installs the stub plugin at user
# scope and primes /opt/devshop-current with the default version. Logs to /tmp/devshop-setup.log.
set +e
MIRROR=/opt/devshop.git
VERSIONS=/opt/devshop-versions
STUB=/opt/devshop-stub
SPIKE=kit/notes/revamp/spikes/w10-1-2b-thin
REF=${1:-main}
LOG=/tmp/devshop-setup.log
log() { echo "[$(date -u +%T)] $*" >> "$LOG"; }

log "bootstrap start ref=$REF mirror-head=$(git --git-dir=$MIRROR rev-parse --short "$REF" 2>&1)"
rm -rf "$STUB"; mkdir -p "$STUB" "$VERSIONS"
git --git-dir="$MIRROR" archive "$REF:$SPIKE" | tar -x -C "$STUB" 2>> "$LOG" || log "stub extract failed"
echo "$REF" > "$VERSIONS/default-ref"
DEVSHOP_PRIME_ONLY=1 CLAUDE_PROJECT_DIR=/nonexistent bash "$STUB/stub/hooks/dispatch.sh" >> "$LOG" 2>&1
claude plugin marketplace add "$STUB" --scope user >> "$LOG" 2>&1 || log "marketplace add failed"
claude plugin install devshop@devshop-thin --scope user >> "$LOG" 2>&1 || log "plugin install failed"
log "RESULT: bootstrap done (current -> $(readlink /opt/devshop-current))"
exit 0
