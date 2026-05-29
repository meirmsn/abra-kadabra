<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: triage-todos-to-friction-log -->
<!-- date: 2026-05-29 -->

# Spec: triage-todos-to-friction-log (devshop)

**Sources:**

- `kit/TODOS.md § Triage TODOs vs FRICTION-LOG` — the driver entry (currently
  uncommitted on main); carries the full sorting rule + per-item (A)/(B)/(C) plan.
- `kit/FRICTION-LOG.md` — destination ledger (schema + ordering rules at its head).
- `.claude/skills/ak-record-friction-log/SKILL.md` — the filing tool (dedup +
  count + impact×count score).
- `PLAN.md § Planned (v0)` — destination for the virtiofs promotion row.
- `CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships` — governs deleting
  the triage entry + unwinding cross-refs in the same change.

First real population of `kit/FRICTION-LOG.md`: demote premature single-sighting
TODOs into the counted intake ledger, promote the proven virtiofs phantom-rebase
item to a scored PLAN row, and version-tag every remaining untagged `kit/TODOS.md`
entry — so future sessions stop reading unscheduled debt as "still pending".

---

## Product update

### Headline + Detail (combined)

Infrastructure update — no user-visible change. Devshop tracker hygiene: the
friction log gets its first real population (7 premature/single-sighting TODOs
demoted into the counted intake ledger), the proven virtiofs phantom-rebase
fallback graduates to a scored `PLAN.md § Planned (v0)` row, and every remaining
untagged `kit/TODOS.md` entry receives a `[v0]`/`[v1]`/`[v+]` schedule tag. The
driver triage entry is deleted as its own resolution.

---

## Decisions (resolved at spec time)

Resolved in Phase 0 with the operator (2026-05-29). Recorded so Phase 1 preserves
them verbatim.

### D1: Move the 3 (A)-Strong items to FRICTION-LOG

