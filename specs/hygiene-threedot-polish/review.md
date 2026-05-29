<!-- audited-at: 54162cc56944756434efe38890f74a586b712900 -->
# Pre-ship review — hygiene-threedot-polish (devshop mode)

## Router Summary

- Dispatched gates: docs-check, fast-job-local (bats), simplify, docs-and-tests-review, review, convention — all **pass**.
- Carve-outs (n/a, non-LLM): metrics-check, rls-coverage, slow-job-lifecycle, changed-tests-local, advisor-clean, responsive-theme, design-conformance, preflight-final, migration-rollback-roundtrip.
- Structural blocked (LLM-mediated, n/a per scope — see advance log): cso, design-review, qa, benchmark.
- Findings pending: 0. Real blocked: 0. No LLM-mediated gate marked bare n/a.

---

## Gate 1: docs-check

- Result: pass

The diff IS documentation (kit/docs/guide/workflow.md cross-ref clause +
kit/docs/guide/hooks.md NOTE 3) plus a paired test change. No script/tooling
change (adversarial-review.sh untouched), so the "every tooling change ships
doc updates" rule is N/A here — there is no behavior to document beyond the
docs themselves. Cross-ref target (hooks.md § Dual-surface check-types) exists
and resolves. Doc coverage adequate.

## Dismissals

None

## Gate 2: metrics-check

- Result: n/a (devshop-self-mode: no METRICS.md in devshop)

## Dismissals

None

## Gate 2b: rls-coverage

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 2c: slow-job-lifecycle

- Result: n/a (devshop-self-mode: no slow-job CI)

## Dismissals

None

## Gate 2d: fast-job-local (adapted — bats)

- Result: pass

`kit/tests/lib/bats-core/bin/bats kit/tests/` — full suite green (0 not-ok,
1528 ok) at merged HEAD. Includes the hardened test 18 (util-adversarial-
review-narrowing.bats) and the Phase 6 test 14 fix pulled in from origin/main
via the base-sync merge.

## Dismissals

None

## Gate 2e: migration-rollback-roundtrip

- Result: n/a (devshop-self-mode: no migrations)

## Dismissals

None

## Gate 2f: changed-tests-local

- Result: n/a (devshop-self-mode: bats run in Gate 2d covers this)

## Dismissals

None

## Gate 2g: advisor-clean

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 3: responsive-theme

- Result: n/a (devshop-self-mode: no UI surface)

## Dismissals

None

## Gate 4: /simplify

- Result: pass

Quality pass over the 3-edit delta. The two doc edits are prose additions
matching surrounding bold-led-NOTE / dense-table-row style. The test-18
assertion uses the minimal correct mechanism (awk region extraction between
the `empty means none:` header and the `Squash body contains an` line +
whitespace-only check) — deliberately chosen over the weaker static-boilerplate
grep (decision D2; rationale documented inline in the test). No simplification
opportunities; no over-engineering. adversarial-review.sh unchanged.

## Dismissals

None

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

## Gate 6: /review

Scope: 3 substantive edits (PLAN.md/specs bookkeeping ignored).

1. `kit/docs/guide/workflow.md` — `/ak-merge-devshop` skill-map row gained a clause on Phase 0.4.5 dimension-(d) three-dot precompute.
2. `kit/docs/guide/hooks.md` — `NOTE 3` description added to § Dual-surface check-types (count `two` → `three` NOTE blocks).
3. `kit/tests/util-adversarial-review-narrowing.bats` — test 18 gained a positive "`$PROP_SURFACES` region is empty" assertion.

### Verdict: pass — no correctness, accuracy, or trust-boundary findings.

Verification performed against `kit/scripts/adversarial-review.sh` (the code the docs describe):

- **Doc accuracy — hooks.md NOTE 3.** Claims verified line-by-line:
  - Three-dot precompute `git diff --name-only origin/main...$HYG_BRANCH` — matches source line 370.
  - Propagation-surface regex (`template/` | `kit/scripts/` | `kit/hooks/` | `.devcontainer/` | `manifest.txt`) — matches source line 371 exactly; all five surfaces present in both doc and regex.
  - Two-dot phantom-FAIL rationale and the `template/.gitignore` (docs/csp-img-src, 2026-05-28) worked incident — matches the source comment at lines 357-365.
  - Fix-commit attribution `b174a11` — confirmed via `git log` (`fix(hygiene): no phantom propagation-block flag on diverged squashes`).
  - Block-presence regex `^\*\*Existing projects:\*\*` — matches source line 373.
  - NOTE count narration ("two" → "three inlined NOTE blocks") — consistent with source NOTE 1/2/3 at lines 394/407/417.

