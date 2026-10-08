# W6 — Pipeline: verify intent, workflow tiers, deterministic orchestration

Deliver the core promise: each change is independently checked against what was
specified, with ceremony proportional to the change. Depends on D-06.
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]`.

## W6.1 Spec-conformance gate — P1 · M3 · M

Findings: F-PIPE-12. Opportunities: O-06, O-10. Pattern to clone: `design-conformance`.
Done when: on the fixture, the gate FAILs a branch with a seeded spec violation
(e.g. a decision ignored, an acceptance item unimplemented) and PASSes the honest
branch; verdicts carry file:line evidence + pinning test per claim.

- [ ] **W6.1.1** Claim extraction: decisions D1..Dn, in-scope items, acceptance criteria, core-story steps → `spec-claims.json` (cached by spec hash) — V2
- [ ] **W6.1.2** Per-claim verdict by a fresh agent with no implementation context: met / partial / unmet / deviated-with-reason, each with evidence + test reference; structured output; gate fails on unmet — V4
- [ ] **W6.1.3** Independence: different model or second reviewer where available (`/codex`, code-review plugin, claude-code-action in CI) (O-06) — V4
- [ ] **W6.1.4** Acceptance boxes ticked from verdicts; Headline/blurb drift **flagged**, never auto-rewritten to fit the diff — V2
- [ ] **W6.1.5** Point docs/tests audits at the spec: "every acceptance item pinned by a test?", "docs describe shipped decisions?" — V4

## W6.2 Traceability — P1 · M3 · S

Findings: F-PIPE-12.

- [ ] **W6.2.1** `tasks.md` gains `Implements: D3, A2, S1` per task; implement step refuses tasks without it — V2
- [ ] **W6.2.2** Test naming/annotation convention linking tests to acceptance IDs; checker script reports unpinned acceptance items — V2

## W6.3 Workflow tiers — P1 · M3 · M

Findings: F-PIPE-13, F-PIPE-14.
Done when: product, fix and patch tiers each exercised once on the fixture (V4);
hotfix documented and dry-run.

- [ ] **W6.3.1** Tier definitions (artifacts + gates per tier) in one table — design note reviewed:
  - product: full chain + spec-conformance
  - fix: investigate → failing regression test first → root-cause note → reduced gates → conformance against the bug report; no gstack prerequisite
  - patch (chore/copy/deps/refactor): spec-lite (decisions + acceptance) → fast CI + review + conformance; refactor adds behaviour-equivalence check
  - hotfix: branch → fix + test → PR; mandatory follow-up record after deploy
- [ ] **W6.3.2** Phase 0 selects the tier (proposed by Claude, confirmed by owner); tier recorded in spec header — V4
- [ ] **W6.3.3** Dependency-upgrade path (uses DEPS-WATCH + dependabot) as a patch-tier variant — V4

## W6.4 Deterministic orchestration; split `/ak-build` — P1 · M3 · L (D-06)

Findings: F-PIPE-06, F-PIPE-09, F-PIPE-11, F-PIPE-18. Opportunity: O-03.
Done when: halts/tallies/gate selection are script exit codes; `/ak-build` is a short
router plus per-phase files; contradictions in F-PIPE-09 gone; no prose "exit 1" halts.

- [ ] **W6.4.1** Single source of truth for gates (one table/file, consumed by scripts; counts generated) — removes F-PIPE-09 class
- [ ] **W6.4.2** `gate-runner` script: runs/collects gates, tallies, applies n/a-by-scope deterministically (fixes F-PIPE-06), exits non-zero to halt — V2/V3
- [ ] **W6.4.3** Split `build/SKILL.md` into router + phase files loaded on demand; move incident narratives to BUILD-LOG/notes; target ≤ 4k words per file — V1 + V4 run
- [ ] **W6.4.4** Pilot Workflow-based fan-out for pre-ship analysis gates (D-06 B) and compare against W6.4.2 — V4

## W6.5 Check taxonomy cleanup — P1 · M3 · M

Findings: F-REV-06, F-HOOK-09, F-SEC-17. Opportunity: O-02.

- [ ] **W6.5.1** Convert mechanically checkable LLM check-types to scripts (dirty-tree paths, manifest tag, PR body section order, bats-skip names, relocation staged, file headers) — V2
- [ ] **W6.5.2** Every bypass leaves a durable record (trailer or log); coverage bypass reasons reviewed at audit time (F-HOOK-09) — V3
- [ ] **W6.5.3** Security review runs on security-relevant devshop changes (hooks, settings, scripts, firewall) instead of blanket n/a (F-SEC-17) — V4
- [ ] **W6.5.4** Dedupe repeated checks (gitleaks ×4, bats ×5, lint/typecheck ×4): one owner per check in the gate table — V1

## W6.6 Greenfield chain + `/ak-new-project` fixes — P2 · M3 · M

Findings: F-PIPE-13, F-PIPE-15.

- [ ] **W6.6.1** Fix `$DEVSHOP` unset, step numbering, "any container" claim (F-PIPE-15) — or fold into W5.3.3 rewrite
- [ ] **W6.6.2** Documented greenfield chain: new-project → `/office-hours` → `/design-consultation` → `/autoplan` → seed PLAN → loop product-tier builds — V4 on fixture

## W6.7 Resolve skill contradictions — P1 · M3 · S

Findings: F-PIPE-07, F-PIPE-08.

- [ ] **W6.7.1** `/ak-spec`: works from Phase 0 skeleton without gstack artifacts; never overwrites decisions; always emits `## Task order`; `/ak-implement`: honours devshop/recipe-specific commands instead of hardcoded pnpm/posthog — V4
