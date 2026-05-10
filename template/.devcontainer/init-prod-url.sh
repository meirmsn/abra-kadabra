#!/bin/bash
# init-prod-url.sh — boot-time bootstrap for the firewall-recovery script.
#
# Reads PRODUCTION_URL from /workspace/.devcontainer/.env (operator-set,
# bind-mounted from the host) and writes the validated value to
# /etc/refresh-allowed-ips/production_url (overlay-fs, root-only).
# refresh-allowed-ips.sh reads from the locked file at run time.
#
# Why this two-step (and not just read .env directly): on Docker Desktop's
# `fakeowner` virtiofs mount, files in /workspace appear root-owned to the
# container but are still writable by the workspace user. A compromised
# npm dep could rewrite .env to point at an attacker-controlled domain,
# then sudo refresh-allowed-ips.sh, getting that domain added to the
# egress allowlist. /etc is overlay-fs where Unix permissions are
# enforced for real, so once we copy the validated value there at boot
# (before any node-user code runs), live tampering is shut.
#
# Invocation:
# - Called once at container start by init-firewall.sh (which already
#   runs as root via the postStartCommand NOPASSWD chain).
# - Has NO sudoers entry of its own — `node` cannot invoke it as root.
#   If `node` runs it directly, the writes to /etc fail with EACCES.
#
# Effect of changing PRODUCTION_URL after boot: requires container
# restart to take effect. Live updates are not supported by design.

set -euo pipefail
IFS=$'\n\t'

if [ "$#" -ne 0 ]; then
  echo "ERROR: init-prod-url.sh takes no arguments." >&2
  exit 1
fi

ENVFILE=/workspace/.devcontainer/.env
LOCKED_DIR=/etc/refresh-allowed-ips
LOCKED_FILE="$LOCKED_DIR/production_url"

# Idempotent dir creation — Dockerfile creates it at build time, but
# defending against a missing dir keeps this script standalone.
mkdir -p "$LOCKED_DIR"
chown root:root "$LOCKED_DIR"
chmod 0755 "$LOCKED_DIR"

PRODUCTION_URL=""
if [ -f "$ENVFILE" ]; then
  # awk: extract the value of PRODUCTION_URL, strip surrounding quotes and
  # trailing comments. Last assignment wins if duplicated.
  PRODUCTION_URL=$(awk -F= '
    /^[[:space:]]*PRODUCTION_URL[[:space:]]*=/ {
      sub(/^[[:space:]]*PRODUCTION_URL[[:space:]]*=[[:space:]]*/, "", $0)
      sub(/[[:space:]]*#.*$/, "", $0)
      gsub(/^["'"'"']|["'"'"']$/, "", $0)
      val=$0
    }
    END { print val }
  ' "$ENVFILE")
fi

# Strip whitespace defensively
PRODUCTION_URL="${PRODUCTION_URL// /}"

if [ -z "$PRODUCTION_URL" ]; then
  # Empty/unset is a valid state (project not yet configured). Write an
  # empty locked file so refresh-allowed-ips.sh's no-op branch fires
  # cleanly instead of erroring on a missing file.
  : > "$LOCKED_FILE"
  chown root:root "$LOCKED_FILE"
  chmod 0644 "$LOCKED_FILE"
  echo "init-prod-url: PRODUCTION_URL unset/empty in $ENVFILE — wrote empty $LOCKED_FILE"
  exit 0
fi

# Same regex as refresh-allowed-ips.sh — bare DNS hostname, no scheme,
# no path, no port, no IP literal, no metacharacters. Validating here
# means a malformed .env never produces a malformed locked file.
DOMAIN_REGEX='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'

if [[ ! "$PRODUCTION_URL" =~ $DOMAIN_REGEX ]]; then
  echo "ERROR: PRODUCTION_URL '$PRODUCTION_URL' is not a bare hostname." >&2
  echo "       Expected form: example.com (no scheme, no path, no port)." >&2
  # Refuse to write a malformed value — leave the locked file as-is
  # (or write empty if it didn't exist) so refresh-allowed-ips.sh no-ops.
  if [ ! -f "$LOCKED_FILE" ]; then
    : > "$LOCKED_FILE"
    chown root:root "$LOCKED_FILE"
    chmod 0644 "$LOCKED_FILE"
  fi
  exit 1
fi

# Atomic write: create temp in same dir, then mv into place. Avoids a
# race where another process reads the file mid-write.
TMP=$(mktemp "$LOCKED_DIR/.production_url.XXXXXX")
printf '%s\n' "$PRODUCTION_URL" > "$TMP"
chown root:root "$TMP"
chmod 0644 "$TMP"
mv -f "$TMP" "$LOCKED_FILE"

echo "init-prod-url: locked PRODUCTION_URL=$PRODUCTION_URL into $LOCKED_FILE"
