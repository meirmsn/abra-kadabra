#!/usr/bin/env bash
# Counts how many generated fake secrets the pinned gitleaks misses (F-NEW-50, LOG #57).
# Usage: measure.sh <kind> <n> [config]   (config default: the repo's .gitleaks.toml)
#   kind: aws-old    the AWS key generator before the fix: "AKIA" + 16 x rand 'A-Z2-7'
#         aws        fake_aws_key from tests/lib.sh as checked out
#         github-pat, slack-bot-token, private-key, generic-api-key: the plants in tests/gitleaks.test.sh
# Writes <n> values, one per file, scans them with `gitleaks dir`, prints each missed value and then
# "<kind> n=<n> missed=<m>". Needs `gitleaks` on PATH (or $GITLEAKS); a missing tool exits 2.
set -euo pipefail

kind=${1:?kind}
n=${2:?n}
repo_root=$(cd "$(dirname "$0")/../../../../.." && pwd)
config=${3:-$repo_root/.gitleaks.toml}
gitleaks=${GITLEAKS:-gitleaks}
command -v "$gitleaks" >/dev/null || { echo "FAIL: gitleaks not found" >&2; exit 2; }
command -v python3 >/dev/null || { echo "FAIL: python3 not found" >&2; exit 2; }
source "$repo_root/tests/lib.sh"

case $kind in
  aws-old) rule=aws-access-token; gen() { printf 'aws_access_key_id = %s\n' "AKIA$(rand 'A-Z2-7' 16)"; } ;;
  aws) rule=aws-access-token; gen() { printf 'aws_access_key_id = %s\n' "$(fake_aws_key)"; } ;;
  github-pat) rule=github-pat; gen() { printf 'GH_TOKEN=%s\n' "ghp_$(rand 'A-Za-z0-9' 36)"; } ;;
  slack-bot-token) rule=slack-bot-token; gen() { printf 'slack: %s\n' "xoxb-$(rand 0-9 12)-$(rand 0-9 12)-$(rand 'A-Za-z0-9' 24)"; } ;;
  private-key)
    rule=private-key
    gen() {
      printf -- '-----BEGIN %s-----\n' "RSA PRIVATE KEY"
      for _ in 1 2 3 4; do rand 'A-Za-z0-9+/' 64; echo; done
      printf -- '-----END %s-----\n' "RSA PRIVATE KEY"
    }
    ;;
  generic-api-key) rule=generic-api-key; gen() { printf 'api_key = "%s"\n' "$(for _ in $(seq 16); do rand a-z 1; rand 0-9 1; done)"; } ;;
  *) echo "FAIL: unknown kind $kind" >&2; exit 2 ;;
esac

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/v"
for i in $(seq "$n"); do gen >"$work/v/$i.txt"; done

rc=0
"$gitleaks" dir "$work/v" --config "$config" --no-banner --log-level error \
  --report-format json --report-path "$work/r.json" >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] || [ "$rc" = 1 ] || { echo "FAIL: gitleaks exit $rc" >&2; exit 2; }

# Files with a finding under the expected rule; every other file is a miss.
python3 - "$work/r.json" "$rule" >"$work/hit" <<'PY'
import json, os, sys
for f in json.load(open(sys.argv[1])):
    if f["RuleID"] == sys.argv[2]:
        print(os.path.basename(f["File"]))
PY
missed=0
for i in $(seq "$n"); do
  grep -qxF "$i.txt" "$work/hit" && continue
  missed=$((missed + 1))
  echo "  missed: $(head -1 "$work/v/$i.txt")"
done
echo "$kind n=$n missed=$missed"
