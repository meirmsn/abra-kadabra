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
