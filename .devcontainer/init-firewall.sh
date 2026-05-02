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
# /ak-new-project will guide you to add your project-specific domains here.
# Examples of what to add:
#   "<your-app>.vercel.app"            — your Vercel production URL
#   "<ref>.supabase.co"                — your Supabase project URL
#   "o<org-id>.ingest.sentry.io"       — your Sentry ingest endpoint
#   "us.i.posthog.com"                 — PostHog ingest (us or eu)
#   "ghcr.io"                          — GitHub Container Registry (supabase start)
#   "registry-1.docker.io"             — Docker Hub
#   "auth.docker.io"                   — Docker Hub auth
#   "production.cloudflare.docker.com" — Docker Hub CDN
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
    "api.supabase.com" \
    "aws-0-us-west-2.pooler.supabase.com" \
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
