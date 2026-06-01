### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/util-audit-tracker-only.bats` (D2 matrix)
**What**: The classifier's tracker prefix-globs (`kit/TODOS*`, `kit/ROADMAP*`, `kit/version*`) have no negative boundary test proving they do not over-match a non-tracker path that merely shares the prefix (e.g. a hypothetical `kit/versioning-guide.md` or `kit/TODOS-archive/notes.md`). The matrix tests the exact tracker paths and clearly-source paths, but not the prefix-glob seam.
**Why**: A future file named with one of these prefixes would be silently classified tracker-only and skip its audit. The risk is currently theoretical (no such files exist) and the `*` on `kit/version*` is deliberate (kit/version has no extension, documented at script line 22), so this is a latent edge, not a live bug.
**Fix**: Add one case asserting a prefix-adjacent non-tracker path (e.g. `two_commit_diff kit/versioned-thing.md` if such a path should audit) resolves to exit 1 — OR record in the spec that the prefix over-match is an accepted trade-off. Non-blocking; recorded for the next audit window.

<!-- Reviewer notes (not findings; audit trail):
- Section A coverage VERIFIED: new kit/scripts/preship/audit-tracker-only.sh is paired by kit/tests/util-audit-tracker-only.bats (9 cases, all green this run). The cases exercise NEW behavior — tracker-only/exit-0, mixed/exit-1, pure-source/exit-1, guide-doc/exit-1 (the load-bearing "guide docs are auditable" rule), test-only/exit-1, friction-log/exit-0, empty/exit-0, usage-error/exit-64, unresolvable-range/exit-1. Not mere file pairing.
- The SKILL.md Step-1 change is covered by util-check-docs-and-tests.bats's new grep test (asserts helper name + short-circuit message + WITHOUT-scaffolding behavior + BEFORE-the-substep-6 ordering) — appropriate for a doc/skill surface.
- Assertion depth is strong: specific exit codes (assert_failure 1 / 64, assert_success) + assert_output --partial on the verdict string. No toBeTruthy-class weak assertions.
- The exit-1-on-unresolvable-range bug fix (bcfd847) landed WITH its confirming bats case in the same commit (no code-without-test). VERIFIED.
- No skip/.only patterns in the range. No WebKit/realtime/wrapper/LLM-boundary surfaces (devshop bash + markdown only) — those Section B sub-checks are N/A.
-->

### Section C — Bypass trailer audit

- `411a3c1` Tests-Coverage-Bypass: "Test file kit/tests/util-audit-tracker-only.bats IS staged in this commit and pairs audit-tracker-only.sh (8 green cases), but check-tests-coverage-devshop.sh hardcodes TESTS_DIR=/devshop/kit/tests and can't see worktree-only bats files; this is a worktree-awareness gap in the hook, not a missing test." — **VERIFIED**. Confirmed: the paired `.bats` is present at HEAD and all cases pass (re-ran this audit: 9/9 green incl. the later unresolvable-range add). The bypass is load-bearing (worktree-blind hook, documented in the same branch's FRICTION-LOG entry + promoted to kit/TODOS) and remains valid — the test exists and is green; the hook simply can't see it from the canonical /devshop tree. Not a real coverage gap.
