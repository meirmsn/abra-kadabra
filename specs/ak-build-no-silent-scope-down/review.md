<!-- audited-at: 2f28e30a31bfb944196cca14b9259421c5f89666 -->
# Pre-ship review — ak-build-no-silent-scope-down (devshop mode)

## Router Summary

6 gates dispatched (1 docs-check, 2d fast-job-local, 4 /simplify, 5 docs-and-tests-review, 6 /review, 11 convention), 13 pre-composed carve-outs (devshop self-mode). No findings dismissed. Result: all dispatched gates pass; 4 LLM-mediated gates structurally inapplicable (carve-out STRUCTURAL advance log below).

- passed: 6
- findings_pending: 0
- n/a (non-LLM carve-outs): 9
- blocked (structural LLM carve-outs): 4

## Gate 1: docs-check

- Result: pass

The diff is itself documentation + tests. Reference-doc coverage:
- `.claude/skills/devshop/build/SKILL.md` — the change IS the doc (prohibition block + Phase 0 one-liner).
- `kit/docs/guide/workflow.md` Step 4 — updated in the same change to stay coherent with the skill behavior (D6).
- `kit/ROADMAP.md` / `PLAN.md` closure is deferred to Phase 4.0 per the pipeline contract (not a docs-check miss).
No code surface lacks a doc; no doc references a removed symbol. Devshop "reference docs"
(kit/docs/guide/*.md, CLAUDE.md, OVERVIEW.md) need no further update — the injunction is
self-contained in the skill, and workflow.md is the one guide doc that describes the pipeline shape.

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

Ran the full devshop bats suite (`kit/tests/`) at HEAD: **1525 tests, 0 failures**.
This is the devshop equivalent of the project's turbo lint/typecheck/test/build
pipeline. The feature's own new tests (util-ak-build-skill.bats Section E, 6 tests)
are included and green; no regression elsewhere.

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

Prose-only change (no runtime code). Scope: bats Section E assertions + the prohibition-block prose.

**Tests (`kit/tests/util-ak-build-skill.bats` Section E, 6 `@test`s):** Each guards a distinct facet — header presence, no-discretion/unconditional-default phrasing, the anti-bias positive+negative pair, the AskUserQuestion template options, the Phase 0 one-liner cross-reference, and the workflow.md coherence line. No overlapping or trivially-true greps. Test 31's `^## Non-negotiable: run the full pipeline` (header, line 55) and Test 35's awk-scoped grep of the same string (Phase 0 cross-ref, line 304) hit genuinely distinct file locations — not redundant. The two negative greps in Test 33 (`! grep ... 'assess pipeline applicability'`, `! grep ... 'Step 0\.1'`) are load-bearing: they guard the D2/D5 invariant against a future edit reintroducing the forbidden routine per-run applicability beat. Multi-grep `@test`s bundle related-but-distinct strings, which is correct one-facet-per-test practice.

**Prose (`build/SKILL.md` block + Phase 0 one-liner; `workflow.md` line):** 4 bold-led paragraphs (unconditional default / no-discretion prohibition / what-silently-disappears stakes / ask-never-act exception) + AskUserQuestion template + Phase 0 cross-reference. No literally duplicated sentences. The recurring "no size threshold" / "too small for the pipeline" framing is the deliberate rule-vs-anti-pattern pairing (para 1 states the rule, para 2 enumerates the three forbidden routine mechanisms) — its thoroughness is the load-bearing point of the anti-bias guard, not redundancy. workflow.md line is a single coherence touch.

No mechanical simplification warranted. Baseline bats suite green (36/36).

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

## Gate 11: convention (adapted — devshop)

- Result: pass

Devshop convention checks for this prose-only change:
- **SKILL.md frontmatter** — intact (name: ak-build, version: 2.0.0, description). The block was inserted at the body (after the intro, before `## Architecture`), not in the frontmatter.
- **No new shell scripts** — diff touches no `kit/scripts/**`, so no script-structure / new-bats-file requirement.
- **Guide-doc routing** — `workflow.md` is already linked in the routing index; the `routing-link-resolution.bats` + `structural-invariants.bats` suites pass at HEAD (included in Gate 2d's 1525-test run).
- **Bats coverage for the change** — the change ships its own regression guard (util-ak-build-skill.bats Section E).
- **Conventional commits** — all 5 branch commits use conventional `type(scope):` subjects describing the observable change.

## Dismissals

None

---

## Gate 5: docs-and-tests-review


## Audit 1: pre-polish (2026-05-28)

<!-- audited-at: d0073d03f61b941dffcfd82f8cde6a4641fdc261 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=1

### Docs findings

- (none)

### Tests findings

- [low] kit/tests/util-ak-build-skill.bats:295 — anti-bias negative greps pin two specific forbidden phrasings (`assess pipeline applicability`, `Step 0.1`); a future scope-down gate under different wording would slip past them. Inherent to prose-grep regression guards; acceptable, noted as a coverage ceiling.

### Bypass trailer audit

- (none)

## Phase 3 → 4 advance log

### 2026-05-28T20:13:50Z — Gate 7: /cso
**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-28T20:13:50Z -->

### 2026-05-28T20:13:50Z — Gate 8: /design-review
**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-28T20:13:50Z -->

### 2026-05-28T20:13:50Z — Gate 9: /qa
**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants run in Gate 2d
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-28T20:13:50Z -->

### 2026-05-28T20:13:50Z — Gate 10: /benchmark
**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-28T20:13:50Z -->

## Audit 2: manual (2026-05-28)

<!-- audited-at: 4de6b47d00896a970a16fb050df2b446b48097c3 -->
<!-- range: 8cdda994ea4523bc18f076b66d0da81ade74ceba..4de6b47 -->

findings: high=0 medium=0 low=0

### Docs findings

- (none)

### Tests findings

- (none)

### Bypass trailer audit

- (none)
