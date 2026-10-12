#!/usr/bin/env bash
# Tests the secret-scanning config (/.gitleaks.toml) against planted fake secrets (L-11, L-40).
# Usage: tests/gitleaks.test.sh [config]   (default: the repo's .gitleaks.toml)
# Needs `gitleaks` on PATH (or $GITLEAKS). A missing tool fails the test; it never passes.
# The fake secrets are generated at run time, so this file holds none and the repo's own scan stays clean.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
config=$(cd "$(dirname "${1:-$repo_root/.gitleaks.toml}")" && pwd)/$(basename "${1:-.gitleaks.toml}")
gitleaks=${GITLEAKS:-gitleaks}

source "$repo_root/tests/lib.sh"
command -v "$gitleaks" >/dev/null || fail "gitleaks not found (set \$GITLEAKS or put it on PATH)"
[ -f "$config" ] || fail "config not found: $config"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"

# scan <dir> <report>: run the config over the repo's history; echo gitleaks' exit code.
scan() {
  local rc=0
  "$gitleaks" git "$1" --config "$config" --no-banner --redact --log-level error \
    --report-format json --report-path "$2" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}

# 1. Control: a repo with no secrets passes (exit 0) — the config parses and doesn't flag everything.
new_repo "$work/clean"
printf 'const greeting = "hello world";\napi_url = "https://example.com"\n' >"$work/clean/app.js"
git -C "$work/clean" add -A && git -C "$work/clean" commit -qm "add app"
rc=$(scan "$work/clean" "$work/clean.json")
[ "$rc" = 0 ] || fail "clean repo: expected exit 0, got $rc"
echo "ok - clean repo passes"

# 2. Plants: each fake secret, committed, must be reported under its expected rule id.
new_repo "$work/planted"
p="$work/planted"
printf 'aws_access_key_id = %s\n' "$(fake_aws_key)" >"$p/aws.ini"
printf 'GH_TOKEN=%s\n' "ghp_$(rand 'A-Za-z0-9' 36)" >"$p/github.env"
printf 'slack: %s\n' "xoxb-$(rand 0-9 12)-$(rand 0-9 12)-$(rand 'A-Za-z0-9' 24)" >"$p/slack.yml"
{
  printf -- '-----BEGIN %s-----\n' "RSA PRIVATE KEY"
  for _ in 1 2 3 4; do rand 'A-Za-z0-9+/' 64; echo; done
  printf -- '-----END %s-----\n' "RSA PRIVATE KEY"
} >"$p/id_rsa"
printf 'api_key = "%s"\n' "$(rand 'a-z0-9' 32)" >"$p/settings.toml"
git -C "$p" add -A && git -C "$p" commit -qm "add config"

rc=$(scan "$p" "$work/planted.json")
[ "$rc" = 1 ] || fail "planted repo: expected exit 1 (leaks found), got $rc"
for rule in aws-access-token github-pat slack-bot-token private-key generic-api-key; do
  grep -q "\"RuleID\": \"$rule\"" "$work/planted.json" || fail "planted $rule not detected"
  echo "ok - detects $rule"
done
echo "PASS: $(basename "$config") detects all 5 planted secrets and passes a clean repo"
