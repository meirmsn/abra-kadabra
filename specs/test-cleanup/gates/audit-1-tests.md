# Audit 1 — Tests Review

**Range**: `origin/main..HEAD` (1 commit: `edb614d`)
**Feature dir**: `specs/test-cleanup`
**Scope**: cosmetic test cleanup of 2 low-severity Audit 2 findings from the just-merged template-ci-overhaul branch. No source changes.

## Files in scope

- `kit/tests/preship-slow-job-lifecycle.bats` (+8 / -4) — rename + recomment the multi-gap test so its description matches the four findings the gate emits.
- `kit/tests/template-ci-yml-shape.bats` (+3 / -4) — drop a dead `run bash -c …` line that never saw the `job_body` setup() function; inline extract is the assertion that actually runs.

## Section A — Coverage of new behavior

No source changes in the range. Both touched tests still exercise the same script-level behavior they covered pre-change (multi-finding aggregation in `preship-slow-job-lifecycle.sh`; the `changes:` job's `actions/checkout@v4` pin in the template `ci.yml`). No coverage rubric entry triggers — no new wrapper, no new RPC, no new edge function, no new script.

Result: no findings.

## Section B — Test quality

### Weak assertions

- `template-ci-yml-shape.bats:65` — `echo "$body" | grep -qE '^[[:space:]]+- uses: actions/checkout@v4'`. Concrete regex match against the extracted job body, not a `toBeDefined`-shaped sniff. Bats success-exit semantics give the assertion. Pass.
- `preship-slow-job-lifecycle.bats:624-627` — four `assert_output --partial` matchers against distinct finding-text fragments (`"findings"`, `"missing edge-runtime health-check retry"`, `"doesn't invoke them"`, `"empty-state guard"`). Each fragment names the specific failure mode being verified. Pass.

### Missing error/invalid input tests

N/A — neither test introduces a new wrapper or new throw path.

### Untested auth boundaries (RLS)

N/A — devshop-side bats tests, no RLS surface.

### Implementation detail tests

Neither change couples to a new internal. Both tests still assert against the script's stdout contract, which is the user-visible surface that the pre-ship gate operator reads.

### Missing boundary conditions

The multi-gap test deliberately exercises a 4-finding boundary (max-currently-defined). The recomment now documents WHY the test omits a count assertion (forward-compat with future Check additions), which is the correct trade-off — robustness over precision when the gate is intentionally extensible.

### Shape-only assertions

N/A — bats `assert_output --partial` matches against script stdout, which IS the user-visible output. No DOM pairing required.

### Skipped tests audit

Diff scan for `\b(test|describe|it|@test)\.(skip|only)\b` and bats equivalents (`skip ` line): no matches added.

### Wrapper-API / runtime-validation / WebKit / realtime rubrics

N/A — no `packages/core/src/api/**` touched, no Playwright tests touched, no realtime subscribers introduced.

### Test name / comment accuracy

This is the central improvement in the diff:

- `preship-slow-job-lifecycle.bats:592` — old name claimed "three findings" but the gate emits four. New name + comment correctly enumerate Check 3 (retry stripped), Check 5 (integration-glob), Check 4 (Playwright guard), Check 4 (migration guard) and explicitly note that the `empty-state guard` partial covers the latter two as a pair. Net positive for future-reader debuggability.
- `template-ci-yml-shape.bats:60-62` — the dead `run bash -c "…"` line was a no-op (subshell couldn't see the `job_body` function defined in `setup()`). Removing it eliminates a misleading red-herring for anyone reading the test in failure-investigation mode. The retained inline-extract is the load-bearing assertion. Net positive.

Both edits improve correctness of test self-description without altering coverage. No findings.

## Section C — Bypass trailer audit

Harvest:

```
git log --format='%H%n%B%n---' origin/main..HEAD | grep -i 'tests-coverage-bypass'
→ no matches
```

Zero `Tests-Coverage-Bypass:` trailers in range. Section is empty (forward-compatible per the rubric).

## Findings

Tests look solid — no findings.

## Severity tally

- high: 0
- medium: 0
- low: 0