**Decision:** Move + delete from TODOS. The three: _Instrument subagent drift
rate then decide_; _Investigate Mac host-resource constraints (home-os PR
#27/#28 blocked outcomes)_; _Layer-B CLAUDE.md classification gate doesn't
re-fire at the squash boundary_.

**Rationale:** All three are explicitly "measure / investigate / confirm-then-
decide" — fix-decision genuinely open, single context. Textbook pre-evidence
intake.

### D2: Move all 4 (A)-Weaker items to FRICTION-LOG

**Decision:** Move all 4 (operator confirmed the "move if you agree" call).
The four: _prTextHygieneReason reviewer auto-rejects even when PR text is fine_;
_`/ak-pre-ship` + Phase 5.9 visual-evidence deferrals get rubber-stamped_; _A
doc/SKILL.md edit can drift a bats test silently_; _`git ls-remote` via
HTTPS-token URL produces garbled output_.

**Rationale:** Single observation each, fix-worth unproven. Net friction-log
additions = 7 (3 Strong + 4 Weaker).

### D3: virtiofs phantom-rebase fallback → PLAN promotion

**Decision:** KEEP the `kit/TODOS.md` entry (it's the long-form Source), tag it
`[v0]`, AND add a `PLAN.md § Planned (v0)` row. Proposed score: 🟡 M impact /
🟢 S risk (the shipped `checkStat` stopgap de-risks the common path) / 🟢 S cost
(~30–45 min skill edit + a bats test). Operator accepted the proposed score;
spec pins the exact Lev computation + Source pointer.

**Rationale:** (B) — proven multi-date recurrence ledger; fired again 2026-05-29.
Graduated past friction. Promote, don't demote.

### D4: sudo-scoping item — keep + tag [v0]

**Decision:** _Investigate scoping node user's sudo access_ stays in TODOS,
tagged `[v0]`.

**Rationale:** (B) explicit operator decision 2026-05-29 — security item,
fix-on-principle, NOT recurrence-gated. Resolves the (C)-v1-list vs (B) conflict
in favor of (B). Matches operator's "keep …as v0".

### D5: Version-tag remaining entries per (C)

**Decision:** Apply (C)'s v0/v1/v+ buckets verbatim to every remaining untagged
entry. One retag: _gstack `/home/node/.gstack` volume-wipe_ moves `[v+]` → `[v0]`
per (C)'s v0 list. Moved items (D1+D2) drop out of tagging. Operator's PLAN
scoring remains the real call — spec pins the full per-entry mapping for review.

**Rationale:** "operator's PLAN scoring is the real call"; operator accepted the
proposed buckets as-is.

### D6: Delete the triage entry itself

**Decision:** Delete the _Triage TODOs vs FRICTION-LOG_ entry from `kit/TODOS.md`
as part of this change; unwind any cross-references.

**Rationale:** It's the resolved driver TODO. Per `CLAUDE.md § Closing TODO /
ROADMAP entries when a fix ships` — the change that ships the fix deletes its own
tracker entry. (The entry is currently working-tree-only / uncommitted, so it
never lands on main standalone.)

---

<!-- /ak-spec (Phase 1) expanded the file from here. The Product update +
     Decisions sections above are verbatim from Phase 0. -->

## Core user story

N/A — devshop tracker/docs hygiene only; no user-facing flow added or modified.

## In scope / Out of scope

**In scope:**

- Populate `kit/FRICTION-LOG.md` with the 7 demoted items (D1: 3 Strong + D2: 4 Weaker), each filed via `/ak-record-friction-log`.
- Promote the virtiofs phantom-rebase fallback to a `PLAN.md § Planned (v0)` row (D3), keeping the `kit/TODOS.md` entry as its long-form Source and tagging it `[v0]`.
- Version-tag every remaining untagged `kit/TODOS.md` open entry with `[v0]` / `[v1]` / `[v+]` per (C) + D4 + D5.
- Delete the 7 moved entries from `kit/TODOS.md` (D1+D2) and the driver _Triage TODOs vs FRICTION-LOG_ entry (D6).
- Unwind any orphaned cross-references the deletions create.

**Out of scope:**

- Actually fixing any of the underlying issues (the friction log accrues counts; the PLAN row schedules — neither fixes).
- Touching `kit/ROADMAP.md`, unless a cross-ref unwind genuinely requires it (none found — see § Cross-reference unwind list).
- Re-resolving any of D1–D6 (locked at Phase 0).

## Tag mapping table

One row per top-level `kit/TODOS.md` entry, enumerated top-to-bottom. **41 top-level entries** total (40 `- [ ]` open + 1 `- [x]` done). Dispositions: `MOVE→FL` = move to FRICTION-LOG + delete (D1/D2); `DELETE` = remove (D6); `KEEP+TAG` = stays, gets a new `[vN]`; `KEEP` = stays, already tagged; `DONE` = `[x]` history, leave verbatim.

| #   | Entry (short subject)                                                    | Disposition | Resulting tag / destination  | (C) phrase matched / note                                                                                                                                                           |
| --- | ------------------------------------------------------------------------ | ----------- | ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Triage TODOs vs FRICTION-LOG (driver)                                    | **DELETE**  | gone (D6)                    | n/a — its own resolution; currently `[v0]`-tagged on branch baseline                                                                                                                |
| 2   | Layer-B CLAUDE.md classification gate doesn't re-fire at squash boundary | **MOVE→FL** | FRICTION-LOG (D1 Strong)     | drops out of (C) tagging (was C-v0 "Layer-B squash gap")                                                                                                                            |
| 3   | Per-project catch-up workflow doc                                        | KEEP+TAG    | `[v1]`                       | (C)-v1 "per-project catch-up doc"                                                                                                                                                   |
| 4   | Full bats suite hangs during `git commit` on main                        | **DONE**    | leave `- [x]` verbatim       | history; fixed 2026-05-26                                                                                                                                                           |
| 5   | Skip bats on docs-only devshop commits                                   | KEEP+TAG    | `[v0]`                       | (C)-v0 "skip-bats-docs-only"                                                                                                                                                        |
| 6   | DCG `push-force-short` false-positive                                    | KEEP+TAG    | `[v0]`                       | (C)-v0 "DCG false-positive"                                                                                                                                                         |
| 7   | virtiofs phantom-rebase fallback mechanization                           | KEEP+TAG    | `[v0]` + **new PLAN v0 row** | (C)-v0 "virtiofs (→PLAN)"; D3                                                                                                                                                       |
| 8   | advisor-probe.mjs: live-Postgres integration coverage                    | KEEP+TAG    | `[v+]` `[spec-inferred]`     | (C) silent; blocked-by-environment (no Postgres/Docker in devcontainer) → v+                                                                                                        |
| 9   | advisor-probe.mjs: behavior-test `loadExemptions()`                      | KEEP+TAG    | `[v1]` `[spec-inferred]`     | (C) silent; small test refactor, post-v0 ship → v1                                                                                                                                  |
| 10  | Strip pre-seeded PRODUCT-ROADMAP + CLAUDE.md from lalista/home-os        | KEEP+TAG    | `[v1]`                       | (C)-v1 "lalista migrations (strip pre-seeded)"                                                                                                                                      |
| 11  | Investigate Mac host-resource constraints                                | **MOVE→FL** | FRICTION-LOG (D1 Strong)     | drops out of (C) tagging (was C-v1 "Mac-resource investigation")                                                                                                                    |
| 12  | Apply CLAUDE.md architecture migration to lalista                        | KEEP+TAG    | `[v1]`                       | (C)-v1 "lalista migrations (…CLAUDE.md arch…)"                                                                                                                                      |
| 13  | Migrate lalista local Supabase off `project_id="workspace"`              | KEEP+TAG    | `[v1]`                       | (C)-v1 "lalista migrations (…Supabase project_id)"                                                                                                                                  |
| 14  | Migrate 10 inline detections to `is_devshop_self_mode`                   | KEEP+TAG    | `[v1]`                       | (C)-v1 "kit-detection consolidation"                                                                                                                                                |
| 15  | `init-firewall.sh` hangs when re-run mid-session                         | KEEP+TAG    | `[v0]`                       | (C)-v0 "init-firewall hang"                                                                                                                                                         |
| 16  | `init-devshop.sh` mtime-bumps locked files                               | KEEP+TAG    | `[v0]`                       | (C)-v0 "mtime-bump locked files"                                                                                                                                                    |
| 17  | Docker Desktop `no-new-privileges` breaks postStartCommand               | KEEP+TAG    | `[v+]`                       | (C)-v+ "Docker no-new-privileges"                                                                                                                                                   |
| 18  | Revert `/ak-build` Phase 5 to `gh pr checks` (GitHub Checks PAT)         | KEEP+TAG    | `[v+]`                       | (C)-v+ "GitHub Checks revert"                                                                                                                                                       |
| 19  | Pin template base image by digest                                        | KEEP+TAG    | `[v1]`                       | (C)-v1 "pin base image"                                                                                                                                                             |
| 20  | Upstream fix: gstack browse daemon Chromium autodetect                   | KEEP+TAG    | `[v+]`                       | (C)-v+ "gstack Chromium"                                                                                                                                                            |
| 21  | Route init tracking out of project BUILD-LOG                             | KEEP+TAG    | `[v1]`                       | (C)-v1 "route init tracking"                                                                                                                                                        |
| 22  | Investigate scoping node user's sudo access                              | KEEP+TAG    | `[v0]`                       | **D4 / (B) wins over (C)-v1 "sudo scoping"**                                                                                                                                        |
| 23  | Instrument subagent drift rate, then decide                              | **MOVE→FL** | FRICTION-LOG (D1 Strong)     | drops out of (C) tagging (was C-v+ "subagent-drift instrumentation")                                                                                                                |
| 24  | `prTextHygieneReason` reviewer auto-rejects when fine                    | **MOVE→FL** | FRICTION-LOG (D2 Weaker)     | drops out of (C) tagging (was C-v0 "prTextHygiene false-reject")                                                                                                                    |
| 25  | Upgrade root ESLint v9 → v10                                             | KEEP+TAG    | `[v+]`                       | (C)-v+ "ESLint v10"                                                                                                                                                                 |
| 26  | Check `claude-code#22583` resolved                                       | KEEP+TAG    | `[v+]`                       | (C)-v+ "claude-code#22583"                                                                                                                                                          |
| 27  | Deny rules with absolute paths don't fire outside cwd                    | KEEP+TAG    | `[v1]`                       | (C)-v1 "deny-rules"                                                                                                                                                                 |
| 28  | `/home/node/.gstack/` not volume-backed (rebuild wipes state)            | **RETAG**   | `[v+]` → `[v0]`              | **D5 / (C)-v0 "gstack volume-wipe"** (existing `[v+]` retagged)                                                                                                                     |
| 29  | `git ls-remote` HTTPS-token URL garbled                                  | **MOVE→FL** | FRICTION-LOG (D2 Weaker)     | drops out of (C) tagging (was C-v1 "ls-remote garbled"); strip existing `[v+]`                                                                                                      |
| 30  | Filesystem-lock erosion via git operations                               | KEEP        | already `[v1]` — keep        | (C) implies v1; no retag                                                                                                                                                            |
| 31  | Pre-ship gate: middleware-matcher public-asset coverage                  | KEEP+TAG    | `[v1]`                       | (C)-v1 "middleware-matcher gate"                                                                                                                                                    |
| 32  | Email-template visual-QA gate / convention                               | KEEP+TAG    | `[v1]`                       | (C)-v1 "email-template QA gate"                                                                                                                                                     |
| 33  | Generalize ci-rollback + ci-type-drift into kit                          | KEEP        | already `[v1]` — keep        | (C)-v1 "generalize ci-rollback/ci-type-drift"; matches existing tag, no retag                                                                                                       |
| 34  | Root-cause: operator stashes vanish during merge                         | KEEP        | already `[v0+]` — keep       | not in (C) lists; already tagged + already a PLAN row (`stash-vanish-root-cause`). Leave `[v0+]` as-is `[spec-inferred]`                                                            |
| 35  | Port `tap-feedback` press-state to template globals.css                  | KEEP+TAG    | `[v1]`                       | (C)-v1 "tap-feedback port"                                                                                                                                                          |
| 36  | `/ak-check-docs-and-tests` scaffolds orphan review.md stubs              | KEEP+TAG    | `[v0]`                       | (C)-v0 "review.md doc-only scaffold"                                                                                                                                                |
| 37  | `/ak-pre-ship` + Phase 5.9 visual-evidence deferrals rubber-stamped      | **MOVE→FL** | FRICTION-LOG (D2 Weaker)     | **conflict: appears in BOTH (C)-v0 "doc/test silent-drift"? no — (C)-v0 lists it implicitly + (C)-v1 "visual-evidence rubber-stamp". D2 overrides: MOVE.** drops out of (C) tagging |
| 38  | PR-body adds `supabase db push` even when deploy-migrations.yml exists   | KEEP+TAG    | `[v1]`                       | (C)-v1 "supabase-db-push redundancy"                                                                                                                                                |
| 39  | `/ak-go-live` Step 1.7 auth-config reminder doesn't fire first-deploy    | KEEP+TAG    | `[v1]`                       | (C)-v1 "go-live auth reminder"                                                                                                                                                      |
| 40  | Convention: auth-callback handler must `Sentry.captureException`         | KEEP+TAG    | `[v1]`                       | (C)-v1 "Sentry auth-callback convention"                                                                                                                                            |
| 41  | doc/SKILL.md edit can drift a bats test silently                         | **MOVE→FL** | FRICTION-LOG (D2 Weaker)     | **conflict: (C)-v0 lists "doc/test silent-drift". D2 overrides: MOVE.** drops out of (C) tagging                                                                                    |

Two advisor-probe rows (8, 9) and the stash-vanish row (34) carry the `[spec-inferred]` flag — (C) doesn't name them explicitly. **Operator: double-check (8) v+, (9) v1, and that (34) keeps `[v0+]` rather than being re-bucketed.** Note rows 11 and 41 resolve a conflict where (C) had tentatively listed the item under a `[vN]` bucket: D1/D2 (move to FRICTION-LOG) win, so they drop out of tagging entirely — confirmed for all 7 moved items.

## Friction-log entry drafts (7)

Each draft below is ready to feed `/ak-record-friction-log` in Phase 2 (Step 2 will scan-before-add; all 7 are expected to be no-match → new entries). Impact = severity **if it recurs**. First seen / session ref = `2026-05-29 — triage-todos-to-friction-log (first FL population)`.

---

### Draft 1 — Layer-B CLAUDE.md classification gate doesn't re-fire at the `/ak-merge-devshop` squash boundary

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — if the squash truly bypasses Layer B, every squash-merged CLAUDE.md change silently skips the classification gate (a structural blind spot in the canonical merge path); but blast radius is audit-trail completeness, not a broken gate.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-29 (`claude-md-regrowth-prune` build, spec D8)
- **Sessions**:
  - 2026-05-29 — `claude-md-regrowth-prune` build; two squash-merge CLAUDE.md edits landed on main with no `Claude-MD-Classification:` trailer.
- **Symptom**: a squash-merge commit that modified devshop `CLAUDE.md` lands on `main` with no `Claude-MD-Classification:` trailer, even though `check-claude-md-classification.sh` should block any staged CLAUDE.md `+` line without a bypass.
- **Detail**: Observed 2026-05-29: `412f20b` (worktree devshop-mode clause) and `8cdda99` (propagation clause) each `+1/-1`'d CLAUDE.md and merged clean. Layer-B contract fires on any staged CLAUDE.md edit with `+` lines and BLOCKS without a `devshop.claudeMdClassification` bypass — so the squash `git commit` should have blocked. **Hypothesis**: `/ak-merge-devshop`'s squash (`git reset --soft $ANCHOR && git commit -F`) either runs with `--no-verify` (structural blind spot — every squash-merged CLAUDE.md change skips the gate) OR the per-commit classification fired on the feature branch but doesn't surface on the squashed commit's trailer (gate working; only audit-time harvest incomplete). **To resolve**: (1) confirm whether the `/ak-merge-devshop` squash runs pre-commit at all; (2) if `--no-verify`, decide whether Layer B should re-gate the net CLAUDE.md delta at squash time, or rely on per-commit classification pre-squash and document the squash-trailer absence as expected; (3) wire the `Claude-MD-Classification:` trailer into `/ak-docs-review § Section E` harvest (`f875263`'s own body flagged this "not yet wired"). NOT a Layer-B rewrite — a coverage/harvest gap. References `kit/scripts/commit-hooks/check-claude-md-classification.sh` + `.claude/skills/devshop/merge-devshop/SKILL.md` + `kit/docs/guide/claude-md.md § Enforcement`.
- **Promotion target**: `kit/TODOS.md` (confirm squash pre-commit behavior + wire trailer harvest) or `kit/ROADMAP.md` if it becomes a Layer-B re-gate.

---

### Draft 2 — Mac host-resource constraints suspected as the real cause of `blocked` QA outcomes

- **Score**: 4 (impact 4 × count 1)
- **Impact**: 4 (L) — if confirmed, the host-resource pressure recurs across every browser-gate run on a loaded Mac, and the shipped workspace-tooling fixes (Chromium apt-bake, env-aware Supabase ports) don't address it — an ongoing recurring tax masquerading as tooling gaps.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-19 (`sandbox-qa-close-gap` PR, codifying home-os PR #27/#28)
- **Sessions**:
  - 2026-05-19 — `sandbox-qa-close-gap`; operator pushback flagged host-resource hypothesis over the tooling-gap framing.
- **Symptom**: browser gates / QA on lalista + home-os run fine for many PRs, then start emitting `blocked` outcomes — correlated with host Mac resource pressure (Docker Desktop Resource Saver, swap, heavy host apps), not a tooling-not-installed cause.
- **Detail**: Codified 2026-05-19. Original ROADMAP framing attributed home-os PR #27/#28 `blocked (n/a per scope: sandbox)` outcomes to workspace tooling gaps; operator pushback: "QA was working on many PRs… until it didn't, and it seemed to be about resource constraints on my host Mac." **What to investigate**: (1) re-read PR #27/#28 audit comments — was `blocked` reason "Chromium failed to launch" / OOM / "Playwright timeout waiting for browser" (resource pressure) or tooling-not-installed? (2) cross-correlate failure timestamps with Docker Desktop Resource Saver activity, macOS `vm_stat` swap, heavy host apps; (3) controlled test — rebuild home-os devcontainer with all gates intact, close every other macOS app, run `/ak-pre-ship` on a no-op branch; clean pass confirms the hypothesis. **Likely fixes if confirmed (pick one)**: (a) Docker Desktop memory cap bump; (b) concurrency cap in-container (`--max-workers=2`, Playwright `workers:1`); (c) `/ak-pre-ship` preflight resource check emitting `findings(1)` when free memory < threshold. Cross-ref: `sandbox-qa-close-gap` only fixed the iptables port issue; `kit/notes/projects/home-os.md` for PR #27/#28 details.
- **Promotion target**: `kit/ROADMAP.md` (once hypothesis confirmed/refuted, with a concrete fix shape) — until then a debugging breadcrumb.

---

### Draft 3 — Subagent drift rate uninstrumented; cleanup-pattern decision deferred

- **Score**: 2 (impact 2 × count 1)
- **Impact**: 2 (S) — measure-then-decide work; if subagents do drift repo state across many spawns it's a recurring low-grade hygiene tax, but the decision gate may well say "skip" (<5% drift). Friction on an uncommon path.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-04-19 (documented; phased plan in `kit/notes/roadmap/subagent-cleanup-pattern.md`)
- **Sessions**:
  - 2026-04-19 — documented the measure-before-build plan after the hook-injection migration.
- **Symptom**: no data exists on how often `/ak-build` / `/ak-implement` subagents leave the repo in a drifted state after a spawn, so there's no basis to decide whether a cleanup pattern is worth codifying.
- **Detail**: Phased plan in `kit/notes/roadmap/subagent-cleanup-pattern.md`. Phase 1 adds a deterministic bash logger (`subagent-drift-log.sh`) at `Agent()` call-sites that snapshots repo state before+after each spawn and writes deltas to a gitignored log. Phase 2 (contingent on Phase 1 data) codifies a clean-state prompt block in `kit/docs/guide/agents.md` + optional helper `check-subagent-cleanup.sh`. **Decision gate after ~30 spawns**: <5% drift → skip Phase 2; 5–15% → prompt block only; >15% or multi-session accumulation → full helper + bats tests. **Hard guardrail**: pattern MUST stay at the prompt/agent-to-agent layer — a `SubagentStop` hook would recreate the hook-injection bug the 2026-04-19 migration killed.
- **Promotion target**: `kit/ROADMAP.md` (Phase 1 instrumentation) — the long-form plan already lives in `kit/notes/roadmap/subagent-cleanup-pattern.md`.

---

### Draft 4 — `prTextHygieneReason` reviewer auto-rejects even when PR text is fine

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — if it recurs it blocks legitimate pushes on the common path (every non-trivial push runs the check), forcing a bypass-reason dance on correct PR text. Friction on a common path.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-04-19 (hook-migration verification)
- **Sessions**:
  - 2026-04-19 — hook-migration verification; pushed an aligned-description PR update and still got blocked with `"No reason given — automatic rejection."`
- **Symptom**: `.husky/pre-push` Check 1 invokes `adversarial-review.sh prTextHygieneReason` and FAILs with `"No reason given — automatic rejection."` even when the PR title is readable, the body matches the commits, and the body has the required `## Product update` + `## Engineering details` structure.
- **Detail**: When no bypass reason is set, the reviewer short-circuits to FAIL even though adversarial prompt item 2(a) says _"PR description genuinely matches the commits — the reviewer is wrong"_ should PASS. (A `pr`-surface primary-judgment NOTE was later added to `adversarial-review.sh` to PASS clean text on the `no reason given` placeholder — verify whether this still reproduces before promoting; the count is the signal.) Full alternatives A–E + decision trigger: `kit/ROADMAP.md § "PR-description staleness check — layer + approach decision"`. Trigger to act: post-PR-3 (`/ak-build core-flows`) data on the false-positive rate of the always-fires implementation.
- **Promotion target**: `kit/ROADMAP.md § PR-description staleness check` (layer + approach decision).

---

### Draft 5 — `/ak-pre-ship` + Phase 5.9 visual-evidence deferrals get rubber-stamped with hand-wave rationales

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — silent visual-evidence drift already spanned 3 consecutive home-os PRs; if it recurs, UI-bearing PRs keep shipping with no screenshots behind plausible-but-wrong rationales, eroding reviewer trust on the common UI-ship path.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-15 (home-os PR #19 `triage-route-handler`)
- **Sessions**:
  - 2026-05-15 — home-os PR #19; Gate 4 + Gate 13 deferred capture citing a factually-wrong "ws() interop" blocker.
- **Symptom**: a pre-ship gate defers screenshot/hero capture with a plausible-sounding technical rationale that's never verified; Phase 5.9 reads the deferral as settled and Phase 6 has no signal for "new screens shipped without any visual evidence."
- **Detail**: Home-os PR #19 deferred `/cards/[id]` capture citing "Node 20 + `@supabase/realtime-js` ws() interop blocks programmatic seed" — but the actual blocker was a firewall rebound-port mismatch, and the same workspace's E2E spec seeded users+cards via `adminClient()` (falsifying the rationale in 30s). Pattern: pre-ship subagents over-accept plausible-and-technical deferrals; orchestrator surfaces it as "findings(1) deferred" not "shipped without evidence." **Fix shape (3 places)**: (1) `/ak-pre-ship` Gate 4/Gate 13 deferral rationale must include a real error message/stack trace OR a tracker-citation infra blocker — hand-waves fail as `findings_pending`; (2) Phase 5.9 detects "new public screens (regex `^apps/[^/]+/app/\(.+\)/[^/]+/page\.tsx$`), zero hero shots" as a halt/re-attempt signal; (3) Phase 6 escalates "shipped without visuals" to a top-line `### ⚠ No visual evidence for new screens` section. Edit targets: `ak-pre-ship/SKILL.md § Gate 4 + Gate 13`, `ak-build/SKILL.md § Phase 5.9 + § Phase 6`, `kit/docs/guide/adversarial-review.md` (add screenshot/E2E deferrals to extra-scrutiny list).
- **Promotion target**: `kit/TODOS.md` / `kit/ROADMAP.md` (3-part `/ak-pre-ship` + `/ak-build` hardening).

---

### Draft 6 — A doc/SKILL.md edit can silently drift a `grep`-based bats test

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — a red suite can reach `main` when a doc edit changes text a content-validation test asserts and nothing forces them to co-update; recurs on the common doc-editing path and the failure is silent until the next full-suite run.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-28 (`1d343bf`, surfaced via parallel `/ak-merge-devshop` runs)
- **Sessions**:
  - 2026-05-28 — `1d343bf` updated 9 docs but missed the asserting test; a red suite reached main.
- **Symptom**: a SKILL.md/doc edit removes or rewrites text that a `grep`-based bats test asserts; the test goes red but nothing in the Layer-1 test-presence hooks links the edit to the test, so the drift ships silently.
- **Detail**: Layer-1 test-presence hooks catch _missing_ tests, not _stale_ ones. Worked observation: `1d343bf` (2026-05-28) updated 9 docs but missed the asserting test — test 14 in `util-build-phase58-audit-parser.bats` (a stale Phase 6 audit-comment assertion from ancestor `486a57d`) went red once `1d343bf` removed the asserted "Pre-ship audit | gates passed" text, and a red suite reached `main`. **Fix shape**: a `structural-invariants.bats` check that maps SKILL-asserting tests to their source files, OR a `conventions.md` note requiring co-update of a doc and any test asserting its content.
- **Promotion target**: `kit/TODOS.md` (structural-invariants mapping check or conventions.md co-update note).

---

### Draft 7 — `git ls-remote` via HTTPS-with-token URL produces garbled output

- **Score**: 1 (impact 1 × count 1)
- **Impact**: 1 (XS) — minor one-off with a known clean workaround (`gh api`); even if it recurs it's an aesthetic/tooling nit on the uncommon branch-cleanup path.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-04-23 (lalista-PR17 cleanup)
- **Sessions**:
  - 2026-04-23 — `/ak-clean-branches` Phase 1 against abra-kadabra; ls-remote output arrived as broken one-word-per-line fragments.
- **Symptom**: `git ls-remote "https://x-access-token:${TOKEN}@github.com/…"` returns broken fragments ("Permission", "Could", "make", "the" — one word per line) instead of `<sha>\trefs/heads/<branch>` rows; `git fetch` with the same URL works fine.
- **Detail**: `/ak-clean-branches` Phase 1 enumerates remote branches via `git ls-remote` over the HTTPS-token URL; only ls-remote broke, fetch was fine. **Workaround (shipped)**: swap to `gh api repos/meirmsn/abra-kadabra/branches --paginate --jq '.[].name'`. **Hypothesis**: token contains a special character (`$` / newline / URL-reserved) interpreted by the shell or git's URL parser, mangling argv (`/etc/devshop-env` is `echo DEVSHOP_GITHUB_TOKEN=$TOKEN` into a file). Low-effort fix: switch the skill to `gh api` unconditionally. Edit target: `.claude/skills/devshop/clean-branches/SKILL.md` (Phase 1 remote enumeration).
- **Promotion target**: `kit/TODOS.md` (swap clean-branches Phase 1 to `gh api`) — low priority.

---

## virtiofs PLAN row

D3 score: 🟡 M impact / 🟢 S risk / 🟢 S cost. **Lev = (impact_num × risk_num) ÷ cost_divisor = (3 × 2) ÷ 0.75 = 8.0.** That is higher than every existing `Planned (v0)` Lev (current max 3.6), so the row sorts to **the top of the `## Planned (v0)` table** (above `pwa-sw-baseline`). TODOS entry (#7) is kept as the long-form Source and tagged `[v0]`.

Exact row to insert as the first body row of `## Planned (v0)`:

```markdown
| `virtiofs-rebase-auto-switch` | `/ak-merge-devshop` auto-detects the virtiofs phantom-rebase failure and auto-switches to the merge-then-soft-reset fallback (no operator halt) | 🟡 M — saves a manual abort+recovery loop on a constantly-recurring merge flake | 🟢 S — operator keeps hand-driving the recognize-signature → switch-to-merge recovery on every affected rebase | 🟢 S — ~30–45 min skill edit + a bats test against a mocked rebase failure | **8.0** | — | `kit/TODOS.md` § `/ak-merge-devshop` Phase 2 / Phase 1.0 — mechanize the virtiofs phantom-rebase fallback |
```

(The Hook is 145 chars > 120 cap — Phase 2 must trim it. Suggested trim to ≤120: `` `/ak-merge-devshop` auto-detects the virtiofs phantom-rebase flake and auto-switches to the merge fallback `` = ~108 chars. Operator's final call on wording.)

## Cross-reference unwind list

Grep result analysis (`Triage TODOs vs FRICTION-LOG` + the 7 moved subjects across `kit/`, `CLAUDE.md`, `.claude/skills/`):

**Needs no rewrite — references stay (legitimate):**

- All `prTextHygieneReason` hits in `kit/scripts/adversarial-review.sh`, `kit/hooks/pre-push.sh`, `kit/tests/util-adversarial-review-narrowing.bats`, `kit/tests/structural-invariants.bats`, `kit/tests/util-ak-merge-devshop.bats`, `kit/docs/guide/{conventions,hooks}.md`, `kit/docs/OVERVIEW.md`, `CLAUDE.md:113`, `.claude/skills/devshop/merge-devshop/SKILL.md` — these reference the **check-type / engine**, not the TODOS entry. The friction-log move doesn't touch the engine. Leave all.
- All `ls-remote` hits in `kit/notes/bootstrap/v0-web.md`, `.claude/skills/devshop/merge-devshop/SKILL.md` — these are functional uses of the `git ls-remote` command, not references to the TODOS entry. Leave all.
- `kit/notes/roadmap/subagent-cleanup-pattern.md` + `kit/notes/README.md` (subagent-drift) — these are the **long-form plan doc** the moved subagent-drift item points TO. The friction-log Draft 3 preserves the pointer (`kit/notes/roadmap/subagent-cleanup-pattern.md`). Leave both — they are now referenced by the FL entry instead of the TODOS entry.

**Needs action (internal to the change):**

- The driver _Triage TODOs vs FRICTION-LOG_ entry's own sub-bullets (A)/(B)/(C) name all 7 moved items + the bucket lists by subject — these vanish when the driver entry is DELETED (D6). No external file cites them.
- No file outside `kit/TODOS.md` references the driver entry by its subject `Triage TODOs vs FRICTION-LOG` (sole hit is line 10, the entry itself).

**Conclusion**: zero orphan cross-references in other files. The only deletions are inside `kit/TODOS.md` itself. `kit/ROADMAP.md` is NOT touched (no unwind requires it). Phase 2 should re-run the grep after deletions to confirm no new orphans, but none are expected.

## Task order

1. **File the 7 friction-log entries via `/ak-record-friction-log`.** Feed each draft (Drafts 1–7) to the skill in order; expect 7 no-match → new-entry adds. The skill re-sorts `## Open` by score and may print promotion-candidate notices (Draft 2 Impact 4 will flag) — expected. Commit (the skill commits per its Step 6, or batch into one `docs(friction-log): seed 7 demoted TODOs` commit). Verify all 7 land with correct schema + sort order before proceeding.
2. **Delete the 7 moved entries + the driver triage entry from `kit/TODOS.md`; unwind cross-refs.** Remove entries #1 (driver, D6), #2, #11, #23, #24, #29, #37, #41 (the 7 moved). Re-run the § Cross-reference unwind grep to confirm no orphans. Commit atomically (`chore(todos): demote 7 premature items to friction log; delete triage driver`).
3. **Promote virtiofs to PLAN + tag the TODOS entry `[v0]`.** Insert the `virtiofs-rebase-auto-switch` row as the first body row of `PLAN.md § Planned (v0)` (trim Hook to ≤120), keep TODOS entry #7 with a `[v0]` tag appended. Commit atomically (`docs(plan): promote virtiofs phantom-rebase auto-switch to v0`).
4. **Version-tag the remaining `kit/TODOS.md` entries.** Apply the § Tag mapping table KEEP+TAG / RETAG dispositions to every remaining open entry (rows 3, 5–10, 12–22, 25–28, 30–36, 38–40 — minus the already-tagged 30/33/34). Retag #28 `[v+]`→`[v0]`; strip the stale `[v+]` from #29 (now moved, n/a). Leave #4 (`[x]` done) verbatim. Commit atomically (`chore(todos): version-tag remaining open entries per triage buckets`).

Commit atomically per task (one task = one commit). All four are devshop docs/tracker commits — bare `kit/*.md` + `PLAN.md` edits pass the doc-coverage gate, no bypass needed.

## Tests

Pure tracker/docs change — no new scripts, no new tests. Requirement: the full bats suite (`kit/tests/`) must stay green through every commit (pre-commit runs it).

**Grep of `kit/tests/` for any test asserting FRICTION-LOG.md / TODOS.md / PLAN.md content or structure: none found.** Specifically:

- `kit/tests/guard-docs-coverage-devshop.bats` asserts only a **path carve-out** — that editing `kit/TODOS.md` / `kit/ROADMAP.md` does NOT fire the docs-coverage gate (lines 250–259). This is behavioral (path-matching), not content-based, so deleting/editing TODOS entries cannot break it.
- Other tests matching `TODOS` (`firewall-extras-overlay.bats`, the `preship-*` and `util-adversarial-*` suites) create their own throwaway `TODOS.md` in a temp repo — unrelated to `kit/TODOS.md`'s content.
- No test reads `kit/FRICTION-LOG.md` or `PLAN.md` structure.

So Phase 2 has no structural-assertion test to update. The only risk is the generic "doc edit drifts a grep-based test" footgun (which is itself Draft 6) — but since no test greps these three trackers, that risk is nil here. Run `pnpm turbo run test` (or the devshop bats invocation) once at the end to confirm green.

## Gotchas

- The driver _Triage TODOs vs FRICTION-LOG_ entry is committed on the branch baseline (`1b7c80a`) and MUST be DELETED (D6). Because devshop ships via squash-merge, the entry never reaches `main` as a standalone commit — it's created and deleted within this branch's squash.
- `/ak-record-friction-log` re-sorts `## Open` by score on every call and prints promotion-candidate notices. Draft 2 (Mac host-resource, Impact 4) will trip the `Impact ≥ 4` notice; that is expected, not an error — do not act on it (promotion is the operator's later call).
- Do NOT touch `kit/ROADMAP.md` — no cross-ref unwind requires it (confirmed in § Cross-reference unwind list).
- Existing tags to handle carefully: #28 is a `[v+]`→`[v0]` **retag** (D5), not a fresh tag; #29's existing `[v+]` is stripped (it's moving to FL); #30 (`[v1]`), #33 (`[v1]`), #34 (`[v0+]`) are KEEP — do not re-tag.
- The stash-vanish entry (#34) is already both tagged `[v0+]` AND has a PLAN row (`stash-vanish-root-cause`) — leave it entirely alone; it is not in scope.
- The `[v0+]` and `[v1]` legacy tags noted in the driver's preamble ("only 2 version-tagged") under-counted — #28/#29/#30/#33/#34 carry tags. The mapping table above is authoritative over the driver's preamble count.

## Acceptance

- [ ] 7 new entries in `kit/FRICTION-LOG.md § Open`, each with the full schema (Score, Impact + why, Count=1, Status=open, First seen, Sessions, Symptom, Detail, Promotion target), sorted by Score desc.
- [ ] 8 entries gone from `kit/TODOS.md` (the 7 moved + the driver triage entry); re-running the cross-ref grep shows no orphans.
- [ ] Every remaining open `kit/TODOS.md` entry carries exactly one `[v0]` / `[v1]` / `[v+]` tag (the `[x]` done entry left verbatim, untagged).
- [ ] #28 retagged `[v+]`→`[v0]`; #29's stale tag removed (entry moved); #30/#33/#34 keep their existing tags.
- [ ] `virtiofs-rebase-auto-switch` row present at the top of `PLAN.md § Planned (v0)`, Lev 8.0, Hook ≤120 chars, Source = `kit/TODOS.md § …`; the TODOS entry kept + tagged `[v0]`.
- [ ] `kit/ROADMAP.md` untouched.
- [ ] Full bats suite green; each of the 4 tasks committed atomically.
