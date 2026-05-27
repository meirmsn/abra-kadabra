# Tests Review — Audit 1

Range: `origin/main..HEAD`
Feature: `bats-hang-on-main-commit`
Audited-at: HEAD

## Section A — Coverage of new behavior

### [domain: tests] [section: A] [severity: medium]

**File**: `kit/scripts/preship/supabase-bootstrap.sh:148-164` (GoTrue admin API fallback in `verify_seed_fixtures`)
**What**: The new `verify_seed_fixtures()` function added in commit `ca42f4d` has three code paths: (1) psql available, (2) psql unavailable + `SUPABASE_SERVICE_ROLE_KEY` set (GoTrue admin API via curl), (3) psql unavailable + no service key (fail-open with warning). Existing tests in `preship-supabase-bootstrap.bats` only exercise path 1 — every test that calls `mock_psql_seed_count` puts a mock `psql` on `$MOCK_BIN`, so path 2 (curl to `/auth/v1/admin/users`) and path 3 (fail-open) are never reached.
**Why**: Path 2 is the primary fix for the reported bug (false-positive "seed missing" under compose isolation where psql is unavailable). If the curl invocation, header formatting, or grep parsing regresses, the bug silently returns — no test catches it. Path 3 (fail-open) could mask real missing-seed errors if the condition is reached unexpectedly.
**Fix**: Add two tests to `preship-supabase-bootstrap.bats`: (a) compose-up with no `psql` in PATH + `SUPABASE_SERVICE_ROLE_KEY` set + curl mock returning JSON containing `alice@test.local` and `bob@test.local` — assert success; (b) same setup but curl mock returning JSON without the fixture emails — assert failure exit 4. Optionally add (c) no psql + no service key — assert the warning on stderr and success exit (fail-open path).

### [domain: tests] [section: A] [severity: low]

**File**: `kit/hooks/bats-format-progress` (new file, 71 lines)
**What**: New bats custom formatter under `kit/hooks/` with no matching `.bats` spec. The devshop rubric expects `kit/hooks/**` additions to have `guard-` bats coverage.
**Why**: If the formatter script has a syntax error or a bash-ism that breaks under edge conditions (e.g., `count=0` causing division by zero in percentage calculation when `bats_tap_stream_plan` is called with 0), it would crash bats and block all commits on main. The failure mode is loud (commit blocked) rather than silent, which reduces severity.
**Fix**: Add a smoke test (`guard-bats-format-progress.bats`) that sources the formatter against a small synthetic TAP stream and verifies it exits 0 with expected summary output. Alternatively, add a structural invariant asserting `kit/hooks/bats-format-progress` is executable and passes `bash -n` (syntax check).

## Section B — Test quality

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/util-build-phase58-audit-parser.bats:128-131`
**What**: The test "build/SKILL.md references /ak-check-docs-and-tests for Audit 1 and Audit 2" asserts `grep -q 'Audit 2' "$SKILL_FILE"` on line 130 — this matches ANY occurrence of "Audit 2" anywhere in the file (4 matches currently), without verifying the association with `/ak-check-docs-and-tests`. The Audit 1 assertion on line 129 properly checks the co-occurrence (`Audit 1.*ak-check-docs-and-tests`), but Audit 2 does not.
**Why**: If a future edit removes the `/ak-check-docs-and-tests` invocation for the Audit 2 pass while leaving other "Audit 2" references intact (e.g., in the Phase 5.8 prose), the test would still pass — silently losing coverage of the Audit 2 dispatch.
**Fix**: Tighten line 130 to `grep -q 'Audit 2.*ak-check-docs-and-tests\|ak-check-docs-and-tests.*Audit 2' "$SKILL_FILE"` (same pattern as the Audit 1 assertion on line 129).

## Section C — Bypass trailer audit

No `Tests-Coverage-Bypass:` trailers found in the range. Nothing to audit.

## Summary

- high: 0
- medium: 1
- low: 2
