# Plan

Forward-looking plan at the feature/PR grain, scoped to one version at a time.

- **Current version**: the `## Planned` header declares which ROADMAP tier is active (e.g., `v0`). Only items from that tier (and relevant TODOS) belong in Planned. Higher tiers stay in ROADMAP/TODOS until the current version ships.
- Pipeline phase per active branch: each feature's `specs/<name>/tasks.md`
- Shipped (rich history): `BUILD-LOG.md`
- Long-form context per row: `kit/ROADMAP.md` / `kit/TODOS.md` (linked from each row)
- Plan history (including dropped rows): `git log --follow PLAN.md`

## How to add entries

Each Planned row is one feature / one PR. Long-form context (problem statement, full fix, sources) lives in `kit/ROADMAP.md` or `kit/TODOS.md` — the Hook column is the one-sentence summary, not the spec.

**Columns**:

- `Feature` — kebab-case slug. The row's identifier. Used in all cross-references (commits, ROADMAP, TODOS, Deps cells, bundle members). Should match the source ROADMAP/TODOS section anchor where possible.
- `Hook` — one sentence (≤ 120 chars) describing what shipping the row does. The observable change, not the mechanism.
- `Impact` — glyph + size + em-dash + short sentence about the payoff.
- `Risk` — glyph + size + em-dash + short sentence about what happens if skipped.
- `Cost` — glyph + size + em-dash + wallclock estimate.
- `Lev` — `Leverage = (impact_num × risk_num) ÷ cost_divisor`. Higher = sooner. Sort the table by this descending.
- `Deps` — blockers / ordering / defer signals. Empty means "unblocked, can start". Bundling info is NOT here — it lives in `## Bundling cheatsheet`.
- `Source` — pointer to long-form context. Shape: `` `kit/ROADMAP.md` `` (file path in its own code span) + `§` (separator) + the section heading text copied verbatim from the source file (preserving any inline-code backticks the heading contains). Truncate at the first `—` or `→` when the full heading is >70 chars AND the truncated form remains unambiguous (verify via `grep -c '^### .*<token>' kit/ROADMAP.md` returning 1). Example: a row sourced from ``### `/ak-go-live` post-merge prod-config sync (Arm B — automation core)`` becomes `` `kit/ROADMAP.md` `` `§` `` `/ak-go-live` `` ` post-merge prod-config sync`.

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
- ⓘ after `<feature>` — ordering constraint, no hard block (e.g., same template surface, conflicts if reversed).

**Splitting a ROADMAP entry into multiple rows**: when a single ROADMAP entry has independently-shippable sub-deliverables with materially different cost / risk / impact, each one becomes its own PLAN row with its own kebab-case slug. The `Source` column carries the ROADMAP section pointer plus a `§ (A)` / `§ (B)` suffix to identify which sub-deliverable. They are NOT a bundle — bundles are strictly ship-together-to-save-ceremony.

**Worked example**: the `auth-ux-conventions` row is well-shaped — kebab-case slug, single-sentence hook naming the observable mechanics (`AwaitingConfirmationCard`, `friendlyAuthError`, `/auth/callback` + `/reset-password` routes), Risk cites the concrete failure mode (every Supabase-auth project re-solves silent-bounce + raw-error-leak), Impact names what closes (major UX gap), Cost is a single estimate, Source points at the ROADMAP entry that carries the full diff.

**Lifecycle**:

- A Planned row becomes Active when `/ak-spec` runs (add `Branch` + `Spec` columns to the Active table).
- **Before implementing**: validate the entry still applies — context shifts, earlier work subsumes the need, constraints disappear. Surface concerns before coding. Cheap check, occasionally saves an entire implementation cycle.
- A row ships → delete from Planned/Active, close the source ROADMAP/TODOS entry, append a BUILD-LOG entry (eng summary + product summary when the change has a user/project-facing impact). The BUILD-LOG entry is the durable record; the PR body or squash commit body is the delivery mechanism.
- A row is dropped (rescope, dead) → delete it. Commit message carries the rationale.
- "Not now, maybe later" work belongs in `kit/ROADMAP.md`, not Planned.
- **Version transitions**: when every Planned row for the current version has shipped or been dropped, bump the `## Planned` header to the next tier (e.g., `v0` → `v1`), pull in items from that ROADMAP tier, and score/sort them.

