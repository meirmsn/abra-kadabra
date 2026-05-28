<!-- audited-at: cc6c01eab298487486cfd798b6c80ef6d5c40b63 -->

# Review — local-env-pillar

## Gate 1: docs-check

- Result: pass

### Checklist

1. **New scripts documented in conventions.md** -- `local-env-health.sh` has a dedicated subsection at `kit/docs/guide/conventions.md` line 262 under "Local Pre-Push Test Gates". `roster-check.sh` and `check-llm-mediated-na.sh` are internal SKILL.md mechanisms (no direct operator invocation), documented inline in `SKILL.md` at their call sites. This matches the existing pattern: `supabase-bootstrap.sh`, `advisor-clean.sh`, etc. are documented at their appropriate level.

2. **SKILL.md wiring internally consistent** -- All three script invocations in SKILL.md match the actual script interfaces:
   - `local-env-health.sh check` / `recover` matches the script's `case` dispatch (line 250).
   - `roster-check.sh <preflight-sink> <gates-dir> <hero-dir>` matches the 3-arg signature (line 25-28).
   - `check-llm-mediated-na.sh <review.md path>` matches the 1-arg signature (line 27).

3. **migrations.md addition properly structured** -- TOC entry at line 16 links correctly to `## Cross-migration FK rollback patterns` at line 298. Four patterns documented with SQL examples. Cross-reference to the existing "Postgres enum extension" section is implicit via TOC proximity.

4. **No stale cross-references** -- The deleted ROADMAP entry ("Local environment as the single verification surface") has zero remaining references in kit/, CLAUDE.md, or .claude/. The deleted TODOS entry ("Codify regression coverage for /ak-build Phase 3->4 LLM-mediated-n/a awk halt grep") has zero remaining references. Both confirmed via grep.

5. **hooks.md / workflow.md** -- Neither file referenced the roster check or inline awk block before; no updates needed. The new scripts are operational internals of SKILL.md Phase 3, not hook-layer or workflow-layer concepts.

## Dismissals

None

## Gate 2: metrics-check

- Result: n/a (devshop-self-mode: no METRICS.md in devshop)

## Dismissals

None

## Gate 2b: rls-coverage

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 2c: slow-job-lifecycle

- Result: n/a (devshop-self-mode: no slow-job CI)

## Dismissals

None

## Gate 2d: fast-job-local

- Result: pass (1454/1454 bats tests passing, 0 failures, 0 skipped)

Full bats suite run at HEAD (a158f3e). 33 new tests across 3 files (preship-local-env-health.bats, preship-roster-check.bats, util-check-llm-mediated-na.bats), 0 regressions in existing 1421 tests.

## Dismissals

None

## Gate 2e: migration-rollback-roundtrip

- Result: n/a (devshop-self-mode: no migrations)

## Dismissals

None

## Gate 2f: changed-tests-local

- Result: n/a (devshop-self-mode: bats run in Gate 2d covers this)

## Dismissals

None

## Gate 2g: advisor-clean

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 3: responsive-theme

- Result: n/a (devshop-self-mode: no UI surface)

## Dismissals

None

## Gate 4: /simplify

- Result: findings (2) fixed

1. `local-env-health.sh`: removed unused `PROJECT_ROOT` variable (declared, ran `git rev-parse`, never referenced) and redundant `any_failed` tracking variable (replaced with direct `${#failures[@]}` array-length check).
2. `roster-check.sh`: simplified PNG existence check from 3-process pipeline (`ls | head -1 | grep -q .`) to single `ls ... >/dev/null 2>&1`.

All 33 bats tests pass after changes.

## Dismissals

None

## Gate 5: docs-and-tests-review

<!-- audited-at: 23518d9504164240972a4e8dd0c345f63c1860d7 -->
<!-- range: origin/main..HEAD (merge-base: ab7745a) -->

findings: high=0 medium=2 low=2

Note: `origin/main` has diverged by 1 commit (`c5e3aaa`) that is not on
this branch. Changes to `release.sh`, `release-devshop/SKILL.md`,
`propagation-entry.bats`, and the two responsive/theme convention lines
in `conventions.md` are artifacts of that divergence and are excluded
from this audit. The actual feature diff is `ab7745a..HEAD`.

### Docs findings

