#!/bin/bash
# refresh-allowed-ips.sh — re-resolve the project's prod domain and add
# fresh IPs to the firewall's allowed-domains ipset. Idempotent; additive
# only (no iptables touch, no flush, no session disruption).
#
# Why this exists: init-firewall.sh resolves domains to IPs once at
# container start, but CDN edge IPs (Vercel/Cloudflare/etc.) rotate during
# the day. The cached ipset goes stale and post-deploy egress to prod
# fails with EHOSTUNREACH / "No route to host". Re-running init-firewall.sh
# is unsafe (full iptables flush; known to hang the Claude session per
# kit/TODOS.md). This script does ipset adds only.
#
# Domain source — /etc/refresh-allowed-ips/production_url (overlay-fs,
# root-owned 644). The bootstrap script init-prod-url.sh writes this file
# once at container start by reading PRODUCTION_URL from
# /workspace/.devcontainer/.env. Operators set the value in .env and
# rebuild the container; live changes to .env have no effect on the
# locked file. Empty / unset → no-op exit.
#
# Why two files (and not just read .env directly here): /workspace is on
# Docker Desktop's `fakeowner` virtiofs mount where Unix perms are not
# enforced — a compromised npm dep can rewrite .env even though it shows
# as root-owned. /etc is overlay-fs where the kernel enforces perms, so
# the locked file is genuinely tamper-resistant. See init-prod-url.sh.
#
# Note: same name as the GitHub Variable `PRODUCTION_URL` consumed by
# keepalive.yml, but format differs — the GH Variable holds the full URL
# form (`https://your-app.com`); the .env value is the bare hostname.
# Document this divergence in your project's CLAUDE.md if it could trip
# someone copy/pasting between surfaces.
#
# Security model:
# - Lives at /usr/local/bin/, root-owned, mode 755 (Dockerfile COPY)
# - Domain source is /etc/refresh-allowed-ips/production_url
#   (overlay-fs, kernel-enforced root-only writes)
# - Strict DNS-label regex validation as defense-in-depth
# - Rejects argv to prevent attacker-supplied domains
# - Workspace user invokes via NOPASSWD sudoers entry in node-firewall

set -euo pipefail
IFS=$'\n\t'

if [ "$#" -ne 0 ]; then
  echo "ERROR: refresh-allowed-ips.sh takes no arguments." >&2
  exit 1
fi

LOCKED_FILE=/etc/refresh-allowed-ips/production_url
PRODUCTION_URL=""
if [ -f "$LOCKED_FILE" ]; then
  # Locked file is plain hostname (or empty), one line, written atomically
  # by init-prod-url.sh. tr -d strips any trailing newline.
  PRODUCTION_URL=$(tr -d '[:space:]' < "$LOCKED_FILE")
fi

if [ -z "$PRODUCTION_URL" ]; then
  echo "refresh-allowed-ips: PRODUCTION_URL unset/empty in $LOCKED_FILE — no-op"
  echo "  (set PRODUCTION_URL in /workspace/.devcontainer/.env and rebuild the container)"
  exit 0
fi

if ! ipset list allowed-domains >/dev/null 2>&1; then
  echo "ERROR: ipset 'allowed-domains' missing — has init-firewall.sh run?" >&2
  exit 1
fi

# Strict DNS label regex: alphanumerics + dots + hyphens, no metacharacters,
# no whitespace, no IP literals. Defense-in-depth — init-prod-url.sh
# validates with the same regex before writing the locked file, but a
# corrupted file (or a future bug there) shouldn't reach `dig` unchecked.
DOMAIN_REGEX='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'

if [[ ! "$PRODUCTION_URL" =~ $DOMAIN_REGEX ]]; then
  echo "ERROR: PRODUCTION_URL '$PRODUCTION_URL' is not a bare hostname." >&2
  echo "       Expected form: example.com (no scheme, no path, no port)." >&2
  exit 1
fi

ips=$(dig +noall +answer A "$PRODUCTION_URL" 2>/dev/null | awk '$4 == "A" {print $5}')
if [ -z "$ips" ]; then
  echo "warn: $PRODUCTION_URL did not resolve — no IPs added"
  exit 0
fi

added=0
while read -r ip; do
  if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "warn: invalid IP $ip from DNS for $PRODUCTION_URL — skipping"
    continue
  fi
  if ipset add allowed-domains "$ip" 2>/dev/null; then
    echo "Added $ip for $PRODUCTION_URL"
    added=$((added + 1))
  fi
done < <(echo "$ips")

echo "refresh-allowed-ips: added $added new IP(s) for $PRODUCTION_URL"
