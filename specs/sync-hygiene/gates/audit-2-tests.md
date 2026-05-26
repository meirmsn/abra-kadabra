# Tests Review — Audit 2

**Range**: `9f8217e2dc9e8c7c5a035d10f934397982cb5ad1..HEAD` (2 commits: `099ab2d`, `77ca94d`)
**Date**: 2026-05-26

## Prior-audit fix verification

### Audit 1 medium — missing jq-fallback test (FIXED)

Commit `77ca94d` added `@test "merge falls back to raw copy when jq is unavailable"` at `kit/tests/sync-package-json-merge.bats:141`. The test shadows jq with a failing stub via `$MOCK_BIN`, invokes `from-devshop.sh --yes`, and asserts the project gets the template's name (`"project-name"`) — confirming the raw-copy fallback path fires. The guard was also strengthened from `! command -v jq` to `! echo '{}' | jq '.' &>/dev/null` (tests jq actually works, not just that it's on PATH). The new test directly exercises this strengthened guard. Test passes (`ok 7` in suite run). **Verified fixed.**

### Audit 1 low — regression guard regex gap (UNCHANGED, still mitigated)

`kit/tests/template-ci-yml-shape.bats:405` regex `[^/]` still doesn't match bare `apps/web` at EOL. The companion test at line 394 (`grep -c '\-\-filter[= ]apps/web'` + `assert_failure`) independently catches the bare form including at EOL. Coverage gap remains theoretical only. **No escalation needed.**

## Section A — Coverage of new behavior

No new source behavior introduced in this range. The only `.sh` change is the jq guard strengthening (`from-devshop.sh:72`), which is now covered by the new fallback test. No new scripts, skills, or hooks added.

No findings.

## Section B — Test quality

The new jq-fallback test (`sync-package-json-merge.bats:141-160`) asserts on a specific value (`"project-name"`) rather than a weak truthiness check. It verifies both that the script succeeds (`assert_success`) and that the correct fallback behavior occurred (raw copy overwrites the project's name). The mock-bin stub approach is a clean contract test — it tests the guard's observable behavior (jq broken → fallback to cp) without coupling to internals.

No skip/only patterns found in the diff range.

No findings.

## Section C — Bypass trailer audit

No `Tests-Coverage-Bypass:` trailers found in the range. Nothing to audit.

## Summary

- **high**: 0
- **medium**: 0
- **low**: 0

Tests look solid — no findings. Prior medium is verified fixed; prior low remains mitigated.