- [low] **SKILL.md § 3.0 preflight: local-env-health.sh positioned after supabase-bootstrap.sh but spec says "alongside".** The conventions.md addition says the health check runs "alongside the Supabase bootstrap," and the spec (D1) says "Called from Phase 3.0 preflight." In practice, the SKILL.md wiring places the `local-env-health.sh check` call *after* `supabase-bootstrap.sh up` (line 857 vs line 852). This is correct behavior (Supabase must be up before the health check queries its status), but the word "alongside" in conventions.md is slightly misleading. It suggests parallelism when the calls are sequential. Not blocking -- the ordering is correct for correctness; the prose is just imprecise.

- [low] **No cross-reference from `local-env-health.sh` script header to conventions.md.** The script header (line 20) references `specs/local-env-pillar/spec.md` for its provenance, and the SKILL.md wiring is documented. The new `conventions.md` subsection documents the script. However, the script header's `Does NOT:` section could mention that the 1GB threshold is documented in conventions.md for discoverability. Not blocking since the conventions.md subsection is the canonical reference and the script is well-commented.

### Tests findings

- [medium] **Zombie detection failure path untested in `preship-local-env-health.bats`.** Test at line 148 ("check exits 1 on zombie processes") explicitly notes "We can't easily mock /proc/<pid>/status in the real filesystem, so this test verifies the healthy path (no zombies = pass)." The spec lists zombie detection as one of the 4 core checks (D2) and the test matrix (spec § Tests item 4) calls for "check exits 1 on zombie processes (mocked lsof/ss)." The failure path for Check 4 is exercised only in production -- never in the bats suite. This means a regression in the zombie detection logic (e.g., a typo in the `grep '^State:'` pattern at script line 173) would not be caught by tests. Recommendation: create a mock `/proc/<pid>/status` file via `BATS_TEST_TMPDIR` and point the script at it (the script already reads from `/proc/$pid/status` directly, so this would require a small refactor to make the proc path injectable, similar to how `PROC_MEMINFO` is already injectable).

- [medium] **`recover` success-kill path untested.** The bats suite tests two `recover` paths: (1) no processes to kill, (2) refuses to kill the protected dev server PID. The third path -- successfully killing a non-protected zombie and reporting "killed: PID X on port Y" -- is never exercised. The spec (§ Tests item 5) lists "recover kills identified zombies (mocked kill)" as a required test case. The `kill` mock is already scaffolded in the PID-protection test (line 228-233) but never used for the success path. Recommendation: add a test where `ss` reports a PID on a port, `DEV_SERVER_PID` is set to a different value (or empty), and the mock `kill` succeeds, then assert the "killed:" output and verify the kill mock was called.

### Bypass trailer audit

- (none found in the feature commits)

## Dismissals

None

## Gate 6: /review

- Result: findings (2) pending

### Finding 1 — `recover` kills ALL processes on monitored ports, not just zombies (MEDIUM)

**File:** `kit/scripts/preship/local-env-health.sh:198-239`

The `cmd_recover()` function iterates all PIDs on monitored ports (3000, 3001, 54321, 54322) and `kill -9`s every process it finds, except the one protected by `DEV_SERVER_PID`. The only guard is the dev-server PID check. This means:

- Healthy Supabase processes on ports 54321/54322 will be killed during recovery.
- A sibling project's dev server on port 3000 would be killed.
- The success message says "zombie processes killed successfully" (line 233) but the killed processes are not necessarily zombies — the zombie check only exists in `cmd_check()` (lines 170-175), not in `cmd_recover()`.

The spec (D4) says: "kill -9 zombies on ports 3000/3001/54321/54322 after identifying their PIDs + checking they're not the current session's dev server." The intent is to kill zombies specifically, but the implementation kills all processes on those ports.

