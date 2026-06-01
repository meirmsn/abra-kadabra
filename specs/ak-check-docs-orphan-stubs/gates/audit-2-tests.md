### [domain: tests] [section: A] [severity: medium]

**File**: `kit/tests/util-audit-tracker-only.bats` (covers `kit/scripts/preship/audit-tracker-only.sh:62-65`)
**What**: The classifier's `case` statement has four distinct tracker arms, but several individual tracker paths in the D2 contract are never exercised by any test. Tested: `PLAN.md`, `kit/TODOS.md`, `kit/version`, `kit/notes/*`, `kit/FRICTION-LOG.md`. **Never tested**: `BUILD-LOG.md`, `PRODUCT-ROADMAP.md`, `DEPS-WATCH.md` (the top-level docs arm — only `PLAN.md` from this 5-token arm is exercised), `kit/ROADMAP.md`, and most notably `kit/docs/CHANGELOG.md` (its own dedicated `case` arm at line 64, never hit).
**Why**: A regression that dropped or mistyped any of these arms would silently re-introduce orphan `review.md` stubs for that merge type (e.g. a CHANGELOG-only or PRODUCT-ROADMAP-only doc merge would stop short-circuiting and scaffold an orphan again) and CI would stay green. The `kit/docs/CHANGELOG.md` arm is the highest-value gap: the spec (`spec.md § D2`, lines 25, 367-368) flags it as the single trickiest boundary — it is the ONLY `kit/docs/` path treated as a tracker ("NOT all of `kit/docs/`"). The suite tests the non-tracker side of that boundary (`kit/docs/guide/workflow.md` → exit 1) but never the tracker side (`kit/docs/CHANGELOG.md` → exit 0), so a regression collapsing or widening the CHANGELOG arm is invisible.
**Fix**: Add tracker-side assertions for the unexercised arms, e.g.:

```bash
@test "kit/docs/CHANGELOG.md is a tracker (NOT all of kit/docs/) → exit 0" {
  two_commit_diff kit/docs/CHANGELOG.md
  run_audit "HEAD~1..HEAD"
  assert_success
  assert_output --partial "short-circuit"
}

@test "remaining top-level + kit trackers → exit 0" {
  two_commit_diff BUILD-LOG.md PRODUCT-ROADMAP.md DEPS-WATCH.md kit/ROADMAP.md
  run_audit "HEAD~1..HEAD"
  assert_success
}
```

### [domain: tests] [section: C] [severity: low]

**File**: commit `411a3c1` (`feat(preship): classify tracker-only audit ranges to skip orphan stubs`)
**What**: Carries a `Tests-Coverage-Bypass:` trailer claiming the test file `kit/tests/util-audit-tracker-only.bats` IS staged and pairs `audit-tracker-only.sh`, but `check-tests-coverage-devshop.sh` hardcodes `TESTS_DIR=/devshop/kit/tests` and can't see worktree-only bats files (a hook worktree-awareness gap, not a missing test).
**Why / verdict**: **VERIFIED.** `git show --stat 411a3c1` confirms `util-audit-tracker-only.bats` (+81 lines) was co-committed with `audit-tracker-only.sh` (+62 lines) in the same commit — the trailer's factual claim is accurate. The pairing test exists, is present in the final tree, and all 12 of its cases pass (re-ran the suite: 46/46 green across both bats files). The bypass was load-bearing (the worktree-blind hook would otherwise have blocked the commit) and remains valid given the current diff — no escalation. The underlying hook worktree-awareness gap is already recorded in `kit/FRICTION-LOG.md` (eb023b9) and is out of scope for this tests audit.

---

**Summary: high=0 medium=1 low=1**

Coverage of the verdict logic is solid: exact exit-code assertions (`assert_success` / `assert_failure 1` / `assert_failure 64`), output-content checks (`--partial "short-circuit"`, `--partial "Usage:"`), a real failure-path test (unresolvable/rewritten-history SHA → exit 1, guards against false short-circuit), and four regression guards beyond the spec's 8-case matrix (prefix-boundary over-match on `kit/versioning.md` / `kit/ROADMAPER` / `kit/TODOS-archive.md`, and `kit/notes/**` dir-prefix). No weak assertions, no `.only` / `.skip`, no shape-only concerns (bash CLI helper, no UI surface). The SKILL.md tracker-only short-circuit change is covered by a new `util-check-docs-and-tests.bats` doc-contract test (helper name, message, no-scaffold ordering). The one real gap is per-arm coverage of the D2 tracker set — most acutely the `kit/docs/CHANGELOG.md` boundary the spec itself names as the trickiest.
