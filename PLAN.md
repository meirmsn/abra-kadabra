# Plan

Forward-looking plan at the feature/PR grain.

- Pipeline phase per active branch: each feature's `specs/<name>/tasks.md`
- Shipped (rich history): `BUILD-LOG.md`
- Deferred / long-term: `kit/ROADMAP.md`
- Tactical bugs/polish: `kit/TODOS.md`
- Plan history (including dropped rows): `git log --follow PLAN.md`

## Active

_No work in progress._

## Planned

_No planned work._

<!-- When features are planned, replace the placeholder with:

| # | Feature | Notes |
| --- | --- | --- |
| 1 | <feature-slug> | <scope pointer — e.g. kit/ROADMAP.md § v0 § Xa> |
| 2 | <next-feature>  | ... |
-->

<!--
Conventions:
- Status lives in section membership (Active vs Planned) — no status column.
- A Planned row transitions to Active when /ak-spec runs: drop #, add Branch + Spec columns.
- An Active row disappears when the feature ships — BUILD-LOG.md carries the full record.
- A row that's dropped (rescope, deprecated) — delete it; git log + commit message is the audit trail.
- "Not now, maybe later" work belongs in kit/ROADMAP.md, not Planned.
- Planned ordered by # ascending (smallest = next up). Renumber on reorder.
-->
