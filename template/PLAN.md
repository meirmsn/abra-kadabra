# Plan

Forward-looking plan at the feature/PR grain, scoped to one version at a time.

- **Current version**: the `## Planned` header declares which version is active (e.g., `v0`). Only items from that tier (and relevant TODOS) belong in Planned. Higher tiers stay in PRODUCT-ROADMAP/TODOS until the current version ships.
- Pipeline phase per active branch: each feature's `specs/<name>/tasks.md`
- Shipped (rich history): `BUILD-LOG.md`
- Deferred / long-term: `PRODUCT-ROADMAP.md`
- Tactical bugs/polish: `TODOS.md`
- Plan history (including dropped rows): `git log --follow PLAN.md`

## Active

_No work in progress._

<!-- When a feature is active, replace the placeholder with:

| Branch | Spec | Notes |
| --- | --- | --- |
| feat/<name> | specs/<name>/spec.md | <scope pointer> |
-->

## Planned (v0)

_No planned work._

<!-- When features are planned, replace the placeholder with:

| # | Feature | Notes |
| --- | --- | --- |
| 1 | <feature-slug> | <scope pointer — e.g. PRODUCT-ROADMAP.md § v1 § Xa> |
| 2 | <next-feature>  | ... |
-->

<!--
Conventions:
- Status lives in section membership (Active vs Planned) — no status column.
- Planned header carries the current version in parens: `## Planned (v0)`.
- A Planned row transitions to Active when /ak-spec runs: drop #, add Branch + Spec columns.
- Before implementing: validate the entry still applies (context shifts, earlier work subsumes the need). Surface concerns before coding.
- A row ships → delete from Planned/Active, close the source PRODUCT-ROADMAP/TODOS entry, append a BUILD-LOG entry. The BUILD-LOG entry is the durable record; the PR body is the delivery mechanism.
- A row that's dropped (rescope, deprecated) — delete it; git log + commit message is the audit trail.
- "Not now, maybe later" work belongs in PRODUCT-ROADMAP.md, not Planned.
- Planned ordered by # ascending (smallest = next up). Renumber on reorder.
- Version transitions: bump the parens when every row for the current version has shipped or been dropped. Pull in items from the next PRODUCT-ROADMAP tier.
-->