Additionally, `DEV_SERVER_PID` is never set by the SKILL.md Phase 3.0 wiring (the `bash local-env-health.sh recover` call at line 860 doesn't pass this env var), so in practice the dev-server protection is inert unless the caller explicitly exports it.

**Severity:** MEDIUM — in the normal flow, `recover` only runs after `check` fails, and a failing `check` likely indicates genuinely unhealthy processes. But killing healthy Supabase containers on 54321/54322 would make the situation worse, not better. The misleading "zombie" message is a cosmetic/correctness concern.

### Finding 2 — Negative cgroup headroom produces misleading diagnostic message (LOW)

**File:** `kit/scripts/preship/local-env-health.sh:104-105, 156-159`

If cgroup `memory.current` exceeds `memory.max` (possible with memory overcommit or accounting lag), the arithmetic at line 105 produces a negative `cgroup_headroom_kb`. This flows through to the failure message at line 158-159: `"-600MB available, need 1024MB"`. The negative sign is confusing to the operator. The check itself works correctly (negative < threshold), so this is purely a message quality issue.

**Severity:** LOW — the check is correct, only the diagnostic message is misleading in an edge case that is unlikely in practice.

---

No findings in:
- `kit/scripts/preship/roster-check.sh` — scope-variable parsing matches SKILL.md format, expected-roster derivation mirrors the original inline code exactly, SKIP.md validation is correctly case-sensitive with known-valid allowlist, `set -euo pipefail` interacts safely with the `[ -n "$VAR" ] && ...` pattern.
- `kit/scripts/preship/check-llm-mediated-na.sh` — awk is confirmed mawk-portable (no `\b`), `($|[^a-z-])` anchoring correctly rejects `/qa-walk` and matches `/qa` at end-of-line, verified against mawk 1.3.4 explicitly.
- `.claude/skills/devshop/build/SKILL.md` changes — script calls pass correct arguments, retry-on-failure pattern is sound, inline code fully replaced (no leftover duplicates).
- `kit/docs/guide/migrations.md` — all 4 FK rollback patterns are technically correct: Pattern 1 (`IF EXISTS` guard on child table drop), Pattern 2 (migration-number suffix), Pattern 3 (`CASCADE` for policies), Pattern 4 (`DO $$ ... IF EXISTS` for conditional `ALTER TABLE`).

## Dismissals

None

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself)

## Dismissals

None

## Gate 8: /design-review

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface)

## Dismissals

None

## Gate 8b: design-conformance

- Result: n/a (devshop-self-mode: no DESIGN.md)

## Dismissals

None

## Gate 9: /qa

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface; bats invariants are the test surface and run in Gate 2d)

## Dismissals

None

## Gate 10: /benchmark

- Result: blocked (n/a per scope: devshop-self-mode — no perf surface)

## Dismissals

None

## Gate 10b: preflight-final

- Result: n/a (devshop-self-mode: bats recheck in Gate 2d covers this)

## Dismissals

None

## Gate 11: convention

- Result: pass

### Checks performed

1. **Shell script structure** -- All 3 new scripts (`local-env-health.sh`, `roster-check.sh`, `check-llm-mediated-na.sh`) have `#!/usr/bin/env bash` shebang, `set -euo pipefail`, 3-line header (`# What:` / `# Why:` / `# Does NOT:`), and spec reference comment.

2. **Bats test files exist** -- Corresponding test files present for all 3 scripts: `preship-local-env-health.bats`, `preship-roster-check.bats`, `util-check-llm-mediated-na.bats`.

3. **Guide docs routing index** -- No new guide docs added; `kit/docs/guide/README.md` alphabetical file list matches the 19 guide files on disk. No update needed.

4. **POSIX compatibility** -- New scripts are bash-only (`#!/usr/bin/env bash`), invoked via `bash "$SCRIPT"`, and not referenced from `.husky/` hooks (which run under `sh`/dash). No dash-incompatible patterns in POSIX-required paths.

5. **Conventional commits** -- All 11 commits follow `type(scope): description` format with valid types (`feat`, `fix`, `docs`, `chore`), under 72 chars, describing observable changes.

## Dismissals

None


## Phase 3 → 4 advance log

### 2026-05-27T20:46:04Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T20:46:04Z -->

### 2026-05-27T20:46:04Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T20:46:04Z -->

### 2026-05-27T20:46:04Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants are the test surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T20:46:04Z -->

### 2026-05-27T20:46:04Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T20:46:04Z -->

## Audit 2: manual (2026-05-27)

<!-- audited-at: 8f9624cd18b4dcd9dcfe802b19e1be3a68a28c66 -->
<!-- range: 23518d9504164240972a4e8dd0c345f63c1860d7..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none)

### Tests findings

- (none)

### Bypass trailer audit

- (none)
