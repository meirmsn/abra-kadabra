#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, and pipeline failures
IFS=$'\n\t'       # Stricter word splitting

# 1. Extract Docker DNS info BEFORE any flushing
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# Flush existing rules and delete existing ipsets
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

# 2. Selectively restore ONLY internal Docker DNS resolution
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
else
    echo "No Docker DNS rules to restore"
fi

# First allow DNS and localhost before any restrictions
# Allow outbound DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
# Allow inbound DNS responses
iptables -A INPUT -p udp --sport 53 -j ACCEPT
# Allow outbound SSH
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
# Allow inbound SSH responses
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
# Allow localhost
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Create ipset with CIDR support
ipset create allowed-domains hash:net

# Fetch GitHub meta information and aggregate + add their IP ranges
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi

if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
    echo "ERROR: GitHub API response missing required fields"
    exit 1
fi

echo "Processing GitHub IPs..."
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "ERROR: Invalid CIDR range from GitHub meta: $cidr"
        exit 1
    fi
    echo "Adding GitHub range $cidr"
    ipset add allowed-domains "$cidr"
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

# Track soft-skipped domains so the final summary banner makes them
# impossible to miss (a single mid-script WARN can scroll off-screen
# behind hundreds of "Adding $ip" lines from the surviving entries).
SKIPPED_DOMAINS=()