<!--
Maintenance conventions:
- Status lives in section membership (Active vs Planned) — no status column.
- Planned header carries the current version tier in parens: `## Planned (v0)`.
- Planned ordered by Leverage descending; ties on dependencies (Deps column).
- Feature slug is the row's identifier — used in all cross-references. Never rename in place; if a row's scope changes meaningfully, delete + add a new row.
- Hook stays ≤ 120 chars. Long-form context goes to ROADMAP/TODOS, not the table cell.
- Source column splits the file path into its own code span so inline-code backticks inside the heading text (e.g. `/ak-build`, `template/apps/web/`) render correctly — markdown can't nest code spans, so a single outer wrap eats the inner backticks.
- Version transitions: bump the parens when every row for the current tier has shipped or been dropped. Pull in items from the next ROADMAP tier, score, sort.
-->

## Active

_No work in progress._

## Planned (v0)

| Feature                           | Hook                                                                                                                              | Impact if shipped                                 | Risk if skipped                                                                                              | Cost               | Lev     | Deps                   | Source                                                                                  |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------ | ------- | ---------------------- | --------------------------------------------------------------------------------------- |
| `pwa-sw-baseline`                 | Serwist wiring + stale-while-revalidate HTML in template; PWA caching strategy doc                                                | 🟡 M — closes an ergonomics gap                   | 🟡 M — every PWA-shaped project pays full server roundtrip on iOS cold-launch                                | 🟡 M — ~2–3 hr     | **3.6** | —                      | `kit/ROADMAP.md` § Template PWA service worker baseline                                 |
| `latency-feedback-primitives`     | Extract `useSubmitFeedback` / `SubmitButton` / `LoadingArea` / `useOptimisticMutation` from lalista to `@devshop-template/ui`     | 🟡 M — closes the ergonomics gap (component half) | 🟡 M — every project re-derives optimistic-mutation rollback timing (React-19 batching gotcha)               | 🟡 M — ~1.5–2 hr   | **3.6** | —                      | `kit/ROADMAP.md` § Latency feedback framework — 5-tier decision rule + primitives § (B) |
| `auth-ux-conventions`             | Template ships `AwaitingConfirmationCard` + `friendlyAuthError` + `/auth/callback` + `/reset-password` routes                     | 🔴 L — closes a major UX gap                      | 🔴 L — every Supabase-auth project re-solves silent-bounce + raw-error-leak                                  | 🔴 L — ~4–5 hr     | **3.2** | —                      | `kit/ROADMAP.md` § Auth UX conventions — shared error-surface + state patterns          |
| `migration-sequencing-tracks-a-c` | `/ak-spec` Migration Sequencing section + `ops.md` doc + fix orphan `ak-go-live:88` cross-ref                                     | 🟢 S — closes a papercut on uncommon path         | 🟡 M — orphan ref stays broken; mutating migrations slip                                                     | 🟡 M — ~2–3 hr     | **2.4** | ⚠ verify Track B usage | `kit/ROADMAP.md` § Migration sequencing safety nets for the Vercel-preview window       |
| `stash-vanish-root-cause`         | Root-cause investigate why operator stashes vanish during `/ak-merge-devshop` flows                                               | 🟢 S — closes a recurring papercut                | 🟡 M — stash data silently lost; recovery requires `git fsck` archaeology                                    | 🟡 M — ~1.5–3 hr   | **2.4** | —                      | `kit/TODOS.md` § Root-cause investigation: operator stashes vanish                      |
| `ak-go-live-arm-b`                | Auto-sync Supabase email templates + auth allow-list post-merge via Management API; per-run `go-live.md` report                   | 🟡 M — saves time per config change               | 🟢 S — manual paste tax on every prod-config change                                                          | 🔴🔴 XL — ~6–10 hr | **0.7** | ⛔ defer; Arm A ~70%   | `kit/ROADMAP.md` § `/ak-go-live` post-merge prod-config sync (Arm B — automation core)  |

## Bundling cheatsheet

Each bundle saves ~15–25 min of ceremony (audit + squash + CI watch + `/ak-merge-devshop`). Members are landed in one PR.

| Bundle           | Members                                                                   | Why bundles cleanly                                                                                                                                                     | Ceremony saved |
| ---------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- |
| post-baseline-UX | `pwa-sw-baseline` + `auth-ux-conventions` + `latency-feedback-primitives` | All target the same `template/apps/web/` + `template/packages/ui/` surface (template baseline shipped 2026-05-19); lalista soak still pending for `auth-ux-conventions` | 2 cycles       |
