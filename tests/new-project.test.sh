#!/usr/bin/env bash
# Tests that a new project placed by `project-files.py init` passes its own CI with no devshop
# present (specs/new-project.md AC-3 to AC-5; L-46, L-50). A scratch devshop holds this tree's
# manifest and the files it names, released as v2.0.0; `init` places them into a repo holding only
# a README commit, as GitHub creates it. The project then runs from a copy outside this checkout, in a private mount
# namespace where every /opt/devshop* is hidden and PATH has no devshop directory: its fast tier
# (against the README commit, as a PR's CI does, and with an empty base) and slow tier pass, its
# CI has the two tiers, a planted secret and an untested acceptance item fail it, and no placed
# file names /opt/devshop.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"
gitleaks=$(command -v "${GITLEAKS:-gitleaks}") || fail "gitleaks not found (set \$GITLEAKS or put it on PATH)"

if [ -z "${DEVSHOP_TEST_NS:-}" ]; then
  command -v unshare >/dev/null || fail "unshare not found (util-linux)"
  ns=(--mount)
  [ "$(id -u)" = 0 ] || ns+=(--map-root-user)
  DEVSHOP_TEST_NS=1 exec unshare "${ns[@]}" bash "$0" "$@"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# The pinned gitleaks may live under /opt/devshop-tools, hidden below: keep a copy of the binary.
mkdir -p "$work/bin" && cp "$(readlink -f "$gitleaks")" "$work/bin/gitleaks"
isolate_git "$work"

# --- A scratch devshop: this tree's manifest and the files it names, modes included ---
ds="$work/devshop"
mkdir -p "$ds/runtime"
cp "$repo_root/runtime/project-files.txt" "$ds/runtime/"
grep -v '^#' "$repo_root/runtime/project-files.txt" | while read -r _ src _; do
  [ -n "$src" ] || continue
  mkdir -p "$ds/$(dirname "$src")" && cp -p "$repo_root/$src" "$ds/$src"
done
git init -q "$ds" && git -C "$ds" add -A && git -C "$ds" commit -qm "devshop snapshot"
git -C "$ds" tag v2.0.0 # a new project pins a release tag
version=v2.0.0

# --- The new project, placed and committed ---
p="$work/project"
new_repo "$p"
readme=$(git -C "$p" rev-parse HEAD)
"$repo_root/runtime/scripts/project-files.py" init --devshop-git "$ds/.git" --version "$version" \
  --project "$p" --codeowner example-owner >"$work/out" 2>&1 || { cat "$work/out" >&2; fail "init failed"; }
git -C "$p" add -A && git -C "$p" commit -qm "Start from the devshop"
"$repo_root/runtime/scripts/ci-tiers-check.py" "$p/.github/workflows/ci.yml" >"$work/out" 2>&1 \
  || { cat "$work/out" >&2; fail "AC-3: the placed ci.yml doesn't have the two tiers"; }
echo "ok - AC-3: the placed CI has the two tiers"

# AC-5: nothing placed needs the session-only install; the tests README names no item.
if grep -rl /opt/devshop "$p" --exclude-dir=.git; then fail "AC-5: a placed file names /opt/devshop"; fi
if grep -Eq 'AC-[0-9]' "$p/tests/README.md"; then fail "AC-5: tests/README.md names an acceptance item"; fi
echo "ok - AC-5: no placed file names /opt/devshop; tests/README.md names no AC item"

# --- No devshop from here on ---
for d in /opt/devshop*; do
  [ -e "$d" ] || continue
  mount -t tmpfs devshop-hidden "$d" || fail "can't hide $d"
done
for d in /opt/devshop*; do
  [ ! -e "$d" ] || [ -z "$(ls -A "$d")" ] || fail "$d is still readable"
done
path="$work/bin"
IFS=: read -ra dirs <<<"$PATH"
for d in "${dirs[@]}"; do case $d in /opt/devshop* | "$repo_root"*) ;; *) path+=":$d" ;; esac; done
c="$work/clone" && git clone -q "$p" "$c"
cd "$c"

# tier <name> <want exit> <pattern or ''> -- <command...>: run one tier with no devshop.
tier() {
  local name=$1 want=$2 pat=$3 rc=0
  shift 4
  PATH="$path" "$@" >"$work/out" 2>&1 || rc=$?
  [ "$rc" = "$want" ] || { cat "$work/out" >&2; fail "$name: expected exit $want, got $rc"; }
  [ -z "$pat" ] || grep -Eq -- "$pat" "$work/out" || { cat "$work/out" >&2; fail "$name: output lacks /$pat/"; }
  echo "ok - $name"
}
tier "AC-3: the fast tier passes against the README commit (a PR's base)" 0 '' -- scripts/check-fast.sh "$readme"
tier "AC-3: the fast tier passes with an empty base (all history)" 0 '' -- scripts/check-fast.sh ""
tier "AC-3: the slow tier passes" 0 '' -- scripts/check-slow.sh

# AC-4: the placed fast tier fails on what it is there to catch.
base=$(git rev-parse HEAD)
printf 'aws_access_key_id = %s\n' "$(fake_aws_key)" >config.ini
git add -A && git commit -qm "planted secret"
tier "AC-4: a planted secret fails the fast tier" 1 '^scripts/secret-scan\.sh failed$' -- scripts/check-fast.sh "$base"
git reset -q --hard "$base"
cat >specs/a-change.md <<'EOF'
# A change

**Go:** pending

## Intent

Something the owner asked for.

## Decisions

- One decision: its reason (owner, 2026-01-01)

## Acceptance items

- **AC-1** Something that must be true

## Out of scope

- Nothing else
EOF
git add -A && git commit -qm "a spec whose item no test names"
tier "AC-4: an acceptance item no test names fails the fast tier" 1 '^scripts/spec-check\.py failed$' -- scripts/check-fast.sh "$base"
grep -q 'AC-1: no test names it' "$work/out" || { cat "$work/out" >&2; fail "AC-4: the spec check didn't name AC-1"; }
echo "ok - AC-4: the spec check names the untested item"

# specs/project-contract.md AC-4: the placed project's fast tier runs the contract check with no
# devshop present (the clean runs above passed it), and a required item deleted fails it, named.
git reset -q --hard "$base"
grep -q '^== scripts/contract-check.py' "$work/out" || { cat "$work/out" >&2; fail "project-contract AC-4: the fast tier didn't run the contract check"; }
git rm -q scripts/check-slow.sh && git commit -qm "drop the slow tier"
tier "project-contract AC-4: a deleted required item fails the fast tier" 1 '^scripts/contract-check\.py failed$' -- scripts/check-fast.sh "$base"
grep -q '^scripts/check-slow.sh: missing' "$work/out" || { cat "$work/out" >&2; fail "project-contract AC-4: the contract check didn't name the item"; }
echo "ok - project-contract AC-4: the contract check names the missing item"
