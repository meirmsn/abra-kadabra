### [domain: tests] [section: A] [severity: medium]

**File**: `kit/tests/preship-fault-injected-qa.bats:200-218`
**What**: `cmd_run`'s Playwright invocation paths — the `pass` outcome (surface detected + harness present + Playwright succeeds) and the `findings (N) — failed: <slug-list>` outcome (Playwright fails) are not exercised by any bats test. Only the scope-exempt `pass (no Tier A2 surfaces in scope)` and `blocked (missing fault-injected harness: ...)` paths are covered.
**Why**: The script's header explicitly documents `PLAYWRIGHT_BIN   override pnpm exec playwright (bats sets a stub).` — i.e., the env-var hook exists specifically to let bats stub Playwright. But no test uses it, so the orchestration code in `cmd_run` (per-surface loop, `mkdir -p` of `gates_dir`, JSON-output redirection to `specs/<feature>/gates/fault-injected-<slug>.json`, exit-code aggregation into `fail_count` / `fail_detail`, final outcome line emission) ships untested. A regression in slug iteration, the `IFS=', '` join (which produces `, `-separated output, not `,`-separated as the docs imply), or the JSON output path is silent until first project use. Spec § Tests defers these paths as "would require headed Chromium" — but stubbing `PLAYWRIGHT_BIN=/bin/true` (pass path) or `PLAYWRIGHT_BIN=/bin/false` (fail path) needs no Chromium at all. The spec's stated rationale doesn't match what the script's own env-var hook enables.
**Fix**: Add two bats tests using `PLAYWRIGHT_BIN`:
```bash
@test "run: emits pass when Playwright stub succeeds for every surface" {
  write_spec_with_table "| AddItem | A2 | hook |"
  touch "$WORK/apps/web/e2e/fault-injected/add-item.spec.ts"
  PLAYWRIGHT_BIN=/bin/true run bash "$SCRIPT" run --feature foo --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  # Last line is the outcome; should be exactly "pass" (not scope-exempt).
  [[ "${lines[-1]}" == "pass" ]]
  # Per-surface JSON written under specs/foo/gates/.
  [ -f "$WORK/specs/foo/gates/fault-injected-add-item.json" ]
}

@test "run: emits findings when Playwright stub fails for a surface" {
  write_spec_with_table "| AddItem | A2 | hook |" "| EditRow | A2 | hook |"
  touch "$WORK/apps/web/e2e/fault-injected/add-item.spec.ts" \
        "$WORK/apps/web/e2e/fault-injected/edit-row.spec.ts"
  PLAYWRIGHT_BIN=/bin/false run bash "$SCRIPT" run --feature foo --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  assert_output --partial "findings (2)"
  assert_output --partial "add-item"
  assert_output --partial "edit-row"
}
```
Either land the stub-based coverage or rewrite the spec § Tests note to match what's actually true (the stub hook is unused; coverage genuinely deferred to first live project run).

### [domain: tests] [section: B] [severity: medium]

**File**: `kit/tests/preship-fault-injected-qa.bats:87-93`
**What**: The `detect-surfaces: emits empty route when no annotation present` test uses a disjunctive shape assertion: `[[ "$output" == *$'\t' ]] || [[ "$output" == *$'\thook\t' ]]`. The test passes if EITHER pattern matches — so the test cannot fail in the way the assertion suggests, and doesn't pin down the actual output format.
**Why**: A regression that swaps trailing-tab vs `\thook\t` formatting would pass the test silently. The whole point of this test is to verify the route-hint column is empty when no `[route:...]` annotation is present — but the assertion lets either format slide. If parsing changes to drop the notes column entirely or add stray whitespace, this test will not catch it.
**Fix**: Pin the exact expected output. The parser emits `<slug>\t<notes>\t<route>`; with `notes="hook"` and no route annotation, the line should be exactly `save\thook\t`:
```bash
[[ "$output" == $'save\thook\t' ]]
```
Or use `assert_equal "$output" $'save\thook\t'` for a clearer diff on failure.

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/preship-fault-injected-qa.bats:175-181`
**What**: `verify-harness: exits non-zero with missing slugs on stderr` asserts on `"$output"`, which in bats by default merges stdout+stderr — the test does not actually verify the missing-slug list went to **stderr** as the script header's contract requires (`Exit non-zero with comma-separated missing slugs on stderr otherwise`).
**Why**: A regression that prints the missing list to stdout instead of stderr would still pass this test. Downstream callers (like `cmd_run` parsing `2>&1` capture) depend on the stderr placement; a silent stdout/stderr swap is invisible to this test.
**Fix**: Use bats' `--separate-stderr` mode or redirect explicitly:
```bash
@test "verify-harness: exits non-zero with missing slugs on stderr" {
  touch "$WORK/apps/web/e2e/fault-injected/a.spec.ts"
  run --separate-stderr bash "$SCRIPT" verify-harness --slugs a,b,c --root "$WORK"
  assert_failure
  [[ "$stderr" == *"b,c"* ]]
  [ -z "$output" ]   # nothing on stdout
}
```

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/preship-fault-injected-qa.bats` (no test for `--diff-range`)
**What**: The `--diff-range` argument to `detect-surfaces` and `run` (which scopes the grep fallback to TS/TSX files in the supplied git range) is not exercised by any test. Its 12-line code branch in `grep_useoptimistic_callsites` (the `if [ -n "$diff_range" ]; then ... git diff --name-only ... fi` block) ships untested.
**Why**: A misquoted glob, a wrong `--diff-filter` flag, or a quoting break that lets the diff-range path swallow non-TS files is invisible until first real-project use. The diff-range path is the production hot-path for `/ak-build` (where the gate runs per-PR with a known base) — the full-tree scan is only the offline-debug fallback.
**Fix**: Add a test that initializes a real git repo inside `$WORK` (already done in `setup()`), commits a baseline, then adds a new `useOptimisticMutation({ failureMode: 'banner' })` call site, and verifies `detect-surfaces --diff-range HEAD~1..HEAD` picks up only the new file (not pre-existing call sites in the baseline).

### [domain: tests] [section: C] [severity: low]

**File**: n/a
**What**: No `Tests-Coverage-Bypass:` trailers in the commit range.
**Why**: Section C harvest is empty — the bypass mechanic isn't active for this PR. No action needed; logged for completeness.
**Fix**: n/a
