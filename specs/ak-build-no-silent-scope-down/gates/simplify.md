## Gate 4: /simplify

- Result: pass

Prose-only change (no runtime code). Scope: bats Section E assertions + the prohibition-block prose.

**Tests (`kit/tests/util-ak-build-skill.bats` Section E, 6 `@test`s):** Each guards a distinct facet — header presence, no-discretion/unconditional-default phrasing, the anti-bias positive+negative pair, the AskUserQuestion template options, the Phase 0 one-liner cross-reference, and the workflow.md coherence line. No overlapping or trivially-true greps. Test 31's `^## Non-negotiable: run the full pipeline` (header, line 55) and Test 35's awk-scoped grep of the same string (Phase 0 cross-ref, line 304) hit genuinely distinct file locations — not redundant. The two negative greps in Test 33 (`! grep ... 'assess pipeline applicability'`, `! grep ... 'Step 0\.1'`) are load-bearing: they guard the D2/D5 invariant against a future edit reintroducing the forbidden routine per-run applicability beat. Multi-grep `@test`s bundle related-but-distinct strings, which is correct one-facet-per-test practice.

**Prose (`build/SKILL.md` block + Phase 0 one-liner; `workflow.md` line):** 4 bold-led paragraphs (unconditional default / no-discretion prohibition / what-silently-disappears stakes / ask-never-act exception) + AskUserQuestion template + Phase 0 cross-reference. No literally duplicated sentences. The recurring "no size threshold" / "too small for the pipeline" framing is the deliberate rule-vs-anti-pattern pairing (para 1 states the rule, para 2 enumerates the three forbidden routine mechanisms) — its thoroughness is the load-bearing point of the anti-bias guard, not redundancy. workflow.md line is a single coherence touch.

No mechanical simplification warranted. Baseline bats suite green (36/36).

## Dismissals

None
