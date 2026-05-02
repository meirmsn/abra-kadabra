# Adversarial Reviewer Doc-Inlining — Pending Follow-ups

**Status:** Phases 1+2 + open Q1 + open Q4 SHIPPED 2026-05-01 (commits `0fcd4c5`, `9b18f46`, `889c883`, `06fe58e` on `main`).

**Source RFC:** [`adversarial-review-doc-inlining.md`](./adversarial-review-doc-inlining.md) — the full original design document. Read it for the architectural rationale. This note is the running inventory of items that did NOT ship in Phase 1+2 and don't yet have their own ROADMAP slot.

**How this note should be used:**

- When a deferred item's gating condition is met, fold it into a new RFC or ROADMAP entry, then mark its bullet here "promoted to ROADMAP § X" with a link (don't delete — preserves the why).
- When a new follow-up arises post-shipment, add it here.
- This note is a rationale archive — rule 1(d)'s historical-notes carve-out applies, so it can keep mentioning shipped/decided items without triggering drift checks.

---

## Already in `kit/ROADMAP.md`

Listed here for completeness; full context lives in their ROADMAP entries.

- **Phase 5 — tool-use grep for `dismissalLog`** → `kit/ROADMAP.md § Adversarial reviewer Phase 5 — tool-use grep for \`dismissalLog\``. Gated on incident data (real dismissalLog rejections that would have caught drift if the reviewer could grep).
- **Phase 6 — out-of-band coherence sweep** → `kit/ROADMAP.md § Adversarial reviewer Phase 6 — out-of-band coherence sweep`. Gated on Phase 5 landing first (tool-use grep makes multi-doc verification materially cheaper).

---

## Operational follow-ups (not yet ROADMAP-worthy)

### `COMMIT_TIMEOUT` 180→90 revert

`COMMIT_TIMEOUT` was bumped from 90s to 180s in commit `3694dc3` because Sonnet 4.6 reliably exceeded 90s on dense `docsReviewed` prompts (rule 4(e) addition-drift sweep added cognitive load). Phase 1 cleanup shrank the static prompt from ~13.4 KB to ~9.7 KB (~28%) and the runtime CONTEXT from cross-repo + head-truncated to FULL-but-narrower; both should reduce per-call latency.

**Why deferred:** the only two timed invocations during the Phase 2 commit (76s and 160s) showed high variance — not enough data to commit to 90s safely. The RFC's "watch one cycle of real commits" guidance is correct.

**Gating condition:** ~5–10 real `docsReviewed` invocations on representative commits, with p95 observed < ~75s. Wrap `adversarial-review.sh` invocations with a timing log (e.g., write `start,end,model,exit-code` to `kit/log.csv` — see ROADMAP § Devshop observability) so the data accumulates passively.

**When to revisit:** after a few weeks of normal devshop activity, audit the timing log. If p95 < 75s, ship the revert as a one-line PR.

**Implementation surface (when ready):** `kit/scripts/adversarial-review.sh` — change the line `COMMIT_TIMEOUT=180` back to `90`. No tests change. No docs change (180 is documented in `kit/docs/guide/hooks.md § Bypass flags + env hatches` as an internal default; if 90 is restored, that paragraph's parenthetical "(bumped from 90s after PR #25 …)" should be revisited but not necessarily removed — the historical context is still useful).

---

## Open RFC questions still un-decided

These are decision points the original RFC explicitly deferred. None block any shipped behavior — they refine the Phase 4+ work that hasn't started.

### Open Q2 — does the project repo grow a `guide/` directory?

The devshop has `kit/docs/guide/` for deep references (hooks, conventions, security, etc.). The project repo doesn't — it has `OVERVIEW.md` + `ARCHITECTURE.md` + per-package READMEs as the deep tier.

**RFC's lean:** option (b) — don't add `guide/` yet. Keep deep references inline in `OVERVIEW.md` / `ARCHITECTURE.md`, expand them as needed. Add `guide/` only when one of those docs grows past readable size.

**Why deferred:** premature. The project doc surface today (lalista) is small enough that consolidation works. Adding `guide/` proactively would be solving a problem that doesn't exist yet.

**When to revisit:** when a project's `ARCHITECTURE.md` (or `OVERVIEW.md`) crosses ~30 KB or becomes hard to navigate by `## ` headings alone — same threshold the original RFC suggests for splitting devshop's `CLAUDE.md`.

**What changes if Q2 lands as option (a):** the `docsReviewed` project branch in `adversarial-review.sh` would also inline `guide/*` headers as flat-catalog (mirroring the devshop branch). The `GUIDES_TO_INCLUDE` selective-expansion map would gain project-side routes. Routing examples from RFC § 4: new `apps/web/app/**/page.tsx` → relevant section of `apps/web/README.md` (already partially served by the per-package README inline); migration changes → `ARCHITECTURE.md § Data` section (selective expansion, not headers-only).

### Open Q3 — doc structural templates

Rule 1(a)'s named-edits requirement (now SHIPPED) requires bypass authors to name "the specific edit (added bullet, new row, changed sentence)." For that constraint to be _meaningfully checkable_, docs need predictable structure — every guide section follows "What it is / How it works / Extending" or similar, every per-package README follows "Routes / Components / Tests" or similar.

**Where templates would live:** `kit/docs/guide/conventions.md § Doc Templates`.

**Why deferred:** rule 1(a) already works without templates — bypass authors quote whatever phrase will appear in the diff, structured or not. Templates would make the pattern more _enforceable_ (Phase 4 territory) but the bypass author + reviewer flow doesn't break without them. Doing Q3 in isolation is documentation work without a concrete payoff yet.

**Implementation order if you take it:**

1. Audit existing `guide/*.md` sections — what _de facto_ structure already exists?
2. Codify 2–3 templates: probably one for "convention" sections (`conventions.md`), one for "subsystem" sections (`hooks.md` / `security.md` / `architecture.md`), one for per-package READMEs.
3. Document them in `conventions.md § Doc Templates`.
4. **Don't** migrate existing docs in the same PR — let templates apply to new sections going forward; backfill is its own per-doc PR.

**Gating condition:** Phase 4 (template-fitness enforcement, see Q5) is on the table. Until then, templates are aspirational.

### Open Q5 — reviewer enforcement of doc structural templates

Once templates exist (Q3), should the reviewer enforce that AFFECTED-doc edits _fit_ the template? E.g., a new `guide/*` section must have "What it is / How it works / Extending" subsections.

**RFC's lean:** yes, but as a soft check (warn, don't block) initially. Promote to hard fail after a few weeks of dogfooding.

**Why deferred:** depends on Q3 landing first. No template = nothing to enforce.

**Implementation surface (when ready):** new prompt rule in `adversarial-review.sh` — for AFFECTED guide-doc edits where the edit ADDS a new section, verify the section follows the template (specific section names present). Initially a soft warning printed alongside PASS; promoted to FAIL after the first cycle where the warning would have been correct ≥3 times.

---

## Cross-references back

- `kit/ROADMAP.md § Adversarial reviewer Phase 5` — links here from "See follow-ups note for related deferred items"
- `kit/ROADMAP.md § Adversarial reviewer Phase 6` — same
- `kit/notes/roadmap/adversarial-review-doc-inlining.md` (the source RFC) — readers who reach the bottom of the RFC and want a "what's the post-Phase-2 status?" view should be pointed here. (Update to the RFC pending — out of scope for this note's first commit; flagged here as a self-referential follow-up.)
