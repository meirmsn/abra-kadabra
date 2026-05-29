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
