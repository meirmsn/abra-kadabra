#!/usr/bin/env bash
# Tests scripts/docs-map-check.py (TARGET § Build 3): it must fail when a doc is not reachable from
# docs/README.md or a relative link is broken (missing file, outside the repo, unknown #anchor),
# ignore links in code, pass a sound map, and fail closed when it can't run.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/scripts/docs-map-check.py"
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"

run_check() {
  local rc=0
  (cd "$1" && "$script") >"$work/out.log" 2>&1 || rc=$?
  echo "$rc"
}
expect() {
  [ "$3" = "$2" ] || { cat "$work/out.log" >&2; fail "$1: expected exit $2, got $3"; }
  echo "ok - $1"
}
# sound_repo <dir>: a map linking a hierarchy, with anchors, a directory link and links in code.
sound_repo() {
  new_repo "$1" # its README.md is linked from the map below
  mkdir -p "$1/docs" "$1/guide/sub"
  cat >"$1/docs/README.md" <<'EOF'
# Docs map

- [Readme](../README.md) and [the guide](../guide/) (a directory: its README.md).
- [Setup, step two](../guide/setup.md#step-two--install-it) and [again](</guide/setup.md#step-two--install-it-1>).
- [External](https://example.com/missing) is not fetched. [Mail](mailto:a@example.com).
- [Ref link][ref] and a [local anchor](#docs-map).

[ref]: ../guide/sub/deep.md
EOF
  cat >"$1/guide/README.md" <<'EOF'
# Guide

See [setup](setup.md).

```md
[in a fence](missing-in-fence.md)
```

Inline code is not a link: `[x](missing-inline.md)`.
EOF
  cat >"$1/guide/setup.md" <<'EOF'
# Setup

## Step two — install `it`

## Step two — install `it`

<a id="custom-anchor"></a>
EOF
  printf '# Deep\n\nBack to [setup](../setup.md#custom-anchor).\n' >"$1/guide/sub/deep.md"
  git -C "$1" add -A && git -C "$1" commit -qm "docs"
}

r="$work/sound"; sound_repo "$r"
expect "a sound docs map passes" 0 "$(run_check "$r")"

r="$work/orphan"; sound_repo "$r"
commit_file "$r" guide/orphan.md "# Orphan"
expect "a doc not reachable from the map fails" 1 "$(run_check "$r")"
grep -q "not reachable from docs/README.md: guide/orphan.md" "$work/out.log" || fail "orphan not named"

r="$work/orphan-untracked"; sound_repo "$r"
printf '# New\n' >"$r/new.md"
expect "a new, not yet committed doc counts" 1 "$(run_check "$r")"

r="$work/ignored"; sound_repo "$r"
printf 'build/\n' >"$r/.gitignore"; git -C "$r" add .gitignore && git -C "$r" commit -qm ignore
mkdir -p "$r/build"; printf '# Generated\n' >"$r/build/out.md"
expect "git-ignored files are not docs" 0 "$(run_check "$r")"

r="$work/island"; sound_repo "$r"
commit_file "$r" a.md "# A
[b](b.md)"
commit_file "$r" b.md "# B
[a](a.md)"
expect "docs linking only each other are still unreachable" 1 "$(run_check "$r")"

r="$work/missing-file"; sound_repo "$r"
commit_file "$r" guide/sub/deep.md "# Deep
[gone](../gone.md)"
expect "a link to a missing file fails" 1 "$(run_check "$r")"
grep -q "guide/sub/deep.md:2: ../gone.md (no such file" "$work/out.log" || fail "broken link not located"

r="$work/missing-anchor"; sound_repo "$r"
commit_file "$r" guide/sub/deep.md "# Deep
[setup](../setup.md#step-three)"
expect "a link to a missing heading fails" 1 "$(run_check "$r")"

r="$work/missing-local-anchor"; sound_repo "$r"
commit_file "$r" guide/sub/deep.md "# Deep
[here](#nowhere)"
expect "a link to a missing heading in the same doc fails" 1 "$(run_check "$r")"

r="$work/outside"; sound_repo "$r"
commit_file "$r" guide/sub/deep.md "# Deep
[up](../../../outside.md)"
printf '# Outside\n' >"$work/outside.md" # exists, but is not part of the repo
expect "a link outside the repo fails" 1 "$(run_check "$r")"
grep -q "(outside the repo)" "$work/out.log" || fail "outside link not reported as such"

r="$work/missing-image"; sound_repo "$r"
commit_file "$r" guide/sub/deep.md "# Deep
![shot](shot.png)"
expect "a missing image fails" 1 "$(run_check "$r")"

r="$work/nomap"; new_repo "$r"
expect "no docs map fails closed" 2 "$(run_check "$r")"
mkdir -p "$work/plain"
expect "outside a git repo fails closed" 2 "$(run_check "$work/plain")"
echo "PASS: docs-map-check.py"
