# Tasks: hygiene-threedot-polish

Flat order (3 tasks). Devshop self-mode: test surface is bats; no METRICS.md, no vitest/Playwright.

## Task: workflow.md:488 cross-ref clause

**Hat**: PM (docs)
**Depends on**: none
**Blocks**: none
**Done when**: The `/ak-merge-devshop` skill-map row (line 488) carries a clause noting the Phase 0.4.5 dimension-(d) propagation-surface precompute fires BEFORE the Phase 1.0 rebase and got its own complementary three-dot fix (codified `b174a11`), so the rebase isn't the sole base-divergence phantom remedy; cross-refs `hooks.md § Dual-surface check-types`. Clause stays on the same logical table row (no hard line breaks).
**Risk**: low
**Status**: done (eb0bbd7)

## Task: hooks.md NOTE 3 description (cross-ref target)

**Hat**: PM (docs)
**Depends on**: none
**Blocks**: none
**Done when**: `hooks.md § Dual-surface check-types` prose paragraph (the one documenting NOTE 1 / NOTE 2) gains a NOTE 3 description in the same bold-led style recording: dimension (d) precomputes its propagation-surface list via three-dot `git diff --name-only origin/main...$BRANCH` (NOT two-dot `origin/main..$BRANCH`), why two-dot manufactures phantoms on a base-diverged branch, and the worked incident (docs/csp-img-src merge 2026-05-28 phantom-FAILed on `template/.gitignore`; codified `b174a11`).
**Risk**: low
**Status**: done (b927902)

## Task: bats test 18 positive surface-empty assertion

**Hat**: BE (test)
**Depends on**: none
**Blocks**: none
**Done when**: test 18 in `util-adversarial-review-narrowing.bats` adds a positive assertion that the rendered `$PROP_SURFACES` region of the captured prompt is whitespace-only (extracted via awk between the `empty means none:` header and the `Squash body contains an` line), with a comment explaining WHY it is not the static "If the list is EMPTY" boilerplate (D2). Test 16 untouched (D3). Bats file green.
**Risk**: low
**Status**: done (d8d899e)

## Decisions

(carried from spec — D1: cross-ref in both workflow.md + hooks.md; D2: assert rendered $PROP_SURFACES region empty, NOT the static "If the list is EMPTY" boilerplate; D3: leave test 16 unchanged.)
