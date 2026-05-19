# CLAUDE.md architecture migration

> Working note + session-resumption doc for the CLAUDE.md sustainability work.
> Branches: `feature/claude-md-architecture` in both `/workspace` and `/devshop`.
> Started: 2026-05-18.

## Problem

`/workspace/CLAUDE.md` is 79k chars (33k tokens; ~5% of every conversation's context). Claude Code surfaces a warning at 40k chars. `/devshop/CLAUDE.md` is 43k chars — also over the warning, also bloated.

Three concrete symptoms:

1. **In-conversation context tax.** Every project-session turn pays 33k tokens for CLAUDE.md content most of which isn't load-bearing for that turn.
2. **`SessionStart` hook truncation.** `session-start.sh` injects `/devshop/CLAUDE.md` as `additionalContext` (workaround for `anthropics/claude-code#22583` — still OPEN as of 2026-05-08). When hook output exceeds ~2KB the harness saves the full payload to disk and surfaces only a 2KB preview. Result: devshop CLAUDE.md is currently NOT in context during project sessions — opposite of the workaround's intent.
3. **Tooling drives growth.** `/ak-docs-review § Section A` and `check-docs-coverage-project.sh` both demand that every new surface gets a `CLAUDE.md § Where Things Happen` entry. `/setup-deploy` writes deploy config to CLAUDE.md. The forcing functions all point at CLAUDE.md.

## Design principles (load-bearing — don't drift from these)

These came out of the planning conversation that preceded this note. They drive every decision in the migration.

### 1. The three layers — own the partition

- **L1 — Devshop tooling/conventions.** Owns: `/devshop/CLAUDE.md`, `/devshop/kit/docs/guide/*.md`. Examples: "Where Things Happen pattern + freshness enforcement", "test-presence is pre-commit-enforced", "Env Var Naming: base name in secrets, prefix per surface", "deploy config written by `/setup-deploy`".
- **L2 — Project-specific.** Owns: `/workspace/CLAUDE.md`, project area READMEs, `OVERVIEW.md`, `ARCHITECTURE.md`. Examples: "home-os is a home maintenance app", actual surface map, project-specific gotchas, project deploy URL.
- **L3 — Claude Code defaults.** Baked into the harness. Not in either CLAUDE.md.

Today, project CLAUDE.md fuses L1 + L2. The migration extracts L1 back to devshop (deletes the project-side restatement) and lifts truly generalizable patterns into `kit/docs/guide/*.md`.

### 2. The hook is load-bearing — and currently broken

Per `/devshop/CLAUDE.md § Context Loading` (line 34):

> **Design principle: project `CLAUDE.md` is self-sufficient for public contributors.** Because the SessionStart hook delivers `/devshop/CLAUDE.md` to project sessions at runtime, the project's own committed `CLAUDE.md` does NOT need to mention devshop conventions, point at `/devshop/...` paths, or otherwise reference the devshop side.

This means project CLAUDE.md **can be slim**, but ONLY IF the hook actually delivers devshop context. Today the hook is truncated at 2KB. **Fixing the hook is foundational to the migration, not a Wave 5 nice-to-have.**

Concrete consequence: project CLAUDE.md must NOT contain `/devshop/...` cross-references (would break for public GitHub contributors). The hook injects devshop context at runtime; the committed file does not.

### 3. The inclusion rule for CLAUDE.md content

> **Belongs in CLAUDE.md = causes SILENT wrong work if not known.**
> **Belongs in toolchain / docs = causes LOUD failure (hook block, CI red, test fail) if not known.**

Loud failures are self-teaching — toolchain catches violation, operator fixes. Silent failures need upfront memorization. This sharpens the "universal vs local" lens.

Applied to current gotchas: `.trim()`-on-env (silent 500) stays; ROLLBACK-marker (CI blocks loudly) goes (the script teaches it).

### 4. Strict default + documented escape hatch

Hard caps alone are too strict (false negatives). Solution mirrors the existing `Docs-Coverage-Bypass:` trailer pattern:

- Mechanical default-block via pre-commit hook (size cap + section allowlist).
- Escape via `CLAUDE-MD-Bypass: <reason>` commit trailer + `<!-- justified: ... -->` inline marker in the file.
- Helper script `kit/scripts/justify-claude-md.sh` produces both in one operator action.
- `/ak-docs-review` Section E harvests bypasses + markers + periodically re-examines.

### 5. The lalista precedent — adopt the classification pattern

`/devshop/kit/notes/lalista-claude-md-classification.md` did this exact exercise on lalista with a 3-class taxonomy:

- **Already in devshop — delete + pointer.** Gotcha is already covered in `kit/docs/guide/*` or `/devshop/CLAUDE.md`. Project deletes the duplicate. The hook delivers the canonical version at runtime.
- **Generalizable — lift.** Gotcha is stack-wide / pattern-wide. Lift into a new section in an existing `kit/docs/guide/*.md` (or create a new guide doc). Delete from project CLAUDE.md.
- **Project-specific — stay.** Gotcha is load-bearing on this project's specific column / RPC / route names. Leave verbatim in project CLAUDE.md.

For each "stay" entry, consider whether a synthetic generalizable pattern can be lifted alongside (rows S1/S2/S3 in the lalista note — pattern lifted via "DB constraint as loud structural backstop" while the specific instance stays).

## Wave plan

Tracked via TaskCreate this session (#1-#5). One commit per wave in each repo. Both repos move together within each wave where applicable.

### Wave 1 — Foundation docs

**Status**: ✅ COMPLETE (committed 2026-05-18). Project: `f25822c`. Devshop: `e8ce1dd`.

Outputs:

- `/devshop/kit/notes/claude-md-migration.md` (this file) — captures plan + decisions.
- `/devshop/kit/docs/guide/claude-md.md` — convention doc; inclusion rule + section allowlist concept + 3-class taxonomy + bypass mechanism. Source of truth for Layers 1-2 of enforcement.
- `/workspace/DEPLOY.md` — extracted Vercel deploy config from project CLAUDE.md.
- `/workspace/KNOWN-ISSUES.md` — operational known-broken-behavior entries (Safari Private Browsing, Supabase SMTP rate limit, callback error swallowing).
- `/workspace/TODOS.md` — operator Vercel-dashboard items lifted from project CLAUDE.md.
- **Classification table** — apply lalista's 3-class taxonomy to home-os's 25+ gotchas + Where Things Happen entries + Stack/Env Var/Migration/Deploy sections. Drives all subsequent waves. Table can live inline in this note (§ Classification below) or as a separate file.

### Wave 2 — Area docs populated

**Status**: ✅ COMPLETE (committed 2026-05-18). Wave 2a project: `181090e`. Wave 2b devshop: `7572bcf`.

Outputs:

- `/workspace/apps/web/README.md` (NEW) — routes, API handlers, components, middleware, providers. Receives all `apps/web/...` Where Things Happen entries.
- `/workspace/supabase/README.md` (NEW) — migrations, RPCs, RLS policies, storage, capture-flow / triage-route / triage-conversation / decide-state / planned-state schema lineage.
- `/workspace/packages/core/README.md` (NEW) — typed Supabase factory, prod-URL guard, shared models, Zod schemas.
- `/workspace/packages/ui/README.md` (NEW) — design tokens, primitive components.
- `/workspace/supabase/functions/README.md` — only when edge functions exist (currently none).
- Devshop side: extended `migrations.md` (+3 sections: OUT-param collisions, Supabase Cloud GRANT posture, return-table function dependency); extended `supabase-ssr-boilerplate.md` (+ Pattern 11: App Router layout-vs-page race); extended `ops.md § Known Footguns` (+ Vercel 4096-byte env-var cap); created `llm-trust-boundaries.md` (NEW guide for LLM-output trust boundaries); created `date-handling.md` (NEW guide for calendar-date traps); updated routing index with 4 new routing rows + 2 alphabetical-list entries.

ARCHITECTURE.md § Module map already has a `README` column with `(added when content warrants)` placeholders — Wave 2 fills them in.

Per home-os classification: 2 already-in-devshop (rows 3 + 27 — covered by existing guides + conventions.md ROLLBACK rule), 12 generalizable lifts went into 4 existing devshop guides + 2 new guides as planned.

### Wave 3 — Trim project CLAUDE.md + relocate code-level gotchas

**Status**: ✅ COMPLETE (committed 2026-05-18) for project; devshop deferred (see below).

- **Project CLAUDE.md trimmed from 79063 → 6353 chars (92% reduction).** Final shape: orientation pointers + project paragraph + Stack one-liner + 3 stay-class gotchas (Q&A location dual-write tolerance, users.location verbatim, locked-jsonb two-trust-boundaries) + Env Var Naming project-prefix table + Migration Workflow commands + Deploy one-liner. No `/devshop/...` cross-references (line-34 principle).
- **Code comments added at 2 file-specific gotcha sites** (migration 010 RPC dual-row `is_location_ask` flag rationale + `cards/[id]/page.tsx` `isReminderDue` two-layer-by-design note). The other 4 file-specific gotchas from the classification (rows 4, 15, 19, 26 → anthropic.ts, answer/route.ts, ChoosePath.tsx, ReminderEditor.tsx) were already codified as comments during their original PRs — verified in-place during this wave; no edits needed.
- **Devshop CLAUDE.md trim deferred.** The per-the-convention rationale: devshop CLAUDE.md is allowed to carry L1 convention summaries that project CLAUDE.md isn't (claude-md.md guide § Section allowlist § Devshop CLAUDE.md). A proper trim requires systematic LOUD-vs-silent classification of devshop's own ~30 § Non-Negotiables + § Known Footguns entries — that's a separate exercise scoped to devshop's own workflow, not the project migration. The 44k devshop CLAUDE.md only affects devshop sessions (when working IN /devshop), not project sessions (where the SessionStart hook delivers it — and even that hook delivery is what Wave 5 fixes). Project session context budget is now FREE of devshop CLAUDE.md content; the devshop's own session budget is the only place where 44k matters, and devshop development sessions don't suffer the same context tax as feature-implementation sessions. Tracked in `kit/TODOS.md` (to be added) for the deeper exercise.
- **Final size measured for Wave 4 cap**: project = 6353 chars. Wave 4 sets cap = ~9000 chars (measured + ~40% headroom).

### Wave 4 — Enforcement layer

**Status**: ✅ COMPLETE (committed 2026-05-18).

**Architecture pivot mid-wave**: dropped the mechanical Layer B gates (size cap + section allowlist) in favor of pure judgment-based hygiene via Layer C (`/ak-docs-review` Section E). Reasoning: the router (Layer A — operating via the routing index pointing at `claude-md.md`) prevents the dominant accidental-drift source; the adversarial reviewer catches everything else with full context; mechanical gates were doing redundant work AND created friction for legitimate exceptions (operator wanting to add a new entry or section in the rare case it's genuinely needed). Captured in the convention doc as Q6.

Outputs:

- `kit/docs/guide/claude-md.md` updated — § Enforcement rewritten: Layer B (mechanical gates) removed entirely; Layer A (write-time router) + Layer C (adversarial audit) are the only enforcement layers. Bypass mechanism (trailer + inline marker) preserved but redefined as **informational artifact** (durable justification for entries the reviewer might challenge), NOT a gate-bypass.
- `kit/scripts/justify-claude-md.sh` (new, executable) — operator helper. Prints the inline marker text + commit-trailer text given a reason. Rejects empty / placeholder reasons. Smoke-tested.
- `kit/scripts/commit-hooks/check-docs-coverage-project.sh` updated — CLAUDE.md dropped from the trigger map. New surfaces under `apps/*/`, `packages/*/src/`, `supabase/functions/*/` demand the AREA README (when present), not CLAUDE.md. Stale-ref scan still includes CLAUDE.md so pre-migration entries get caught when their source paths are deleted.
- `.claude/skills/ak-docs-review/SKILL.md` updated — Section A project rubric flipped (route per area README; CLAUDE.md is no longer a destination, only a fallback for project-specific stay entries that survived the inclusion-rule test). Step 2 reference doc set expanded (`KNOWN-ISSUES.md`, `DEPLOY.md`, `kit/docs/guide/claude-md.md`, `supabase/README.md` added; per-area READMEs reframed as the canonical surface map). New Section E (CLAUDE.md hygiene) — 5 sub-steps (inclusion-rule sweep, section sweep, inline marker re-examination, CLAUDE-MD-Bypass trailer harvest, size trend reporting). Section E is the canonical hygiene gate.
- `kit/docs/guide/README.md` routing-index entry for `claude-md.md` updated to drop "section allowlist" / "mechanical bypass" language; reflects judgment-based posture.

Not built:

- ~~`kit/scripts/commit-hooks/check-claude-md-budget.sh`~~ — dropped per the architecture pivot.
- ~~`kit/config/claude-md-sections.txt`~~ — dropped per the pivot.
- `/ak-build` Phase 5.x router — no explicit code change needed. The routing flows through the existing chain: `/ak-spec` Step 1.5 + `/ak-implement` Step 1 consult `kit/docs/guide/README.md` routing index, which fires `claude-md.md` as a target for any `CLAUDE.md`-touching work. Claude reads the convention doc and routes accordingly. Downstream gates (coverage hook + Section E audit) catch misroutes.

Cap target: deferred to N/A (no mechanical cap; the reviewer reports size trends but doesn't enforce a threshold).

### Wave 5 — Symmetric devshop CLAUDE.md trim + hook payload fits naturally

**Status**: ✅ Phases 1-3 COMPLETE (this commit). Phases 4-6 in progress.

**Architecture re-decision mid-wave**: Originally Wave 5 was going to fix the hook truncation via Option A (pointer) or Option B (curated subset). User pushed back: "the two claude.md to be 1:1 with their repo right? and then when working on a project somehow load the devshop claude.md (and if working on the public repo, just get to a no-op type of thing)" — and later "i don't want the warning on devshop sessions either. As we said, equivalently (and appropriate) hierarchical approach to either devshop and projects repos." The symmetric answer: trim devshop CLAUDE.md the same way the project's was trimmed (3-class taxonomy, lift recipe-heavy content to guide docs, keep silent-failure traps + framing). Then the existing hook inlining mechanism just works — no special pointer or curation logic needed.

- **Phase 1 — Classification**: `kit/notes/devshop-claude-md-classification.md` produced. Per-section + per-entry taxonomy (stay / condense+pointer / lift / delete). Projected slim CLAUDE.md ~20-25k chars from 44k.
- **Phase 2 — Guide coverage verification + lifts**: Added 2 new sections + 1 extension to existing guides for the lift targets that weren't already covered:
  - `kit/docs/guide/conventions.md § Verify state before public assertion` (NEW)
  - `kit/docs/guide/conventions.md § Closing TODO / ROADMAP entries when a fix ships` (NEW — moved from devshop CLAUDE.md per the trim)
  - `kit/docs/guide/security.md § Authoring locked files (denied-path recipe)` (NEW — `/tmp + sudo install -m 0644 -o root -g root` recipe lifted from devshop CLAUDE.md)
  - `kit/docs/guide/ops.md § Browse daemon binary drift` + `§ Playwright cache population` (NEW subsections extending the Chromium symlink coverage)
- **Phase 3 — Trim devshop CLAUDE.md**: 44041 → 21890 chars (50% reduction). Section-by-section trim per the classification. § Known Footguns went from ~24k to ~8k via condense-to-summary-+-pointer for recipe-heavy entries. § Two repos / Devshop shipping flow condensed to 3-step summary + skill pointers. § Adversarial Layer 2 reviews paragraph collapsed to one-sentence rule + multi-guide pointer.

**Hook payload behavior (correction post-verification 2026-05-19)**:

- Project session SessionStart hook output is now ~28.7k after the trim (was ~49.6k pre-trim).
- **Earlier mental model was wrong.** I described a "truncation threshold" between 32k and 49.6k that the trim was meant to fit under, with the 2KB number as "preview length after truncation." That framing conflated two distinct mechanisms.
- **Actual behavior** (confirmed by operator's fresh session): the harness **always** persists the full hook payload to disk + **always** inlines a ~2KB preview into the conversation, regardless of total payload size. There is no "threshold" that drops content. The 2KB cap is a display convention for the inline preview only; the full payload is reachable via Read on the persisted file path that the harness exposes in the SessionStart system reminder.
- **What the Wave 5 trim actually achieves**:
  - (a) Devshop sessions stop tripping the 40k Claude Code warning (native auto-load of 22k devshop CLAUDE.md is under the threshold).
  - (b) When Claude Reads the persisted hook output (or is told to), the content cost is smaller (22k vs 44k for devshop CLAUDE.md inside the payload).
  - (c) Symmetric architecture (project + devshop CLAUDE.md both 1:1 with their repos).
  - (d) Public contributors cloning project on GitHub see only project CLAUDE.md — no broken pointers.
- **Practical implication**: in a fresh project session, Claude has the 2KB inline preview eagerly + can Read the persisted file path to load full devshop CLAUDE.md on demand (the fresh-session verification confirmed Claude does exactly this — "Read 2 files" before reporting verification). The architecture is correct; the original framing of "fix the truncation" was the wrong target. The right target was "make the file Claude reads on demand smaller + symmetric across repos," which the trim achieves.

**Net effect by session type after this trim**:

| Session                  | Auto-loaded                                                                               | Warning?                           |
| ------------------------ | ----------------------------------------------------------------------------------------- | ---------------------------------- |
| `/devshop` dev           | 21.9k devshop CLAUDE.md (native auto-load)                                                | No (under 40k threshold)           |
| `/workspace` project dev | 7.5k project CLAUDE.md (native) + 21.9k devshop CLAUDE.md (via hook, no longer truncated) | No (each file under 40k threshold) |
| Public contributor       | 7.5k project CLAUDE.md only — no `/devshop/` available, hook doesn't run                  | No                                 |

**Phases 4-6 status**:

- **Phase 4 — Hook payload verification**: ✅ Confirmed by operator's fresh session 2026-05-19. The full ~28.7k payload (including devshop CLAUDE.md lines 77-285) is persisted to disk and accessible via Read on the persisted file path that the SessionStart system reminder exposes. Earlier framing of "truncation threshold" was incorrect — see § Hook payload behavior (correction) above. The Wave 5 trim achieved its real targets (warning resolved + symmetric + smaller-on-demand-read).
- **Phase 5 — Layer A routing smoke test**: Verified mechanically via the bats suite (`guard-docs-coverage-project.bats` passing on the new shape — new-file-under-`apps/web/` demands `apps/web/README.md` not CLAUDE.md). Real-world e2e via `/ak-build` is the canonical exerciser; first feature implementation after the migration is the natural smoke test.
- **Phase 6 — Migration close-out**: This note's final form (you're reading it).

## Final shape (post-migration)

| Surface                        | Pre-migration                                      | Post-migration                                                                                                                                                               |
| ------------------------------ | -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/workspace/CLAUDE.md`         | 79041 chars (33k tokens)                           | 7485 chars (~91% reduction)                                                                                                                                                  |
| `/devshop/CLAUDE.md`           | 44041 chars                                        | 22261 chars (~50% reduction)                                                                                                                                                 |
| Hook payload (project session) | ~49.6k (truncated to 2KB preview)                  | ~30.9k (fits below threshold)                                                                                                                                                |
| Claude Code 40k warning        | Triggered on both files                            | Neither file triggers                                                                                                                                                        |
| Per-area READMEs               | None (placeholders in ARCHITECTURE.md)             | 4 populated (`apps/web/`, `supabase/`, `packages/core/`, `packages/ui/`)                                                                                                     |
| New devshop guides             | n/a                                                | 2 created (`llm-trust-boundaries.md`, `date-handling.md`)                                                                                                                    |
| Extended devshop guides        | n/a                                                | 5 (`migrations.md`, `supabase-ssr-boilerplate.md`, `ops.md`, `conventions.md`, `security.md`)                                                                                |
| Enforcement layer              | None (per-commit hooks demanded CLAUDE.md updates) | Write-time router (Layer A via routing index → `claude-md.md`) + adversarial audit (Layer C via `/ak-docs-review` § Section E). No mechanical size cap or section allowlist. |
| Bypass mechanism               | n/a (no gate to bypass)                            | Informational artifact: `CLAUDE-MD-Bypass:` trailer + `<!-- justified: ... -->` inline marker. Helper at `kit/scripts/justify-claude-md.sh`.                                 |
| 3-class taxonomy adoption      | Lalista-only (1 instance)                          | Lalista + home-os + devshop (3 instances). Pattern codified in `kit/docs/guide/claude-md.md`.                                                                                |

## Commit history (this migration)

Project repo (`feature/claude-md-architecture` branch in `/workspace`):

- `f25822c` — Wave 1: DEPLOY.md + KNOWN-ISSUES.md + TODOS Vercel items
- `181090e` — Wave 2a: 4 area READMEs
- `9474105` — Wave 3: project CLAUDE.md trim 79k → 6.4k + code comments

Devshop repo (`feature/claude-md-architecture` branch in `/devshop`):

- `e8ce1dd` — Wave 1: convention doc + migration scaffolding + home-os classification
- `7572bcf` — Wave 2b: lift home-os patterns + new llm-trust-boundaries + date-handling guides
- `0214542` — Wave 3 close-out: defer devshop trim (later reversed in Wave 5)
- `609084a` — Wave 4: enforcement layer (router + Section E audit; mechanical gates dropped mid-wave)
- `d9e228c` — Wave 5: devshop CLAUDE.md trim 44k → 22k + guide lifts

## Decisions that shaped the migration (for future reference)

1. **L1/L2/L3 layer model** — devshop conventions (L1), project specifics (L2), Claude Code defaults (L3). Project CLAUDE.md is L2; devshop CLAUDE.md is L1.
2. **Silent-failure inclusion rule** — sharper than "universal vs local." If toolchain catches it loudly, it doesn't belong in CLAUDE.md.
3. **Mechanical gates dropped mid-Wave-4** — both size cap and section allowlist eliminated. The router (Layer A) prevents accidental drift upstream; the adversarial reviewer (Layer C) catches everything else at audit time. Bypass mechanism repositioned as durable justification artifact, not gate-bypass.
4. **Symmetric devshop trim in Wave 5** — initially deferred ("devshop CLAUDE.md only matters in devshop sessions"); user reframed: "two CLAUDE.md 1:1 with their repos; no warning on either; hook just delivers the slim devshop one." The symmetric trim made the hook fix unnecessary — the existing hook mechanism now works because the payload fits.
5. **No-`/devshop/...`-paths-in-project-CLAUDE.md** — line-34 principle from devshop CLAUDE.md. Project CLAUDE.md self-sufficient for public GitHub contributors; the SessionStart hook is the runtime bridge.
6. **3-class taxonomy with synthetic `S*` rows** — adopted from lalista's worked example. Project-specific-stay entries can also lift a generalizable pattern alongside.

## Future watch-items

- **First fresh project session after this commit lands**: verify devshop CLAUDE.md content shows up in `additionalContext` (not truncated to 2KB). If still truncated, trim further or examine the actual threshold.
- **First `/ak-build` after the migration**: exercise Layer A routing end-to-end. New surfaces should land in area READMEs, not CLAUDE.md.
- **First `/ak-docs-review` after the migration**: Section E (CLAUDE.md hygiene) runs for the first time. May surface entries to relocate that we didn't catch in the manual trim.
- **Upstream Anthropic fix for `#22583`** — if Anthropic ever lands the fix for `additionalDirectories` CLAUDE.md auto-load, the SessionStart hook's force-inject of devshop CLAUDE.md becomes redundant. Drop it then.

Migration complete.

## Resolved design questions (from the planning conversation)

These are captured in `kit/docs/guide/claude-md.md` § Rationale during Wave 1.

**Q1 — Cross-cutting gotcha index.** Decision: no dedicated index file. Adding one creates a maintenance surface that rots. Default: orientation pointers in CLAUDE.md route to area READMEs. Extend `/ak-status` to synthesize a consolidated gotchas view on demand. Lighter, no drift.

**Q2 — On-demand vs front-loaded navigation.** Decision: default lean. CLAUDE.md = silent-failure traps + project framing only; reading area READMEs + `kit/docs/guide/*` is part of normal work. Projects may override their own size cap if their workflow demands fatter CLAUDE.md — devshop ships defaults; project overrides are additive only (can't disable the budget itself).

**Q3 — AskUserQuestion during `/ak-build` for ambiguous routing.** Decision: removed. Router routes silently to best-guess destination; emits a per-commit transparency summary; operator catches misroutes on diff review. Bypass flow handles intentional overrides.

## Classification — apply lalista pattern to home-os

To be filled during Wave 1 by reading `/workspace/CLAUDE.md` carefully. Table shape mirrors lalista's:

| #   | Title (first 70 chars) | Classification | Target | Rationale (≤ 30 words) |
| --- | ---------------------- | -------------- | ------ | ---------------------- |

Three classifications:

- `Already in devshop — delete + pointer` (project CLAUDE.md deletes the duplicate; canonical version lives in devshop guide)
- `Generalizable — lift` (lift into existing `kit/docs/guide/*.md` section or new guide doc; delete from project CLAUDE.md)
- `Project-specific — stay` (load-bearing on this project's specific names; leave verbatim)

For each "stay", consider whether a synthetic generalizable pattern can be lifted alongside (rows S1+ in lalista).

Sections to classify (not just Gotchas — apply the lens to every section):

- Orientation block (top)
- Project paragraph
- Where Things Happen entries (~70 entries) — these mostly fan out to area READMEs (Wave 2); rare cross-cutting ones may stay
- Gotchas (~25 entries)
- Testing section
- Stack section
- Env Var Naming table
- Migration Workflow commands
- Deploy Configuration section
- Custom deploy hooks
- Vercel dashboard follow-ups (operator TODO — moves to TODOS.md, not a classification target)

## Resumption instructions (if session splits)

If a fresh session picks this up:

1. **Read this file first.** It captures the entire design conversation and current state.
2. **Check current branch state.** `git -C /workspace branch --show-current` and `git -C /devshop branch --show-current` should both be `feature/claude-md-architecture`.
3. **Check TaskCreate state.** `TaskList` should show 5 tasks; the in-progress one is the current wave.
4. **Read the lalista precedent.** `/devshop/kit/notes/lalista-claude-md-classification.md` — the 3-class taxonomy with worked examples on 26 gotchas.
5. **Read current project CLAUDE.md.** `/workspace/CLAUDE.md` — the 79k char source to be migrated.
6. **Read current devshop CLAUDE.md.** `/devshop/CLAUDE.md` — line 34 has the "project CLAUDE.md is self-sufficient for public contributors" principle that constrains migration shape.
7. **Read `kit/docs/guide/claude-md.md`** (once Wave 1 produces it) — the convention doc this work generalizes for future projects.
8. **Find the in-progress wave's checkpoint.** Each wave commits. Last commit message indicates progress. Diff to find where you are within the wave.

Open questions that may surface mid-migration get added to a `## Mid-migration open questions` section below.

## Mid-migration open questions

_(Filled as they arise. Empty at migration start.)_

## Out-of-scope (intentionally deferred)

- `/setup-deploy` skill update — low priority (rarely re-runs). Defer to a separate session after Wave 4 stabilizes.
- Cross-cutting gotcha index (Q1 above) — decided "no". `/ak-status` enhancement may follow but not in this migration.
- Anthropic upstream fix for `#22583` — passive monitoring only; Option A in Wave 5 doesn't depend on it.

## Cross-references

- `/devshop/kit/notes/lalista-claude-md-classification.md` — precedent classification work; pattern adopted.
- `/devshop/CLAUDE.md § Context Loading` (line 34) — "project CLAUDE.md is self-sufficient" principle.
- `/devshop/.claude/skills/ak-docs-review/SKILL.md` — adversarial reviewer; rewrite target for Wave 4.
- `/devshop/kit/scripts/session-start.sh` — hook that delivers devshop content; rewrite target for Wave 5.
- `/devshop/kit/scripts/commit-hooks/check-docs-coverage-project.sh` — coverage gate; rewrite target for Wave 4.
- `/devshop/.claude/skills/ak-build/SKILL.md` — Phase 5.x writes docs; rewrite target for Wave 4.
- `anthropics/claude-code#22583` — upstream bug `additionalDirectories` doesn't load CLAUDE.md; OPEN as of 2026-05-08.