- **Doc accuracy — workflow.md clause.** "Phase 0.4.5's precompute fires BEFORE the rebase" verified: Phase 0.4.5 is the compose-time hygiene check inside Phase 0; the rebase is Phase 1.0 (SKILL.md lines 522, 633-636) — 0.4.5 precedes 1.0. "diffs `origin/main...$BRANCH`, not two-dot" matches source line 370 (`$BRANCH` is readable shorthand for the `$HYG_BRANCH` / `DEVSHOP_HYGIENE_BRANCH` variable, consistent with the SKILL's own Phase 0.2 reference). Cross-ref target `kit/docs/guide/hooks.md § Dual-surface check-types` exists. `b174a11` attribution matches.

- **Test correctness — bats test 18 new assertion (non-vacuous, boundary-accurate).**
  - awk start anchor `/empty means none:/` matches the emitted header at source line 389; the literal "empty means none:" appears exactly once in the prompt source (case-sensitive; NOTE 3's `NON-EMPTY`/`EMPTY` at lines 418/427 do not match).
  - awk end anchor `/^Squash body contains an/` is line-anchored and unique (one occurrence, source line 392).
  - The captured region between the two anchors is precisely `$PROP_SURFACES` (line 390) plus the trailing blank line (391); `tr -d '[:space:]'` + `[ -z ... ]` correctly asserts the rendered surface list is whitespace-only. On the base-diverged README-only branch (test fixture, lines 318-343), three-dot yields an empty `PROP_SURFACES`, so the assertion holds.
  - Non-vacuity confirmed: a differently-broken three-dot emitting any phantom path (not just `template/.gitignore`) would make the region non-empty and fail the assertion — strictly stronger than the pre-existing filename-absence grep. The test comment correctly warns against substituting the static NOTE 3 boilerplate (`If the list is EMPTY`), which has zero discriminating power.
  - Full suite executed: 23/23 pass, including test 18.

- **SQL / LLM-trust-boundary / conditional-side-effects:** none applicable (docs + test only; no new code paths, no user-input interpolation into SQL or shell beyond the already-shipped `git diff` precompute).

## Dismissals

None

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself)

## Dismissals

None

## Gate 8: /design-review

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface)

## Dismissals

None

## Gate 8b: design-conformance

- Result: n/a (devshop-self-mode: no DESIGN.md)

## Dismissals

None

## Gate 9: /qa

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface; bats invariants are the test surface and run in Gate 2d)

## Dismissals

None

## Gate 10: /benchmark

- Result: blocked (n/a per scope: devshop-self-mode — no perf surface)

## Dismissals

None

## Gate 10b: preflight-final

- Result: n/a (devshop-self-mode: bats recheck in Gate 2d covers this)

## Dismissals

None

## Gate 11: convention (devshop)

- Result: pass

- SKILL.md frontmatter: no skills changed — N/A.
- Shell script structure: no scripts changed (adversarial-review.sh untouched) — N/A.
- Guide docs linked in routing index: workflow.md + hooks.md are existing,
  already-indexed guide docs; edits only, no new doc files — N/A.
- Bats test files exist for new scripts: no new kit/scripts/ — N/A; the change
  IS a bats test improvement.
- Commit + PR text style: per-task commits follow conventional-commit subjects;
  squash subject will be composed at merge time.

## Dismissals

None

## Phase 3 → 4 advance log

### 2026-05-29T06:15:50Z — Gate 7

**Gate:** Gate 7
**Reason:** devshop-self-mode — gate structurally inapplicable;  /cso:no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T06:15:50Z -->

### 2026-05-29T06:15:50Z — Gate 8

**Gate:** Gate 8
**Reason:** devshop-self-mode — gate structurally inapplicable;  /design-review:no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T06:15:50Z -->

### 2026-05-29T06:15:50Z — Gate 9

**Gate:** Gate 9
**Reason:** devshop-self-mode — gate structurally inapplicable;  /qa:no UI surface; bats invariants run in Gate 2d
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T06:15:50Z -->

### 2026-05-29T06:15:50Z — Gate 10

**Gate:** Gate 10
**Reason:** devshop-self-mode — gate structurally inapplicable;  /benchmark:no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T06:15:50Z -->

