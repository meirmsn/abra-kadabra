### [domain: tests] [section: A] [severity: low]
**File**: kit/tests/util-reconcile-task-commits.bats
**What**: Test suite carries more cases than the spec's documented "9 cases" — case 6b (negative-control for bookkeeping exclusion) is an extra beyond the enumerated set.
**Why**: Not a coverage gap; the opposite — tests exceed spec. Carried forward from Audit 1's low=1 informational finding. The extra negative-control (case 6b) strengthens the exclusion guarantee.
**Fix**: None needed. Informational; the spec § Tests header could be updated to "10 cases" for bookkeeping accuracy, but this is cosmetic.

### Coverage / quality summary (Sections A-C)

- **Coverage (A)**: Complete. New `kit/scripts/reconcile-task-commits.sh` has a matching `kit/tests/util-reconcile-task-commits.bats` (12 bats cases, all passing). New wiring in `build/SKILL.md` (Step 0 rung 2 + Phase 2 note + resume-table row) and the `workflow.md` drift fix are each pinned by `util-ak-build-skill.bats` Section F (tests 37-42, all passing). The `implement/SKILL.md` done-means-committed prose is a reaffirmation of existing step-10/11 ordering (no new mechanic), adequately covered by the Section F assertions on the gate it references.
- **Quality (B)**: Strong. Assertions are on concrete exit codes (0/1/64) and specific diagnostic substrings (`done=3`, `impl-commits=2`, `no matching commit`, `dirty`) — no weak `toBeTruthy`-equivalents. Failure modes covered: dirty tree (case 3), count mismatch (case 2), all three usage-error paths (7a/7b/7c, exit 64). Boundary/robustness: rebase-rewrites-SHAs-preserves-count (case 5, the D3 invariant this feature exists to protect), bookkeeping-exclusion positive + negative control (case 6/6b), mawk-parity (case 8, guards the no-`\b` portability requirement), and the CRLF-strip regression sentinel (case 9) — case 9 explicitly asserts exit 1 to pin the fix (without the strip, done would undercount to 0 and falsely pass). The Section F skill-wiring tests scope greps to the correct doc region via `awk` range extraction rather than whole-file grep, so they fail correctly if the prose moves out of the resume-check region. Skipped-tests audit: no `.only` / `.skip` patterns in the diff. No realtime / WebKit / wrapper-boundary surfaces in range (devshop bats only).
- **Bypass trailers (C)**: No Tests-Coverage-Bypass trailers in range.
- **Empirical verification**: Ran both suites against HEAD — `util-reconcile-task-commits.bats` 12/12 pass; `util-ak-build-skill.bats` Section F (37-42) 6/6 pass.

findings: high=0 medium=0 low=1
