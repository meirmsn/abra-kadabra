### [domain: tests] [section: A] [severity: high]

**File**: `kit/tests/preship-slow-job-lifecycle.bats` (not modified in range)
**What**: `kit/scripts/preship/slow-job-lifecycle-check.sh` was substantially rewritten (new "active from day one" semantics; removed n/a path; new Check 4 / Check 4b; rescoped Check 2; new finding text), but the matching bats spec was NOT touched in this commit range. Multiple existing assertions will now fail and two new code paths have zero coverage.

**Why**: Test rot creates false confidence in two opposite directions: (a) stale tests fail on the next CI run and force a follow-up "fix the tests" PR that should have been part of this branch; (b) the new behavior introduced in Check 4 (empty-state `hashFiles` guards) and Check 4b (`Start local Supabase` must NOT carry a guard — ambient health signal) lands with zero regression coverage, so the next "tidy-up" PR that strips a guard or adds one to the wrong step ships silently.

Specific stale / missing assertions:

- Line 55: `assert_output --partial "n/a (no integration tests or E2E specs"` — the script removed the entire threshold-detection early-exit (lines 28–34 of old script). The "n/a (no integration tests or E2E specs ...)" string is no longer emitted; on an empty project the script now proceeds into Check 1 and produces findings. Test will fail.
- Lines 164 and 245: `assert_output --partial "predicate doesn't match canonical"` — the Check 2 finding string changed to `"slow-job 'if:' predicate is missing the \`github.event_name == 'pull_request'\` gate"`. Both tests will fail.
- Lines 149–165 fixture (`if: always()` without `needs.changes.outputs.runtime`) — Check 2 was rescoped to find the if: line that references `needs.changes.outputs.runtime` first, then assert on the pull_request gate. The fixture's `if:` line lacks that runtime reference, so `SLOW_IF_LINE` is empty and Check 2 produces no finding. The test that previously caught a broken `if:` predicate now silently passes Check 2 (other findings still fire, but the specific regression this test was guarding against is no longer covered).
- Lines 220–248 multi-gap test asserts `"findings (3)"` — with Check 2 now silently skipping on this fixture (no runtime reference in the if:), the count is likely off; needs re-pinning against the new shape.
- New Check 4 (empty-state `hashFiles` guards on Playwright steps and on type-drift/rollback) — no test fixtures cover the "guard absent on content-less project" finding nor the inverse "guards present on content-full project = pass" path.
- New Check 4b (`Start local Supabase` MUST NOT have a `hashFiles` guard — ambient health signal) — the only assertion of this invariant lives in `kit/tests/template-ci-yml-shape.bats` against the template file itself, NOT against the pre-ship gate's regression-guard logic. A project whose `ci.yml` drifts (operator adds a guard to the heartbeat step) is what Check 4b catches, and no bats covers that code path.

**Fix**:

1. Update line 55's fixture: drop the assertion entirely (no n/a path exists for "no integration / no E2E"), or replace with a fixture that asserts the script now produces a positive outcome on a content-less project + canonical-shape template (the pass path under the new semantics).
2. Update lines 164 and 245 to match the new Check 2 finding text: `"missing the \`github.event_name == 'pull_request'\` gate"`.
3. Refit the fixture at lines 149–165 so its slow-job's `if:` references `needs.changes.outputs.runtime` (otherwise Check 2 doesn't fire). E.g. `if: always() && needs.changes.outputs.runtime == 'true'`.
4. Re-pin the assertion at line 244 (`findings (3)`) against the rescoped Check 2 behavior on the lines 220–248 fixture.
5. Add tests for Check 4 (positive + negative for each glob: `apps/web/e2e/**/*.spec.ts` guard, `supabase/migrations/*.sql` guard, with `HAS_E2E` / `HAS_MIGRATIONS` both empty and non-empty).
6. Add a test for Check 4b: fixture with a `hashFiles` directive on the line immediately after `- name: Start local Supabase` → assert the "ambient signal" finding fires.

---

### [domain: tests] [section: A] [severity: high]

**File**: `kit/tests/structural-invariants.bats:619`
**What**: The "all kit/scripts/*.sh tracked as 644 (not 755)" invariant was reverted from worktree-aware (`git rev-parse --show-toplevel`) back to hardcoded `git -C "$DEVSHOP"` (= `/devshop` main). In the SAME branch, two scripts were chmod'd from 644 → 755 (`kit/scripts/preship/slow-job-lifecycle-check.sh` and `kit/scripts/preship/migration-rollback-roundtrip.sh`). Together, these two changes mean the bats test cannot detect the mode regression introduced by this branch — when bats runs in the worktree, it queries `/devshop` (still 644), while the worktree's index has the files at 755.

Verified:

```
$ git ls-files -s kit/scripts/preship/{slow-job-lifecycle-check,migration-rollback-roundtrip}.sh
100755 ...  kit/scripts/preship/migration-rollback-roundtrip.sh
100755 ...  kit/scripts/preship/slow-job-lifecycle-check.sh

$ git -C /devshop ls-files -s kit/scripts/preship/{slow-job-lifecycle-check,migration-rollback-roundtrip}.sh
100644 ...  kit/scripts/preship/migration-rollback-roundtrip.sh
100644 ...  kit/scripts/preship/slow-job-lifecycle-check.sh
```

