findings: high=0 medium=0 low=1

### Tests findings

- [low] kit/tests/structural-invariants.bats:234 — Widening the `infra_scripts`
  allow-list in the "every non-exempt kit script is wired" meta-test trades a
  false positive for a small, permanent loss of coverage: if a future edit ever
  re-wires `reconcile-task-commits.sh` into a hook, or the script is deleted, the
  exemption silently becomes stale and the test will no longer flag it. This is
  inherent to every entry on the list (30+ siblings share the risk) and is the
  correct trade here — but no mechanism asserts that listed exemptions still
  exist / are still genuinely unwired. Optional hardening (devshop backlog, not
  this PR): have the wiring test assert each `infra_scripts` entry names a file
  that exists under `kit/scripts/` and is NOT grep-matched in `kit/hooks/` /
  `.husky/`, so a stale exemption fails loudly. Recording as low; the fix itself
  is correct.

Verification performed (grounds the verdict):
- Exemption claim is true: `reconcile-task-commits.sh` exists under
  `kit/scripts/`, is referenced by `.claude/skills/devshop/build/SKILL.md` and
  `.claude/skills/devshop/implement/SKILL.md` (skill prompts), and has ZERO
  references in `kit/hooks/` or `.husky/`. It is legitimately not hook-wired, so
  the exemption is correct rather than a mask over a real wiring gap.
- The script's own behavior is independently covered by
  `kit/tests/util-reconcile-task-commits.bats` — the exemption does not remove
  coverage of the script itself, only of the meta-wiring assertion.
- Re-ran the full `structural-invariants.bats` suite: test 12 ("every non-exempt
  kit script is wired into a hook or pre-commit") now passes; 0 failures across
  the suite. The change achieves its stated goal of greening main, which had
  been red on a full-suite run since ca4bc76.
- No new test was needed: this is a one-line allow-list addition to an existing
  meta-test, with a rationale comment matching the neighboring entries' pattern.
