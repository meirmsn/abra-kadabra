#!/usr/bin/env bash
# W10.1.2 spike — paste this into a cloud environment's "Setup script".
# Fetches the devshop at a pinned commit from the PRIVATE abra-kadabra repo using a
# read-only token in the environment variable DEVSHOP_READ_TOKEN, then installs the
# probe plugin at user scope. Logs every step to /tmp/devshop-setup.log (never the token).
# Always exits 0 so a failed probe never blocks the session; the log is the result.

PIN=71ffcb89dff3b6d5990b3c382dadc1f4be44a47d  # full commit SHA to install
REPO=meirmsn/abra-kadabra
DEST=/opt/devshop-pin
PLUGIN_DIR=kit/notes/revamp/spikes/w10-1-2-install
LOG=/tmp/devshop-setup.log

log() { echo "[$(date -u +%T)] $*" >> "$LOG"; }
: > "$LOG"
log "start pin=$PIN user=$(whoami) HOME=$HOME pwd=$(pwd)"
log "cwd listing: $(ls -A 2>&1 | head -20 | tr '\n' ' ')"
log "claude: $(command -v claude || echo MISSING) $(claude --version 2>&1 | head -1)"
log "HTTPS_PROXY set: ${HTTPS_PROXY:+yes} · token set: ${DEVSHOP_READ_TOKEN:+yes}"
log "github.com reachable (no auth): http=$(curl -s -o /dev/null -m 10 -w '%{http_code}' https://github.com 2>&1)"

fetched=""
rm -rf "$DEST"; mkdir -p "$DEST"

# Route 0: abra-kadabra attached to the session as a second repo — take the pin from its clone.
clone=$(find /home -maxdepth 3 -type d -name abra-kadabra 2>/dev/null | head -1)
log "attached clone: ${clone:-none}"
if [ -n "$clone" ]; then
  if git -C "$clone" rev-parse -q --verify "$PIN^{commit}" > /dev/null 2>&1; then
    log "route 0: pin already in clone"
  elif git -C "$clone" fetch -q origin "$PIN" >> "$LOG" 2>&1; then
    log "route 0: pin fetched into clone"
  else
    log "route 0: pin not in clone and fetch failed"
  fi
  if git -C "$clone" archive "$PIN" 2>> "$LOG" | tar -x -C "$DEST" 2>> "$LOG" \
     && [ -d "$DEST/$PLUGIN_DIR" ]; then
    fetched="0:attached-clone"
  else
    log "route 0 (attached clone) failed"
    rm -rf "$DEST"; mkdir -p "$DEST"
  fi
fi

# Route A: git over HTTPS with the token as a basic-auth header.
if [ -z "$fetched" ] && [ -n "$DEVSHOP_READ_TOKEN" ]; then
  auth=$(printf 'x-access-token:%s' "$DEVSHOP_READ_TOKEN" | base64 -w0)
  if git -C "$DEST" init -q \
     && git -C "$DEST" -c http.extraHeader="Authorization: Basic $auth" \
          fetch -q --depth 1 "https://github.com/$REPO" "$PIN" >> "$LOG" 2>&1 \
     && git -C "$DEST" checkout -q FETCH_HEAD >> "$LOG" 2>&1; then
    fetched="A:git+token"
  else
    log "route A (git+token) failed"
  fi
fi

# Route B: GitHub REST tarball with the token.
if [ -z "$fetched" ] && [ -n "$DEVSHOP_READ_TOKEN" ]; then
  rm -rf "$DEST"; mkdir -p "$DEST"
  code=$(curl -sS -L -o /tmp/devshop.tgz -w '%{http_code}' \
    -H "Authorization: Bearer $DEVSHOP_READ_TOKEN" \
    "https://api.github.com/repos/$REPO/tarball/$PIN" 2>> "$LOG")
  log "route B (REST tarball) http=$code"
  if [ "$code" = 200 ] && tar -xzf /tmp/devshop.tgz -C "$DEST" --strip-components=1 >> "$LOG" 2>&1; then
    fetched="B:rest+token"
  fi
fi

# Route C: plain git, no token (expected to fail for a non-attached private repo, F-NEW-11).
if [ -z "$fetched" ]; then
  rm -rf "$DEST"; mkdir -p "$DEST"
  if git -C "$DEST" init -q \
     && git -C "$DEST" fetch -q --depth 1 "https://github.com/$REPO" "$PIN" >> "$LOG" 2>&1 \
     && git -C "$DEST" checkout -q FETCH_HEAD >> "$LOG" 2>&1; then
    fetched="C:git-no-token"
  else
    log "route C (git, no token) failed"
  fi
fi

if [ -z "$fetched" ]; then
  log "RESULT: FETCH FAILED"
  exit 0
fi
log "fetched via $fetched"

claude plugin marketplace add "$DEST/$PLUGIN_DIR" --scope user >> "$LOG" 2>&1 \
  || log "marketplace add failed"
claude plugin install devshop-probe@devshop-spike --scope user >> "$LOG" 2>&1 \
  || log "plugin install failed"
claude plugin list >> "$LOG" 2>&1
log "RESULT: done ($fetched)"
exit 0
