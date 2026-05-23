# Tests Review — Audit 3

**Range**: `7eac1c7..HEAD` (1 commit: `233fdf3`)
**Feature**: `kit-scripts-deny-rule-investigation`
**Date**: 2026-05-23

## Section A — Coverage of new behavior

### Commit 233fdf3 — regression guard test for absolute-only deny rules

This commit adds a new bats test (`kit/tests/structural-invariants.bats` line 670) that directly addresses the Audit 2 medium finding. The test:

1. Asserts the two absolute deny rules exist: `Edit(/devshop/kit/scripts/**)` and `Write(/devshop/kit/scripts/**)` (positive guard).
2. Asserts no relative deny patterns `Edit(kit/scripts/...)` or `Write(kit/scripts/...)` exist (negative guard).
3. Provides clear failure messages with a pointer to `specs/kit-scripts-deny-rule-investigation/spec.md` for rationale.

The test is a structural-invariant test for a `settings.json` configuration change — no other source code was modified in this range, so no additional test coverage is required.

Test verified: runs and passes against current `settings.json`.

No coverage gaps.

## Section B — Test quality

### Assertion quality — pass

The test uses `grep -qF` (fixed-string exact match) for the positive assertions and `grep -qE` with a `^`-anchored regex for the negative assertion. Both are specific, concrete assertions — not weak `toBeDefined`/`toBeTruthy`-style checks. Each failure branch emits a descriptive error message before returning false.

### Regex correctness — pass

The negative regex `'^(Edit|Write)\(kit/scripts/'` correctly matches relative patterns (e.g., `Edit(kit/scripts/**)`) without false-positiving on absolute patterns (e.g., `Edit(/devshop/kit/scripts/**)`) because the absolute form has `/devshop/` between the `(` and `kit/`. The `^` anchor is valid because `jq -r '.permissions.deny[]?'` outputs one entry per line.

### Missing error/invalid input tests — n/a

This is a structural wiring test, not an API wrapper. No error-path testing applicable.

### Shape-only assertions — n/a

No user-visible output; pure config-validation test. Bypass accepted: structural invariant test over JSON config, no render path.

### Skipped tests audit — pass

No `test.skip`, `test.only`, `describe.skip`, or `describe.only` patterns found in the diff.

## Section C — Bypass trailer audit

Zero `Tests-Coverage-Bypass:` trailers in the range. Nothing to audit.

## Summary

high=0 medium=0 low=0

Tests look solid — no findings. The Audit 2 medium finding (missing regression guard for absolute-only deny invariant) is fully addressed by the new test.
