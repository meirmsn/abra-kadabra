# Tests Review — Audit 2

**Range**: `a917e9d..HEAD` (2 commits: `3fa5636`, `7eac1c7`)
**Feature**: `kit-scripts-deny-rule-investigation`
**Date**: 2026-05-23

## Section A — Coverage of new behavior

### Commit 7eac1c7 — settings.json deny rule removal

The fix removes two relative deny patterns (`Edit(kit/scripts/**)`, `Write(kit/scripts/**)`) from `.claude/settings.json`. This is the remediation for the Audit 1 high findings (docs/settings.json inconsistency).

Existing test coverage:

- `structural-invariants.bats` line 326 (`"wiring: devshop settings.json is valid JSON"`) — validates JSON parse. Passes.
- `structural-invariants.bats` line 655 (`"wiring: settings.json denies reads of both repos' .env files"`) — validates specific deny entries for `.env` files. Does NOT cover `kit/scripts` deny rules.
- `guard-security-freshness.bats` — validates settings.json freshness (copy vs symlink), not deny-list content.

No test asserts that the `kit/scripts` deny list uses only absolute paths (the invariant this feature establishes). A regression re-adding relative `Edit(kit/scripts/**)` / `Write(kit/scripts/**)` patterns would silently reintroduce the inconsistent enforcement that motivated this fix.

### Commit 3fa5636 — audit docs (no code)

Docs-only commit (writes to `specs/<feature>/gates/`). No test coverage needed.

### [domain: tests] [section: A] [severity: medium]

**File**: `kit/tests/structural-invariants.bats` (missing test)
**What**: No structural-invariant test asserts that `kit/scripts` deny rules in `settings.json` use only absolute paths (`/devshop/kit/scripts/**`), not relative paths (`kit/scripts/**`). The feature's entire purpose is removing relative patterns to fix inconsistent enforcement in worktrees, but no regression guard exists.
**Why**: A future `settings.json` edit could re-add `Edit(kit/scripts/**)` or `Write(kit/scripts/**)` (relative patterns) without any test catching it. This would silently reintroduce the mid-session flip behavior documented in `spec.md` — early Edit calls succeed (worktree absolute path), later calls fail (relative path match).
**Fix**: Add a test in `structural-invariants.bats` alongside the existing `.env` deny-rule test:

```bash
@test "wiring: kit/scripts deny rules use absolute paths only" {
  local settings="$DEVSHOP/.claude/settings.json"
  [ -f "$settings" ] || skip "settings.json not found"
  local denies
  denies=$(jq -r '.permissions.deny[]?' "$settings")
  # Absolute-path denies must exist
  echo "$denies" | grep -qF 'Edit(/devshop/kit/scripts/**)' || {
    echo "Missing: Edit(/devshop/kit/scripts/**)"
    false
  }
  echo "$denies" | grep -qF 'Write(/devshop/kit/scripts/**)' || {
    echo "Missing: Write(/devshop/kit/scripts/**)"
    false
  }
  # Relative-path denies must NOT exist (cause inconsistent enforcement in worktrees)
  if echo "$denies" | grep -qE '^(Edit|Write)\(kit/scripts/'; then
    echo "Found relative kit/scripts deny pattern — must use absolute /devshop/kit/scripts/** only"
    echo "See specs/kit-scripts-deny-rule-investigation/spec.md for rationale"
    false
  fi
}
```

## Section B — Test quality

No test files were added or modified in this range. Nothing to audit.

## Section C — Bypass trailer audit

Zero `Tests-Coverage-Bypass:` trailers in the range. Nothing to audit.

## Summary

high=0 medium=1 low=0

One medium finding: no regression guard test exists for the invariant this feature establishes (kit/scripts deny rules must use absolute paths only). The fix itself is correct — the relative patterns are removed — but there is no test preventing them from being re-added. Recommended: add a structural-invariant test before merge.
