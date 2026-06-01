Tests look solid — no findings.

---

## Audit context (for the record — not a finding)

**Range**: `bf1cb7acfba628b16c12bc62893e2c66dce660a8..4f336fa`
**Diff**: 1 file, +1/-1 — `kit/tests/structural-invariants.bats`. Adds `audit-tracker-only.sh` to the `infra_scripts` allow-list in the `wiring: every non-exempt kit script is wired into a hook or pre-commit` test.

**Section A (coverage of new behavior)**: N/A — the diff modifies a test, not source. No new `kit/scripts/**.sh` or skill surface introduced in-range that would require a new test pair. The script being registered (`kit/scripts/preship/audit-tracker-only.sh`) is from a prior PR and already has its behavior spec (`kit/tests/util-audit-tracker-only.bats`, 14 cases, all green).

**Section B (test quality)**: No findings on the modified line. The unanchored `grep -q "$script"` match at structural-invariants.bats:261 is a pre-existing design (untouched by this diff) and is therefore out of scope per the "do not re-flag grandfathered tests in untouched files" rule. Verified no substring collision: `audit-tracker-only.sh` is not a substring of any other kit script basename, so the loose match cannot cause a false-negative for this entry.

**Section C (bypass trailers)**: zero rows harvested in-range.

**Verification performed**:

- The registered script is genuinely skill-invoked, not hook-wired — confirmed it is referenced from `.claude/skills/devshop/check-docs-and-tests/SKILL.md` (`bash kit/scripts/preship/audit-tracker-only.sh "$RANGE"`) and NOT from `.claude/settings.json`, `kit/hooks/pre-commit.sh`, or either `prepare-commit-msg`. This matches the sibling rationale (`check-llm-mediated-na.sh`, `roster-check.sh`) for belonging in `infra_scripts`.
- Change is load-bearing (not a no-op): reverting the added entry makes the wiring test FAIL, listing `audit-tracker-only.sh` as "not wired into any hook or pre-commit chain"; with the entry, the test PASSES.
- The wiring test's recursive `find` over `kit/scripts/` correctly discovers the script under the `preship/` subdir.
- Both affected specs run green: `util-audit-tracker-only.bats` (14/14) and the touched wiring test (1/1).
