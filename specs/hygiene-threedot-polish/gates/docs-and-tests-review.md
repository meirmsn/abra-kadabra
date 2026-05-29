## Gate 5: docs-and-tests-review

Range: `origin/main...HEAD` on `feat/hygiene-threedot-polish`. Substantive delta = 3 files
(hooks.md NOTE 3, workflow.md cross-ref clause, bats test 18). PLAN.md / specs/* bookkeeping
and the merge-pulled origin commits (CSP docs, ak-build test, merge commit 54162cc) ignored.

findings: high=0 medium=0 low=0

### DOCS

Verified, all clean:

- **Cross-ref target exists.** `hooks.md § Dual-surface check-types` is a real heading
  (`kit/docs/guide/hooks.md:486`, `#### Dual-surface check-types`). The new workflow.md:488
  clause cites it; CLAUDE.md, conventions.md (×3), and the prior hooks.md prose also cite the
  same heading. No dangling cross-ref.
- **NOTE 3 description is accurate against the implementation.** `adversarial-review.sh:370`
  precomputes `PROP_SURFACES` via three-dot `git diff --name-only "origin/main...$HYG_BRANCH"`
  (NOT two-dot) — exactly as the prose states. The propagation regex at line 371
  (`'^(template/|kit/scripts/|kit/hooks/|\.devcontainer/)|(^|/)manifest\.txt$'`) matches the
  doc's listed surfaces (`template/**` / `kit/scripts/**` / `kit/hooks/**` / `.devcontainer/**`
  / `manifest.txt`). The worked-incident citation (docs/csp-img-src, 2026-05-28, phantom-FAILed
  on `template/.gitignore`, codified `b174a11`) matches the in-script comment (lines 360-369)
  and the real commit (`b174a11 fix(hygiene): no phantom propagation-block flag on diverged
  squashes`, which touches adversarial-review.sh + the bats file). Both doc citations of
  `b174a11` are correct.
- **NOTE-count consistency holds.** hooks.md now says "three inlined NOTE blocks" (the b32dd42
  fix is in-branch at the top of HEAD's history). Repo-wide grep for "two inlined NOTE" /
  "two NOTE block" / "NOTE 1 and NOTE 2" returns zero stragglers. No sibling NOTE-count
  statement was invalidated.
- **No sibling doc invalidated.** SKILL.md § 0.4.5 (lines 522-545) describes dimension (d)'s
  presence check at a higher abstraction and never asserts two-dot vs three-dot, so it is not
  made stale by the new prose. CLAUDE.md § Known Footguns and conventions.md § Existing-Project
  Migration Block describe (d) without the precompute internal — also untouched and consistent.
- **workflow.md clause is coherent.** It correctly frames Phase 0.4.5's three-dot precompute as
  a *complementary* base-divergence remedy that fires BEFORE the Phase 1.0 rebase ("not the
  sole remedy"), which is accurate: 0.4.5 runs at compose time, before Phase 1's rebase, and
  carries its own three-dot fix. The diff (`origin/main...$BRANCH`, codified `b174a11`) matches
  the implementation.

### TESTS

Verified, all clean:

- **Test 18 assertion is adequate and positively pins dimension-(d) N/A.** The new assertion
  extracts the rendered `$PROP_SURFACES` region via
  `awk '/empty means none:/{f=1;next} /^Squash body contains an/{f=0} f'` and asserts it is
  whitespace-only (`tr -d '[:space:]'` then `-z`). This is strictly stronger than the
  pre-existing `grep -qF "template/.gitignore" → assert_failure` (which only catches the ONE
  known phantom filename — a differently-broken three-dot emitting a *different* phantom path
  would slip past the filename grep but fail the empty-region check). The inline comment
  correctly documents why `grep "If the list is EMPTY"` is NOT a valid substitute (that literal
  is static NOTE 3 boilerplate at adversarial-review.sh:427, emitted unconditionally → zero
  discriminating power).
- **awk boundary is correct vs the real prompt.** Both anchors are unique in the script:
  start `empty means none:` matches only line 389 (skipped via `next`), end
  `^Squash body contains an` matches only line 392. The captured region is exactly line 390
  (`$PROP_SURFACES`, empty on this base-diverged branch) + line 391 (blank) — whitespace-only,
  so the assertion passes for a genuinely-empty surface list and would fail if any phantom path
  rendered.
- **No untested new behavior.** The delta is itself a test improvement + docs; the underlying
  three-dot behavior is exercised by test 18's existing `template/.gitignore`-absence check
  plus the new positive empty-region check, and by sibling tests 15-17 (surface-touched → FAIL,
  no-surface → N/A, surface+block → yes). Full suite run: all 23 tests in
  `util-adversarial-review-narrowing.bats` PASS, including the modified test 18.

## Dismissals

None.
