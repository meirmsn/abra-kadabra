#!/usr/bin/env bash
# Tests this repo's scripts/deploy.sh, the devshop's release step (specs/devshop-deploy-comment.md
# devshop-deploy AC-5): what it writes for the deploy comment, from its inputs, and that a missing or
# malformed input exits 2 after writing deployed=yes.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
script="$repo_root/scripts/deploy.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sha=0123456789abcdef0123456789abcdef01234567
before=fedcba9876543210fedcba9876543210fedcba98
# run [VAR=value...]: the script with good inputs, overridable; sets $rc, outputs in $work/out.
run() {
  : >"$work/out"
  rc=0
  env -i PATH=/usr/bin:/bin GITHUB_OUTPUT="$work/out" BUILD_SHA=$sha BEFORE=$before \
    GITHUB_SERVER_URL=https://git.example.com GITHUB_REPOSITORY=o/r "$@" bash "$script" >"$work/log" 2>&1 || rc=$?
}

run
[ "$rc" = 0 ] || { cat "$work/log" >&2; fail "devshop-deploy AC-5: exit $rc"; }
cat >"$work/want" <<'EOF'
deployed=yes
version=0123456789ab
previous_version=fedcba987654
url=https://git.example.com/o/r/commit/0123456789abcdef0123456789abcdef01234567
rollback=revert `0123456789ab`
EOF
diff -u "$work/want" "$work/out" >&2 || fail "devshop-deploy AC-5: the outputs differ (above)"
run BEFORE=0000000000000000000000000000000000000000
grep -qx 'previous_version=unknown' "$work/out" || { cat "$work/out" >&2; fail "devshop-deploy AC-5: a first push has no previous version"; }
for bad in BUILD_SHA= BEFORE= BUILD_SHA=abc GITHUB_SERVER_URL=http://git.example.com GITHUB_REPOSITORY=nope GITHUB_REPOSITORY=; do
  run "$bad"
  [ "$rc" = 2 ] || fail "devshop-deploy AC-5: '$bad' should exit 2, got $rc"
  [ "$(cat "$work/out")" = deployed=yes ] || fail "devshop-deploy AC-5: '$bad' should write only deployed=yes, wrote: $(cat "$work/out")"
done
rc=0
env -i PATH=/usr/bin:/bin bash "$script" >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "devshop-deploy AC-5: no GITHUB_OUTPUT should exit 2, got $rc"
grep -q 'secrets\.' "$repo_root/.github/workflows/ci.yml" && fail "devshop-deploy AC-5: the devshop's ci.yml uses a secret"
echo "ok: devshop-deploy AC-5 deploy.sh writes the release's outputs, and exits 2 on a missing input"
echo "PASS: scripts/deploy.sh"
