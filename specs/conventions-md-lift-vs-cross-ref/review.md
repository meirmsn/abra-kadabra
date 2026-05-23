# Review — conventions-md-lift-vs-cross-ref

## Audit 1: manual (2026-05-23)

<!-- audited-at: c81407a0c15e88beac4f55b363590fcc4129f3f0 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=1 low=1

### Docs findings

- [low] `kit/docs/guide/ops.md:81`, `kit/docs/guide/ops.md:243`, `kit/docs/guide/ops.md:476`, `kit/docs/guide/migrations.md:71`, `kit/docs/guide/README.md:92`, `kit/docs/OVERVIEW.md:278` — Six cross-references in non-touched docs point at `conventions.md § Deploy Boundaries` and `conventions.md § Screenshot Routing`, which are now one-line redirect stubs (two-hop indirection). Fix: update each to point directly at `go-live/SKILL.md § Deploy surfaces` / `pre-ship/SKILL.md § Screenshot Routing`.

### Tests findings

- [medium] `kit/tests/structural-invariants.bats` (removed test) — The structural invariant test `wiring: template .gitignore matches Screenshot Routing convention` was deleted, removing the assertion that `specs/*/qa-walk/` is present in `template/.gitignore`. NOTE: this finding is from the base divergence (origin/main moved forward after branch creation); the change is NOT in this branch's actual diff (which touches only doc/skill files).

### Bypass trailer audit

- (none)
