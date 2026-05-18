# Review — product-update-pr-section

## Audit 1: manual (2026-05-18)

<!-- audited-at: cc9d887d49211af2eecf1d37989429e63a132eb7 -->
<!-- range: origin/main...HEAD -->

findings: high=0 medium=0 low=1

### Docs findings

- (none)

Coverage (Section A): SKILL.md changes in `.claude/skills/devshop/{spec,build,go-live}/SKILL.md` matched by edits to `kit/docs/guide/workflow.md` (Phase 4.1 / 4.0/5.6 BUILD-LOG bullet / Phase 6 / Phase 7) and `CLAUDE.md § Commit + PR text style`. Other touched files fall under documented carve-outs (`kit/tests/**`, `kit/ROADMAP.md`, `PLAN.md`, `specs/**`).

Adequacy (Section B): all three reference-doc edits are substantive (new sections / new table columns / new lead paragraphs). Named-section claims verified by grep: `ak-spec § Product update` (line 341), `/ak-build` Phase 0.2.6 (line 267), Phase 4.1 (line 785), Phase 5.3.5 (line 1026), Phase 6 Part D (line 1975), `/ak-go-live` Step 6 (line 439). All citations resolve at HEAD.

Coherence (Section C): no renames or deletions in the merge content. Cross-doc sweep returned no stale `## Summary` references in non-touched docs; `BUILD-LOG.md` references in `OVERVIEW.md` / `FAQ.md` / `architecture.md` / `hooks.md` make no field-shape claims that contradict the new `Headline:` / `Summary:` two-field layout.

Bypass trailers (Section D): No Docs-Coverage-Bypass trailers in range.

### Tests findings

- [low] `kit/tests/util-product-update-blurb.bats:308` — noun-extraction tests duplicate the SKILL.md heuristic inline; comment claims drift-detection but the implementation doesn't enforce that contract. Recommend either extracting the stopword list + regex set from SKILL.md at runtime (mirroring the lint-regex tests at lines 226–266 which DO use runtime extraction) or dropping the misleading comment. Low because the higher-blast-radius lint-regex tests already have the correct runtime-extraction pattern, and the noun-extraction logic is small + stable.

Section A — Coverage: 37 tests cover all three touched SKILL.md files and every named section the diff adds (Phase 0.2 / 0.2.6 / 0.3 / 4.1 / 5.3.5 / 5.6 / 6 Part D / 7 + Step 6). All 37 tests pass against HEAD.

Section B — Quality: no weak assertions, no skip/only patterns. Behavioral lint-regex tests (lines 226–266) extract regexes from SKILL.md at runtime — correct drift-detection shape.

Section C — Bypass trailers: No Tests-Coverage-Bypass trailers in range.

### Bypass trailer audit

- (none)