**Why**: `init-devshop.sh` locks all `kit/scripts/*.sh` to 644 (per the test's own comment). Two scripts tracked as 755 contradict that invariant. The pre-overhaul version of this test would have caught it (correctly), so the revert isn't just dead weight — it's a regression that masks two violations shipping in the same branch.

**Fix**: Either (a) `git add --chmod=-x` both scripts to restore 644 — the test then passes against `/devshop` too, and the revert becomes truly inert; OR (b) restore the `git rev-parse --show-toplevel` resolution so the test catches the violation, and decide explicitly whether the two scripts should be 644 (consistent with the template-side `init-devshop.sh` lockdown) or 755 (deliberate exception, documented somewhere). Picking neither leaves the branch landing two silent invariant breaches.

---

### [domain: tests] [section: B] [severity: medium]

**File**: `kit/tests/template-ci-yml-shape.bats:204–212`
**What**: The "Start local Supabase has NO hashFiles gate" regression-guard test reads the line immediately after the step's `- name:` and refutes a `hashFiles` match on it. This is brittle to a benign refactor that inserts a blank line, a `# comment`, an `env:` block, or any other YAML key between `- name:` and the eventual `if:` — the test would silently pass even if a `hashFiles` guard is added two lines down.

**Why**: The intent (per the test's own comment) is to assert that the `Start local Supabase` step has NO `if: hashFiles(...)` anywhere in its step body, not just on the line immediately following `name:`. Today's YAML happens to put `run:` on the next line (no `if:` line at all), so the test passes. The instant someone adds an `env:` mapping under the step (a common, harmless edit), this guard goes silent.

**Fix**: Scan forward from `- name: Start local Supabase` until the next step boundary (next `- name:` at the same indent OR end of file), and refute `if:[[:space:]]+hashFiles` over the whole range. The same pattern is already used in `slow-job-lifecycle-check.sh § Check 4b` — keep the bats test in lockstep with the script's scope of inspection.

---

### [domain: tests] [section: B] [severity: medium]

**File**: `kit/tests/template-ci-yml-shape.bats` (multiple `@test` blocks)
**What**: Many positive assertions match generic patterns like `run grep -E '^[[:space:]]+- uses: actions/checkout@v4' "$CI_YML"` without scoping to the `changes:` job. The fast-job ALSO uses `actions/checkout@v4`, so a malformed `changes:` job that drops checkout entirely would still pass this test as long as the fast-job's checkout remains. Same problem on `fetch-depth: 0`, `node-version: '22'`, and the ignore-list case-arms which now appear once they're uncommented (was previously safe because the commented form was unique to the stub).

**Why**: The pre-overhaul shape made these tests sound — commented-form patterns (`^[[:space:]]+#[[:space:]]+...`) only matched the stub. Post-overhaul, the uncommented form matches indiscriminately across jobs. The test "changes: job uses actions/checkout@v4" can pass even if the `changes:` job has no `- uses: actions/checkout@v4` directive at all, because the fast-job satisfies the grep.

**Fix**: Use a job-scoped scan. Either (a) `awk '/^  changes:/{p=1} /^  [a-z]+:$/&&!/^  changes:/{p=0} p && /pattern/' "$CI_YML" | grep -q ...`; or (b) extract the `changes:` job into a temp file with the same awk, then grep it; or (c) at minimum, anchor each assertion to a line range that's known to belong to the `changes:` job. Without job-scoping, a future refactor that breaks the `changes:` job's internal shape can pass green.

---

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/template-compose-isolation.bats:179–183`
**What**: The supabase-port-allowance assertions were de-genericized — instead of matching the env-var form `--dport "$SUPABASE_API_PORT" -j ACCEPT`, the assertions now match the literal `--dport 54321 -j ACCEPT` / `--dport 54322 -j ACCEPT`. The matching default-value guards (`SUPABASE_API_PORT="${SUPABASE_API_PORT:-54321}"`, `SUPABASE_DB_PORT="${SUPABASE_DB_PORT:-54322}"`) were also removed.

**Why**: The pre-existing test asserted both the env-var indirection AND the default values, codifying the "env-aware Supabase ports" feature (`94de8d7`). The new test pins only the hardcoded literals. If the template moves back to env-var-aware ports (or rebinds defaults), the test passes only for the literal 54321/54322 shape and silently breaks the env-var indirection at the same time.

**Fix**: If env-aware ports are intentionally reverted in this branch, mention it in the spec / commit body (it's not obvious from the file paths touched). If not, restore the env-var form and the default-value guards — the prior test was load-bearing for the "env-aware Supabase ports" convention, and this branch's diff doesn't appear to walk that convention back deliberately.

---

### [domain: tests] [section: C] [severity: low]

**File**: bypass-trailer harvest over `origin/main..HEAD`
**What**: Zero `Tests-Coverage-Bypass:` trailers harvested from the range (commit messages `4592bb1` and `5fb1abc`). No bypass to verify.

**Why**: Not a finding per se — the bypass-trailer mechanic legitimately produces zero rows for branches that don't claim a bypass. Noting for completeness.

**Fix**: None.
