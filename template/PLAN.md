# Plan

Forward-looking plan at the feature/PR grain, scoped to one version at a time.

- **Current version**: the `## Planned` header declares which version is active (e.g., `v0`). Only items from that tier (and relevant TODOS) belong in Planned. Higher tiers stay in PRODUCT-ROADMAP/TODOS until the current version ships.
- Pipeline phase per active branch: each feature's `specs/<name>/tasks.md`
- Shipped (rich history): `BUILD-LOG.md`
- Long-form context per row: `PRODUCT-ROADMAP.md` / `TODOS.md` (linked from each row)
- Deferred / long-term: `PRODUCT-ROADMAP.md`
- Tactical bugs/polish: `TODOS.md`
- Plan history (including dropped rows): `git log --follow PLAN.md`

## How to add entries

Each Planned row is one feature / one PR. Long-form context (problem statement, full fix, sources) lives in `PRODUCT-ROADMAP.md` or `TODOS.md` — the Hook column is the one-sentence summary, not the spec.

**Columns**:

- `Feature` — kebab-case slug. The row's identifier. Used in all cross-references (commits, PRODUCT-ROADMAP, TODOS, Deps cells). Should match the source PRODUCT-ROADMAP/TODOS section anchor where possible.
- `Hook` — one sentence (≤ 120 chars) describing what shipping the row does. The observable change, not the mechanism.
- `Impact` — glyph + size + em-dash + short sentence about the payoff.
- `Risk` — glyph + size + em-dash + short sentence about what happens if skipped.
- `Cost` — glyph + size + em-dash + wallclock estimate.
- `Lev` — `Leverage = (impact_num × risk_num) ÷ cost_divisor`. Higher = sooner. Sort the table by this descending.
- `Deps` — blockers / ordering / defer signals. Empty means "unblocked, can start".
- `Source` — pointer to long-form context. Shape: `` `PRODUCT-ROADMAP.md` `` (file path in its own code span) + `§` (separator) + the section heading text copied verbatim from the source file (preserving any inline-code backticks the heading contains). Truncate at the first `—` or `→` when the full heading is >70 chars AND the truncated form remains unambiguous.

**Rating scale** (uniform across Impact / Risk / Cost):

| Glyph | Size | Impact if shipped                              | Risk if skipped                                        | Cost wallclock |
| ----- | ---- | ---------------------------------------------- | ------------------------------------------------------ | -------------- |
| 🟢🟢  | XS   | housekeeping                                   | aesthetic only                                         | 15–30 min      |
| 🟢    | S    | closes a recurring papercut                    | friction on uncommon path                              | 30–60 min      |
| 🟡    | M    | saves measurable time per cycle                | friction on common path                                | 1.5–3 hr       |
| 🔴    | L    | closes a major UX/ergonomics gap               | recurring tax, ongoing operator cost                   | 4–8 hr         |
| 🔴🔴  | XL   | closes a class of bug for every future project | active prod/security exposure or every project blocked | >8 hr          |

**Numeric mapping for the formula**: XS=1, S=2, M=3, L=4, XL=5 (risk + impact). Cost divisors: XS=0.25, S=0.75, M=2.5, L=5, XL=9.

**Deps glyphs**:

- ⛔ `<feature>` — blocked on `<feature>`; can't start until it lands.
- ⚠ — decision item or verify-usage-first; might auto-close.
- ⓘ after `<feature>` — ordering constraint, no hard block (e.g., same surface, conflicts if reversed).

**Splitting a PRODUCT-ROADMAP entry into multiple rows**: when a single PRODUCT-ROADMAP entry has independently-shippable sub-deliverables with materially different cost / risk / impact, each one becomes its own PLAN row with its own kebab-case slug. The `Source` column carries the PRODUCT-ROADMAP section pointer plus a `§ (A)` / `§ (B)` suffix to identify which sub-deliverable.

**Lifecycle**:

- A Planned row becomes Active when `/ak-spec` runs (add `Branch` + `Spec` columns to the Active table).
- **Before implementing**: validate the entry still applies — context shifts, earlier work subsumes the need, constraints disappear. Surface concerns before coding.
- A row ships → delete from Planned/Active, close the source PRODUCT-ROADMAP/TODOS entry, append a BUILD-LOG entry. The BUILD-LOG entry is the durable record; the PR body is the delivery mechanism.
- A row is dropped (rescope, dead) → delete it. Commit message carries the rationale.
- "Not now, maybe later" work belongs in `PRODUCT-ROADMAP.md`, not Planned.
- **Version transitions**: when every Planned row for the current version has shipped or been dropped, bump the `## Planned` header to the next tier (e.g., `v0` → `v1`), pull in items from that PRODUCT-ROADMAP tier, and score/sort them.

<!--
Maintenance conventions:
- Status lives in section membership (Active vs Planned) — no status column.
- Planned header carries the current version in parens: `## Planned (v0)`.
- Planned ordered by Leverage descending; ties on dependencies (Deps column).
- Feature slug is the row's identifier — used in all cross-references. Never rename in place; if a row's scope changes meaningfully, delete + add a new row.
- Hook stays ≤ 120 chars. Long-form context goes to PRODUCT-ROADMAP/TODOS, not the table cell.
- Source column splits the file path into its own code span so inline-code backticks inside the heading text render correctly — markdown can't nest code spans, so a single outer wrap eats the inner backticks.
- Version transitions: bump the parens when every row for the current tier has shipped or been dropped. Pull in items from the next PRODUCT-ROADMAP tier, score, sort.
-->

## Active

_No work in progress._

<!-- When a feature is active, replace the placeholder with:

| Branch | Spec | Notes |
| --- | --- | --- |
| feat/<name> | specs/<name>/spec.md | <Hook from the Planned row> |
-->

## Planned (v0)

_No planned work._

<!-- When features are planned, replace the placeholder with:

| Feature | Hook | Impact if shipped | Risk if skipped | Cost | Lev | Deps | Source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `<feature-slug>` | <one-sentence observable change> | 🟡 M — <payoff> | 🟡 M — <consequence> | 🟡 M — ~N hr | **N.N** | — | `PRODUCT-ROADMAP.md` § <section heading> |
-->
