### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/template-ci-yml-shape.bats:61`
**What**: Dead `run bash -c "echo \"\$(job_body changes)\" | grep -E ..."` line at the top of the `changes: job uses actions/checkout@v4` test. The `bash -c` subshell does not inherit the `job_body()` shell function defined in the bats setup scope, so the subshell errors out with `job_body: command not found`, `$status` is set to 1, and the captured `$output` is empty. The test author even left a comment immediately below the dead line acknowledging this: `# The above subshell call doesn't see the job_body function. Inline extract instead.` — but the dead line was committed anyway. The real assertion (lines 64-66) is the inline `body=$(job_body changes); echo "$body" | grep -qE ...` form, which DOES see the function and works correctly.

**Why**: Dead code in a test is two failure modes waiting to happen: (a) a future reader copy-pastes the dead pattern thinking it's load-bearing and propagates the broken-subshell idiom into a new test where the inline form below isn't present, silently shipping a no-op test; (b) the dead `run` line mutates `$status` / `$output` ahead of any future `assert_*` someone adds at the bottom of the test, producing confusing failures when the assertion sees the dead line's empty output instead of fresh state. Neither is happening today, but the residue is one careless edit away from a real bug. The companion test below (`changes: sets fetch-depth: 0 on checkout`, lines 69-77) is correctly structured with only the inline form — that's the canonical shape; line 61 is an editing accident left in.

**Fix**: Delete line 61 (the `run bash -c ...` form) and the explanatory comment on lines 62-63. The test body collapses to just the local-variable + inline-grep pattern that lines 69-77 already model:

```bats
@test "changes: job uses actions/checkout@v4" {
  # Pinned to v4 (matches fast-job; same constraint). Job-scoped so a
  # malformed changes-job that drops checkout entirely can't pass via the
  # fast-job's checkout matching the bare grep.
  local body
  body=$(job_body changes)
  echo "$body" | grep -qE '^[[:space:]]+- uses: actions/checkout@v4'
}
```

---

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/preship-slow-job-lifecycle.bats:592-622`
**What**: The multi-gap test's `@test` description and inline comment claim "Three findings should fire under the new check set", but running the gate against the fixture actually emits **four** findings — Check 3 (retry pattern stripped), Check 4 (Playwright hashFiles guard missing on content-less project), Check 4 (migration hashFiles guard missing on content-less project), and Check 5 (integration test invocation missing). The test still passes because it only `assert_output --partial`-matches three of the four messages and does not assert on a `findings (N)` count.

Reproduction: re-run the fixture against `slow-job-lifecycle-check.sh` — output is `findings (4)` with the migration-guard finding firing alongside the three the test claims to cover.

**Why**: Comment-vs-behavior drift creates wrong mental models for future maintainers. A reader who treats the comment as the contract will assume Check 4-migration is silent on this fixture (since only Playwright-guard is named), and will write the next fixture / new test believing migration-content-less is uncovered when it actually fires here. This was the exact failure mode Audit 1's HIGH-1 closed (stale assertions in this same file) — re-introducing it on the audit-fix commit is mild but the same shape.

**Fix**: Either (a) update the description + comment to name all four findings the fixture produces ("retry stripped + integration invocation missing + Playwright guard missing + migration guard missing"); OR (b) add `add_migration` to the fixture so the migration-guard finding does NOT fire and the comment's "three findings" becomes accurate. Option (a) is the lighter touch and exercises broader coverage in a single test.

---

### [domain: tests] [section: C] [severity: low]

**File**: bypass-trailer harvest over `5fb1abc..HEAD`
**What**: Zero `Tests-Coverage-Bypass:` trailers harvested from the audit-fixes commit (`9850786`) or the Audit 1 docs commit (`ed7c0e2`). No bypass to verify.

**Why**: Not a finding per se — the audit-fixes commit closes Audit-1 findings by adding tests, not by claiming a bypass. Noted for completeness.

**Fix**: None.

---

## Re-audit verification of Audit 1 findings

Verified that the audit-fixes commit `9850786` addresses every Audit 1 finding:

- **Audit-1 HIGH-1 (preship-slow-job-lifecycle.bats stale + missing Check 4/4b coverage)** — CLOSED. The bats spec was rewritten end-to-end. All 24 tests run green (`bats kit/tests/preship-slow-job-lifecycle.bats` → 24/24 ok). Specifically: the stale `"n/a (no integration tests or E2E specs"` assertion is gone; both stale `"predicate doesn't match canonical"` assertions updated to `"missing the"` + `"github.event_name == 'pull_request'"`; the rescoped Check 2 fixture now references `needs.changes.outputs.runtime` (line 234) so Check 2 actually fires; the legacy multi-gap test's `"findings (3)"` count assertion was dropped in favor of partial-match-on-each-finding pinning against the new check set; new tests cover Check 4 Playwright-guard-missing on content-less project (line 279), Check 4 migration-guard-missing on content-less project (line 317), Check 4 no-false-positive on legacy lalista/home-os shape with content + no guards (line 355), and Check 4b hashFiles-on-Start-local-Supabase ambient-signal regression (line 390).

- **Audit-1 HIGH-2 (structural-invariants.bats "all kit/scripts/*.sh tracked as 644" invariant violated by 755-mode scripts)** — CLOSED. Both scripts (`kit/scripts/preship/slow-job-lifecycle-check.sh` + `kit/scripts/preship/migration-rollback-roundtrip.sh`) are now tracked at mode 100644 in the worktree's index. The invariant test passes (`bats kit/tests/structural-invariants.bats` → test 43 `wiring: all kit/scripts/*.sh tracked as 644 (not 755)` ok). The commit body notes structural invariant #102 is now passing for the first time, having been a pre-existing failure on main due to the `migration-rollback-roundtrip.sh` mode regression.

- **Audit-1 MEDIUM-1 (Start local Supabase brittleness — read-only-next-line)** — CLOSED. The test now scans forward from `- name: Start local Supabase` until the next step boundary (next `- name:` at 6sp indent OR next job-level key at 2sp indent OR EOF) and refutes `if:[[:space:]]+hashFiles` over the whole step body. A benign `env:` block / comment / blank line inserted between `name:` and a later `if: hashFiles` directive no longer silently bypasses the guard. The new logic mirrors the gate's Check 4b scan shape, per Audit 1's recommendation.

- **Audit-1 MEDIUM-2 (`changes:` job assertions not job-scoped)** — CLOSED for the two highest-blast-radius assertions. A `job_body()` helper extracts the named job's body via awk (lines between `  <name>:` and the next 2-sp job-level key) and is now applied to `changes: job uses actions/checkout@v4` + `changes: sets fetch-depth: 0 on checkout`. The remaining unscoped assertions called out by Audit 1 (`node-version: '22'`, ignore-list case-arms) are not actually at risk of false-positive on the fast-job's match: `node-version: '22'` only appears under jobs that run pnpm (fast + slow, not changes), and the ignore-list case-arms only exist within the `changes:` job's classify-step shell body — no other job has a `*.md)` or `specs/**)` arm. The targeted fix is adequate.
