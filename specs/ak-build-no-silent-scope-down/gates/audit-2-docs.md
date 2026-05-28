Clean — no docs findings.

Notes (not findings — informational):
- Devshop self-mode (GIT_ROOT=/devshop); Section E (CLAUDE.md hygiene) is
  project-mode-only and skipped.
- Coverage (Section A): the diff touches `.claude/skills/devshop/build/SKILL.md`
  (SKILL.md surface → requires `kit/docs/guide/workflow.md` OR `CLAUDE.md`);
  `kit/docs/guide/workflow.md` IS staged in range → covered. No `template/**`,
  `kit/scripts/**`, `kit/hooks/**`, `.devcontainer/**`, or `kit/manifest.txt`
  touched, so no Existing-projects migration block is required.
- Adequacy (Section B): both touched docs are substantive. The workflow.md
  Step 4 line states the observable behavior ("runs in full by default … asks
  via AskUserQuestion before deviating") and matches the new SKILL.md
  `§ Non-negotiable: run the full pipeline` block verbatim in intent. The
  Phase 0 one-liner correctly cross-references that section by its real header.
- Coherence (Section C): the "full pipeline by default, every phase, no matter
  how small" claim does NOT contradict devshop-mode's documented phase skips
  (Phases 4.1–7 skipped, reduced 6-gate set). The new block scopes itself to
  agent-improvised scope-down ("no discretion to hand-roll a lighter flow",
  "genuine impulse to deviate"); the devshop-mode reductions are reached by
  deterministic mode detection in Step 0, not by discretion. No stale path or
  dangling section reference; the `§ Non-negotiable: run the full pipeline`
  header cited by the Phase 0 one-liner exists. This matches Audit 1's
  stale-doc sweep conclusion.
- Bypass trailers (Section D): no Docs-Coverage-Bypass trailers in range.
- The remaining commits in the Audit 1→HEAD range are Phase 4.0 bookkeeping
  (BUILD-LOG.md entry, PLAN.md row removal, kit/ROADMAP.md closure) and Phase 3
  gate artifacts — all carve-out paths per the devshop coverage rubric
  (kit/ROADMAP.md, specs/**, gates/**); none introduce a new documentable
  surface.
- No METRICS.md expected or present (devshop self-mode, no user-facing app
  feature).
