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
- Deferred subsection: low-priority v0 rows the operator has consciously parked. Still v0 (not yet promoted to v1); membership in `### Deferred` is the defer signal. Revisit the whole subsection at the v0→v1 bump.
-->

## Active

_No work in progress._

## Planned (v0)

| Feature                        | Hook                                                                                                                                                  | Impact if shipped                                                                                 | Risk if skipped                                                                                                          | Cost                                                                                                             | Lev     | Deps                                                                                  | Source                                                                    |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `gstack-vendored-upgrade`      | Upgrade vendored gstack 0.15.1.0→1.55.0.0; closes browse-daemon memory/zombie leaks, unblocks visual-design + native QA                               | 🔴 L — closes the browse-daemon leak/zombie-rebuild class + unblocks v1 visual-design & native QA | 🔴 L — recurring browse flakiness + destructive-rebuild exposure; upgrade debt compounds (~110 releases behind, growing) | 🟡 M — vendored swap + `./setup` hazard + smoke + throwaway `/ak-pre-ship` (~1.5–3 hr; project rollout separate) | **6.4** | ⚠ run before `visual-design-richness-mvp`; verify `./setup` vs locked `settings.json` | `kit/ROADMAP.md` § gstack vendored upgrade (0.15.1.0 → 1.55.0.0)          |
| `sudo-scoping-node`            | Scope node's passwordless sudo so a rogue dep/agent can't `sudo chown`-bypass root-owned file locks                                                   | 🟡 M — closes the sudo-chown bypass of root-owned protections                                     | 🟡 M — defense-in-depth gap remains; two-layer locking stays aspirational                                                | 🟡 M — sudoers scoping + the `sudo-hardening.md` analysis                                                        | **3.6** | —                                                                                     | `kit/TODOS.md` § Investigate scoping node user's sudo access              |
| `grep-test-drift-guard`        | Link `grep`-based bats tests to the prose/source they assert so an edit can't silently drift a test (red main) or under-assert (silent coverage drop) | 🟡 M — kills the most frequent (5×) red-main / silent-coverage-drop class                         | 🟡 M — recurs on the common doc / prompt / script-edit path                                                              | 🟡 M — `structural-invariants.bats` mapping check or a `conventions.md` co-update rule                           | **3.6** | —                                                                                     | `kit/TODOS.md` § Guard against `grep`-based bats tests drifting           |
| `wiring-test-skill-autodetect` | Auto-detect skill-invoked kit scripts in the wiring test so a new helper can't ship a red `main`                                                      | 🟡 M — closes the red-main-on-unregistered-script class                                           | 🟡 M — recurs per new skill-helper; red `main` blocks in-flight merges                                                   | 🟡 M — grep `.claude/skills/**/SKILL.md` for the basename in `structural-invariants.bats`                        | **3.6** | —                                                                                     | `kit/TODOS.md` § Auto-detect skill-invoked kit scripts in the wiring test |

### Deferred (low-priority v0 — may slip to v1)

_Consciously parked — deprioritized within v0; revisit at the v0→v1 bump (likely promote to v1). Ordered by Leverage descending. Membership in this subsection is the defer signal (no status column), consistent with the maintenance conventions above._

| Feature                           | Hook                                                                                                                          | Impact if shipped                                 | Risk if skipped                                                                                | Cost               | Lev     | Deps                   | Source                                                                                  |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ------------------ | ------- | ---------------------- | --------------------------------------------------------------------------------------- |
| `latency-feedback-primitives`     | Extract `useSubmitFeedback` / `SubmitButton` / `LoadingArea` / `useOptimisticMutation` from lalista to `@devshop-template/ui` | 🟡 M — closes the ergonomics gap (component half) | 🟡 M — every project re-derives optimistic-mutation rollback timing (React-19 batching gotcha) | 🟡 M — ~1.5–2 hr   | **3.6** | —                      | `kit/ROADMAP.md` § Latency feedback framework — 5-tier decision rule + primitives § (B) |
| `auth-ux-conventions`             | Template ships `AwaitingConfirmationCard` + `friendlyAuthError` + `/auth/callback` + `/reset-password` routes                 | 🔴 L — closes a major UX gap                      | 🔴 L — every Supabase-auth project re-solves silent-bounce + raw-error-leak                    | 🔴 L — ~4–5 hr     | **3.2** | —                      | `kit/ROADMAP.md` § Auth UX conventions — shared error-surface + state patterns          |
| `migration-sequencing-tracks-a-c` | `/ak-spec` Migration Sequencing section + `ops.md` doc + fix orphan `ak-go-live:88` cross-ref                                 | 🟢 S — closes a papercut on uncommon path         | 🟡 M — orphan ref stays broken; mutating migrations slip                                       | 🟡 M — ~2–3 hr     | **2.4** | ⚠ verify Track B usage | `kit/ROADMAP.md` § Migration sequencing safety nets for the Vercel-preview window       |
| `ak-go-live-arm-b`                | Auto-sync Supabase email templates + auth allow-list post-merge via Management API; per-run `go-live.md` report               | 🟡 M — saves time per config change               | 🟢 S — manual paste tax on every prod-config change                                            | 🔴🔴 XL — ~6–10 hr | **0.7** | ⛔ defer; Arm A ~70%   | `kit/ROADMAP.md` § `/ak-go-live` post-merge prod-config sync (Arm B — automation core)  |

## Bundling cheatsheet

Each bundle saves ~15–25 min of ceremony (audit + squash + CI watch + `/ak-merge-devshop`). Members are landed in one PR.

| Bundle           | Members                                               | Why bundles cleanly                                                                                                                                                                                                                                                                                                                | Ceremony saved |
| ---------------- | ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- |
| post-baseline-UX | `auth-ux-conventions` + `latency-feedback-primitives` | Both target the same `template/apps/web/` + `template/packages/ui/` surface (template baseline shipped 2026-05-19); lalista soak still pending for `auth-ux-conventions`. (`pwa-sw-baseline` dropped — demoted out of v0; its `kit/ROADMAP.md § Template PWA service worker baseline` entry is v1 / soak-pending on lalista's SW.) | 1 cycle        |

## Planned (v1)

_Forward-staged ahead of v0 shipping — a deliberate relaxation of the one-tier-at-a-time rule, kept here for visibility on the two largest near-term capability bets. Promote into the active `## Planned` table when the header bumps to v1._

| Feature                      | Hook                                                                                                                   | Impact if shipped                                                          | Risk if skipped                                                                 | Cost                                                      | Lev     | Deps | Source                                           |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | --------------------------------------------------------- | ------- | ---- | ------------------------------------------------ |
| `visual-design-richness-mvp` | Art-direction `DESIGN.md` section + themeable SVG decorative kit + pre-ship richness gate so pages stop shipping plain | 🔴 L — closes a major visual-quality gap (plain → richer on every product) | 🟡 M — every from-scratch product ships visually plain by construction          | 🔴 L — ~1–1.5 days                                        | **2.4** | —    | `kit/ROADMAP.md` § Visual design richness (MVP)  |
| `native-mobile-support`      | Extend the devshop to React Native (Expo): `apps/mobile/`, EAS, Maestro E2E, mobile Sentry/PostHog, store deploys      | 🔴🔴 XL — unlocks an entire second platform the devshop can't build today  | 🟡 M — no native capability exists; every native project blocked until it lands | 🔴🔴 XL — whole platform (Expo/EAS/Maestro/stores), weeks | **1.7** | —    | `kit/ROADMAP.md` § Native/mobile devshop support |