# Resolve and add other allowed domains
# === PROJECT-SPECIFIC DOMAINS ===
# Static template list below covers stack-common services (npm / GitHub /
# Anthropic / Sentry / Vercel / VS Code / common CDNs / ntfy). Project-
# specific domains (your Supabase project URL, Sentry org ingest, PostHog
# region, Vercel app URL) go in .devcontainer/firewall-extra-domains —
# a project-owned [scaffold-once] file that init-devshop.sh seeds and
# locks (root:root 644). Edits there persist across container starts.
# init-firewall.sh itself is [locked] — edits below revert on next start.
#
# Note on Supabase egress (deliberately omitted under compose
# isolation):
# `api.supabase.com` (control plane) and `aws-0-us-west-2.pooler.supabase.com`
# (connection pooler) are NOT in this allowlist by default. Migrations +
# functions deploy from CI on push-to-main (see .github/workflows/deploy-{migrations,
# functions}.yml), never from this devcontainer. The local stack runs in
# the sibling `supabase-runner` compose service; the workspace reaches the
# data plane via host.docker.internal:54321 (REST) / :54322 (Postgres) —
# explicitly allowed by the host-gateway rule below — and reaches the
# cmd-relay via `supabase-runner:9000` over the compose-internal
# `supabase-net` bridge (allowed by the HOST_NETWORK ACCEPT rule). If your
# project needs `supabase link` / `supabase db push` from this devcontainer,
# add `api.supabase.com` to .devcontainer/firewall-extra-domains.
# See /devshop/kit/notes/security/local-supabase-isolation-options.md.
#
# Also no `download.docker.com` / `registry-1.docker.io` / `auth.docker.io`
# / `production.cloudflare.docker.com` — compose-isolation workspace has no docker
# CLI install, so it never fetches Docker tooling at build or runtime. The
# supabase-runner sibling does, but it doesn't run this firewall script.
for domain in \
    "registry.npmjs.org" \
    "deb.debian.org" \
    "api.anthropic.com" \
    "sentry.io" \
    "statsig.com" \
    "marketplace.visualstudio.com" \
    "vscode.blob.core.windows.net" \
    "update.code.visualstudio.com" \
    "cdn.playwright.dev" \
    "playwright.download.prss.microsoft.com" \
    "vercel.com" \
    "api.vercel.com" \
    "cdn.jsdelivr.net" \
    "objects.githubusercontent.com" \
    "fonts.googleapis.com" \
    "fonts.gstatic.com" \
    "ntfy.sh" \
    ; do
    echo "Resolving $domain..."
    ips=$(dig +noall +answer A "$domain" 2>/dev/null | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        # Tolerant resolution: a single retired or transiently-unresolvable
        # domain shouldn't brick postStartCommand. Loud yellow inline banner
        # AND a deferred summary banner at the end (so it can't scroll away
        # behind hundreds of "Adding $ip" lines from surviving entries).
        printf '\n\033[1;33m================================================================\n' >&2
        printf 'WARN: Failed to resolve %s\n' "$domain" >&2
        printf 'Skipping — egress to this host will be BLOCKED by the firewall.\n' >&2
        printf 'If the domain is gone, remove it from init-firewall.sh.\n' >&2
        printf 'If transient, rerun: sudo /usr/local/bin/init-firewall.sh\n' >&2
        printf '================================================================\033[0m\n\n' >&2
        SKIPPED_DOMAINS+=("$domain")
        continue
    fi

    while read -r ip; do
        if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "ERROR: Invalid IP from DNS for $domain: $ip"
            exit 1
        fi
        echo "Adding $ip for $domain"
        ipset add allowed-domains "$ip" 2>/dev/null || true
    done < <(echo "$ips")
done

# Project-specific extras — read /workspace/.devcontainer/firewall-extra-domains
# (scaffold-once: seeded by init-devshop.sh from /devshop/template/, then owned
# by the project). One bare hostname per line; lines beginning with # are
# ignored. Each line is validated against a strict DNS-label regex before being
# resolved + added to the allowed-domains ipset. The file is root-owned 644 so
# only the operator (with sudo) can edit it.
EXTRAS_FILE="/workspace/.devcontainer/firewall-extra-domains"
if [ -f "$EXTRAS_FILE" ]; then
    echo "Reading project-specific extras from $EXTRAS_FILE..."
    while IFS= read -r raw || [ -n "$raw" ]; do
        line="${raw%%#*}"
        line="$(echo -n "$line" | tr -d '[:space:]')"
        [ -z "$line" ] && continue
        if [[ ! "$line" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
            printf '\n\033[1;33mWARN: firewall-extra-domains line %q is not a valid hostname — skipping\033[0m\n' "$line" >&2
            SKIPPED_DOMAINS+=("$line")
            continue
        fi
        echo "Resolving extra $line..."
        ips=$(dig +noall +answer A "$line" 2>/dev/null | awk '$4 == "A" {print $5}')
        if [ -z "$ips" ]; then
            printf '\n\033[1;33mWARN: Failed to resolve extra %s — skipping\033[0m\n' "$line" >&2
            SKIPPED_DOMAINS+=("$line")
            continue
        fi
        while read -r ip; do
            if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "ERROR: Invalid IP from DNS for extra $line: $ip"
                exit 1
            fi
            echo "Adding $ip for extra $line"
            ipset add allowed-domains "$ip" 2>/dev/null || true
        done < <(echo "$ips")
    done < "$EXTRAS_FILE"
fi

# GitHub Actions artifact storage — Azure Blob shards published in
# api.github.com/meta § domains.actions (currently productionresultssa0-19;
# new shards added by GitHub get picked up automatically). Tolerant
# resolution skips hosts that don't resolve from this region. Without
# these, `gh run download` from the devcontainer fails with "no route to host".
echo "Resolving GitHub Actions artifact storage hosts..."
for domain in $(echo "$gh_ranges" | jq -r '.domains.actions[]? | select(test("blob\\.core\\.windows\\.net"))'); do
    ips=$(dig +noall +answer A "$domain" 2>/dev/null | awk '$4 == "A" {print $5}')
    [ -z "$ips" ] && continue
    while read -r ip; do
        if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "Adding $ip for $domain"
            ipset add allowed-domains "$ip" 2>/dev/null || true
        fi
    done < <(echo "$ips")
done

# Get host IP from default route
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
    echo "ERROR: Failed to detect host IP"
    exit 1
fi

HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "Host network detected as: $HOST_NETWORK"

# Set up remaining iptables rules
iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

# Allow workspace → host.docker.internal on supabase data-plane ports.
# Under compose isolation, supabase's spawned sibling containers
# (supabase_kong_*, supabase_db_*) bind host ports (REST/kong + Postgres)
# directly. Workspace reaches them via host.docker.internal which Docker
# Desktop maps to the host gateway. Without this rule the default DROP
# policy below would block the connection, since host.docker.internal's
# IP is outside HOST_NETWORK.
#
# Port sourcing: SUPABASE_API_PORT + SUPABASE_DB_PORT are read directly
# from /workspace/.devcontainer/.env (root-readable; this script runs as
# root via sudo in postStartCommand). Compose's env_file: .env directive
# puts the vars into the workspace's process environment, but sudo strips
# env vars by default (no env_keep / no --preserve-env on the
# postStartCommand sudo invocation), so we can't rely on inherited vars
# inside this script. Reading .env directly is self-contained and works
# regardless of how the script is invoked.
#
# Defaults: 54321 (REST/kong) + 54322 (Postgres) — Supabase's upstream
# defaults. Projects that rebind to avoid host-port collisions (e.g.
# home-os uses 54421/54422 — see project CLAUDE.md § Local Supabase ports)
# declare the rebind by adding SUPABASE_API_PORT= + SUPABASE_DB_PORT=
# lines to .devcontainer/.env; the workspace's outbound ACCEPT rule
# tracks automatically; no edit to this script required. Numeric
# validation below catches typos before iptables emits an opaque "invalid
# argument" error.
#
# Use `getent ahostsv4` (NOT `getent hosts`) — Docker Desktop's
# host.docker.internal can resolve to either an IPv4 or IPv6 address
# depending on Docker Desktop version + macOS Docker network settings,
# and the choice may flip across Docker Desktop restarts. iptables here
# is IPv4-only (ip6tables would be a separate rule set), so passing it
# an IPv6 address fails with "host/network not found" and the script
# aborts. ahostsv4 explicitly returns the IPv4 form, which is also the
# one that actually works for our case (supabase's spawned siblings bind
# 0.0.0.0:<api> + 0.0.0.0:<db> IPv4 host ports).
ENV_FILE="/workspace/.devcontainer/.env"
if [ -f "$ENV_FILE" ]; then
    api_line=$(grep -E '^SUPABASE_API_PORT=' "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '[:space:]"'"'"'')
    db_line=$(grep -E '^SUPABASE_DB_PORT=' "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '[:space:]"'"'"'')
    [ -n "$api_line" ] && SUPABASE_API_PORT="$api_line"
    [ -n "$db_line" ] && SUPABASE_DB_PORT="$db_line"
fi
SUPABASE_API_PORT="${SUPABASE_API_PORT:-54321}"
SUPABASE_DB_PORT="${SUPABASE_DB_PORT:-54322}"
for port_name in SUPABASE_API_PORT SUPABASE_DB_PORT; do
    port_val=$(eval echo "\$$port_name")
    if [[ ! "$port_val" =~ ^[0-9]+$ ]] || [ "$port_val" -lt 1 ] || [ "$port_val" -gt 65535 ]; then
        echo "ERROR: $port_name=$port_val is not a valid TCP port (must be 1-65535)"
        echo "       Source: $ENV_FILE"
        exit 1
    fi
done
HOST_DOCKER_INTERNAL=$(getent ahostsv4 host.docker.internal 2>/dev/null | awk '{print $1}' | head -1)
if [ -n "$HOST_DOCKER_INTERNAL" ]; then
    echo "Allowing host.docker.internal ($HOST_DOCKER_INTERNAL) on supabase ports $SUPABASE_API_PORT + $SUPABASE_DB_PORT"
    iptables -A OUTPUT -d "$HOST_DOCKER_INTERNAL" -p tcp --dport "$SUPABASE_API_PORT" -j ACCEPT
    iptables -A OUTPUT -d "$HOST_DOCKER_INTERNAL" -p tcp --dport "$SUPABASE_DB_PORT" -j ACCEPT
else
    echo "warn: host.docker.internal did not resolve to IPv4; supabase reachability from workspace will fail"
fi

# Set default policies to DROP first
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# First allow established connections for already approved traffic
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Then allow only specific outbound traffic to allowed domains
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Explicitly REJECT all other outbound traffic for immediate feedback
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Firewall configuration complete"
echo "Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - was able to reach https://example.com"
    exit 1
else
    echo "Firewall verification passed - unable to reach https://example.com as expected"
fi

# Verify GitHub API access
if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
else
    echo "Firewall verification passed - able to reach https://api.github.com as expected"
fi

# Final summary: re-surface skipped domains so they don't scroll off-screen
# behind hundreds of "Adding $ip" / verification lines.
if [ ${#SKIPPED_DOMAINS[@]} -gt 0 ]; then
    printf '\n\033[1;33m################################################################\n' >&2
    printf '#  WARN: Firewall init completed with %d unresolved domain(s):\n' "${#SKIPPED_DOMAINS[@]}" >&2
    for d in "${SKIPPED_DOMAINS[@]}"; do
        printf '#    - %s\n' "$d" >&2
    done
    printf '#  Egress to those hosts is BLOCKED. If the domain is retired,\n' >&2
    printf '#  remove it from .devcontainer/init-firewall.sh and rebuild.\n' >&2
    printf '################################################################\033[0m\n\n' >&2
fi

# Bootstrap the locked PRODUCTION_URL file used by refresh-allowed-ips.sh.
# init-prod-url.sh reads /workspace/.devcontainer/.env once, validates,
# writes /etc/refresh-allowed-ips/production_url. Runs in this script's
# root context — no separate sudo entry needed, intentionally not exposed
# to node-user invocation. See init-prod-url.sh header for the threat model.
if [ -x /usr/local/bin/init-prod-url.sh ]; then
    /usr/local/bin/init-prod-url.sh \
        || echo "warn: init-prod-url.sh failed; refresh-allowed-ips.sh will no-op until next rebuild" >&2
else
    echo "warn: /usr/local/bin/init-prod-url.sh missing; refresh-allowed-ips.sh will no-op" >&2
fi
