# CLAUDE.md — what belongs where, and how it stays sustainable

> **What this guide covers**: the inclusion rule that decides whether content belongs in `CLAUDE.md` or somewhere else, the adversarial placement judgment that keeps its section set from sprawling, the routing table for new content surfaces, and the bypass mechanism that lets legitimate exceptions land with audit trail. Applies to **both** the project-level `/<workspace>/CLAUDE.md` and the devshop-level `/devshop/CLAUDE.md`.
>
> **Why it exists**: CLAUDE.md is auto-loaded into every conversation turn. Unbounded growth taxes every turn's context budget and (above ~40k chars) trips a Claude Code warning. Tooling that writes to CLAUDE.md by default drove `/workspace/CLAUDE.md` to 79k chars / 33k tokens on home-os before this convention landed. This guide flips the default — area READMEs are the new home for surface inventory; CLAUDE.md is reserved for content that fails the silent-failure test below.

## The inclusion rule

> **Belongs in CLAUDE.md = causes SILENT wrong work if not known.**
>
> **Belongs in toolchain / docs = causes LOUD failure (hook block, CI red, type error, test fail) if not known.**

Loud failures are self-teaching — the toolchain catches the violation, the operator fixes it, and the lesson is delivered exactly when needed. Loud failures don't need upfront memorization, so they don't need CLAUDE.md space.

Silent failures are different — wrong work passes every gate and lands in production. The only defense is upfront knowledge. That's what CLAUDE.md is for.

**Worked examples**:

| Gotcha shape                                                                   | Inclusion rule verdict                                                           | Why                                                                            |
| ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `.trim()` on every `NEXT_PUBLIC_*` env read; trailing whitespace silently 500s | Silent → **CLAUDE.md** (or devshop guide if generalizable)                       | Type system + tests don't catch it; production-only manifestation.             |
| PostgREST returns `data: null` + populated `error` on non-existent column      | Silent → **CLAUDE.md** (lifted to devshop guide if generalizable)                | Type system says "got a row," runtime throws downstream null-deref.            |
| Every column-adding migration MUST carry a `-- ROLLBACK:` marker               | Loud → **delete from CLAUDE.md**; lives in toolchain                             | `ci-rollback-explain.sh` blocks CI on missing marker; lesson delivered loudly. |
| Anthropic SDK `web_search` server-tool name drifts with SDK version            | Borderline (loud at SDK bump via type error) → **code comment** at the call site | Survives SDK bumps; visible at the file that has to be updated.                |
| Migration 010 backfill targets PR #19's initial-read rows                      | One-off historical context → **delete**; the migration file documents intent     | Future migrations don't need this.                                             |

## What CLAUDE.md typically contains

These are the conventional sections — descriptive, not enforced. The adversarial reviewer judges fit; new sections may be added when they genuinely belong (e.g. a `## Capability flags` block when a project needs operator-pokeable feature flags). The reviewer challenges sections that don't fit the inclusion rule (e.g., a `## Vercel dashboard follow-ups` should be in `TODOS.md`).

**Project CLAUDE.md** typical shape:

- `## Project: <name>` — one-paragraph framing. Tiny. Always.
- `## Where Things Happen` — **rare cross-cutting entries only**. Most surfaces fan out to area READMEs (`apps/<x>/README.md`, `supabase/README.md`, `packages/<x>/README.md`). Entries that touch ≥3 distinct directories and have no natural home in any single area README may stay.
- `## Gotchas` — silent-failure traps that survived the inclusion-rule test. Apply the 3-class taxonomy (below) on every addition.
- `## Testing` — project-specific test commands ONLY if they differ from devshop conventions (which the hook delivers). If they match devshop conventions, omit this section entirely.
- `## Stack` — one-line summary. Full architecture diagram lives in `ARCHITECTURE.md`.
- `## Env Var Naming` — project-specific prefix table (Next.js `NEXT_PUBLIC_*`, edge function `SUPABASE_*`, etc.). The convention ("base name in secrets, prefix per surface") lives in `kit/docs/guide/ops.md § Env Var Naming Convention` and is delivered by the hook; the project-side table is the project's application of that convention.
- `## Migration Workflow` — project-specific commands ONLY (`pnpm db:reset`, `pnpm db:gen-types`, etc.).
- `## Deploy` — one-line pointer to `DEPLOY.md`. The full deploy config (URLs, project IDs, dashboard follow-ups) lives in `DEPLOY.md`, not CLAUDE.md.

**Devshop CLAUDE.md** typical shape (broader latitude — this file is its own convention surface):

- `## Devshop Conventions` — orientation block, with explicit `Context Loading` + `Session Start` subsections that document the hook contract.
- `## Philosophy` / `## Implementation Approach` — high-level posture; tiny.
- `## Non-Negotiables` — universal rules; LOUD failure cases enforced by tooling (test coverage, docs coverage, pre-commit gates).
- `## Known Footguns` — silent-failure devshop-development traps.
- Other sections per the historical devshop CLAUDE.md shape (Confidence Calibration, TODO Protocol, etc.) — these are the devshop's L1 conventions that bridge to project sessions via the hook.

## What CLAUDE.md MUST NOT contain

- **Operational known-issues** (Safari Private Browsing, SMTP rate limit) → `/workspace/KNOWN-ISSUES.md`.
- **Operator TODOs** (Vercel dashboard follow-ups) → `/workspace/TODOS.md`.
- **Surface inventory** (the bulk of "Where Things Happen") → per-area READMEs.
- **Deploy config detail** (URLs, project IDs, full hooks) → `DEPLOY.md`.
- **Devshop convention restatement** in project CLAUDE.md (`Per devshop convention…`, full restatements of test-presence rules, etc.) → lives in `kit/docs/guide/*.md`; hook delivers at runtime.
- **`/devshop/...` cross-references in project CLAUDE.md** (line-34 principle: project CLAUDE.md is self-sufficient for public contributors). Reference the canonical home only inside the hook's runtime payload, not in the committed file.
- **One-off historical context** ("migration 010 backfill targets PR #19") → the migration file / commit message is the audit trail. Delete from CLAUDE.md after the migration lands.
- **Loud-failure gotchas** the toolchain catches (CI scripts, pre-commit hooks, type errors) → the toolchain teaches the lesson on the next violation. Don't duplicate.

## The 3-class taxonomy for gotchas

Pattern adopted from lalista (`/devshop/kit/notes/lalista-claude-md-classification.md`). For every existing gotcha in a project CLAUDE.md AND every newly-discovered gotcha during implementation:

- **Already in devshop — delete + pointer.** Gotcha is already covered by `/devshop/CLAUDE.md` or `kit/docs/guide/*.md`. Project deletes the duplicate (the hook delivers the canonical version at runtime; the committed project file does not cross-reference `/devshop/...`).
- **Generalizable — lift.** Gotcha is stack-wide or pattern-wide. Lift into a `kit/docs/guide/*.md` section (extending an existing file when the topic fits; creating a new file when no existing guide owns the area). Delete from project CLAUDE.md.
- **Project-specific — stay.** Gotcha is load-bearing on this project's specific column / RPC / route names AND causes silent wrong work AND has no better home (not a single file). Leave verbatim in project CLAUDE.md.

**Project-specific — code comment** is a sub-class of "Project-specific" where the gotcha is tied to one file. Survives renames; visible in PR diffs; future reader of the file sees it. Prefer this over CLAUDE.md when the gotcha is single-file.

For each "stay" entry, consider whether a **synthetic generalizable pattern** can be lifted alongside (lalista's `S*` rows). When a project-specific instance demonstrates a stack-wide pattern, lift the pattern into a devshop guide and let the project keep the specific instance with a back-pointer in commit history (not in CLAUDE.md).

## Routing table for new content

When tooling (`/ak-build` Phase 5.x, `/setup-deploy`, ad-hoc edits) wants to document new content, route it by this table — NOT to CLAUDE.md by default:

| Content type                                                                    | Destination                                                                                                                                                     | Notes                                                                                                      |
| ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| New surface (route, API handler, component, migration)                          | Nearest area README walking up from the file's directory (`apps/web/README.md`, `supabase/README.md`, `packages/<x>/README.md`, `supabase/functions/README.md`) | If no area README owns the directory, create one (with header pointing to `ARCHITECTURE.md § Module map`). |
| New gotcha — silent + universal                                                 | `kit/docs/guide/*.md` (or `CLAUDE.md § Gotchas` if no guide owns the pattern yet)                                                                               | Apply 3-class taxonomy first.                                                                              |
| New gotcha — silent + project-specific + single-file                            | Code comment at the file                                                                                                                                        | Comment block at the function / variable that bites. Survives renames.                                     |
| New gotcha — silent + project-specific + cross-file                             | Project `CLAUDE.md § Gotchas`                                                                                                                                   | Reserved for the small set that genuinely needs CLAUDE.md placement.                                       |
| New gotcha — loud (toolchain catches it)                                        | Delete after one cycle                                                                                                                                          | The toolchain teaches on next violation.                                                                   |
| Deploy config                                                                   | `DEPLOY.md` (project)                                                                                                                                           | One-line pointer in CLAUDE.md. `/setup-deploy` writes to DEPLOY.md, not CLAUDE.md.                         |
| Operational known-issue (user-facing broken behavior)                           | `KNOWN-ISSUES.md` (project)                                                                                                                                     | Not a development trap; doesn't belong in Gotchas.                                                         |
| Operator TODO                                                                   | `TODOS.md` (project)                                                                                                                                            | Action items for the human; not for Claude.                                                                |
| One-off historical context (PR-specific backfill, migration-transition synonym) | Delete from CLAUDE.md after the work lands                                                                                                                      | Commit message + migration intent IS the audit trail.                                                      |
| Devshop convention                                                              | `kit/docs/guide/*.md` (or `/devshop/CLAUDE.md` for orientation-level posture)                                                                                   | NEVER restate in project CLAUDE.md. Hook delivers at runtime.                                              |

Each row of the routing table is enforced by `/ak-docs-review` § Section E (CLAUDE.md hygiene) and the `/ak-build` write-time router. When a destination is ambiguous, route silently to the best-guess + emit a per-commit transparency summary (`Doc routing summary: …`) so the operator catches misroutes on diff review.

## Enforcement

Three layers — upstream prevention via the router, commit-time classification + placement via the pre-commit gate, and downstream judgment via the adversarial reviewer. **No mechanical size cap and no mechanical section allowlist** — a hard allowlist was rejected in planning (Q6) because it would block a legitimately-needed new section (e.g. `## Capability flags`). Section discipline is instead enforced as an **adversarial placement judgment** at Layer B: a new section is allowed, but only when the reason proves no existing section fits. This revives the *intent* of the dropped allowlist (stop section sprawl) without its rigidity, after evidence that per-entry classification alone let CLAUDE.md regrow one well-formed entry at a time. The three layers compose:

1. **Layer A** (write-time router) prevents the dominant source of drift (`/ak-build` writing surface inventory to CLAUDE.md by default).
2. **Layer B** (pre-commit classification + placement gate) blocks intentional additions that don't pass the inclusion test — every addition must be classified, *placed*, and reviewed.
3. **Layer C** (adversarial audit) catches drift that slipped through both at audit time, with full context.

### Layer A — Write-time router (`/ak-build`, `/setup-deploy`)

Skills that author docs consult this guide's routing table BEFORE writing. Each PR that touched docs emits a transparency block at commit-message-draft time:

```
Doc routing summary:
  apps/web/README.md       +3 entries (2 surfaces, 1 gotcha)
  supabase/README.md       +1 entry  (1 migration)
  CLAUDE.md                +0 entries
```

Operator scans the block before approving. Misroutes are caught there.

### Layer B — Pre-commit classification gate (`check-claude-md-classification.sh`)

Fires on any staged CLAUDE.md edit that adds or modifies content. Pure deletions pass trivially (reducing CLAUDE.md is always good). When additions are detected, the commit is blocked unless a `claudeMdClassification` bypass flag classifies each entry.

**Bypass interface:**

```bash
git -c devshop.claudeMdClassification="trap → § <section>: <entry> — <why silent failure>; placement: <extends|NEW> — <why>" commit ...
```

Each addition must be classified as one of:

- **trap** — causes silent wrong work if forgotten. Stays in CLAUDE.md. Must also declare its **placement** (see below).
- **reference** — look-it-up information. Must be relocated to its canonical home (guide doc, area README, code comment) in the same commit.
- **convention** — already documented in a guide. Delete the CLAUDE.md duplicate (or keep a one-liner pointer if the convention is frequently violated).

Each **trap** must additionally declare *where it lands* — classification alone is no longer enough, because a well-formed trap can still be marginal or spawn a needless section. Placement is one of:

- **extends an existing section** — name the section. PASS only if it is the genuinely-closest home AND the entry is materially distinct from the entries already there (not a near-duplicate, not a sub-case an existing entry already implies). A marginal entry folds into its neighbor instead of standing alone.
- **NEW section** — a `## ` / `### ` header the diff introduces. PASS only if the reason names why *no* existing section fits. New sections are the dominant regrowth vector, so the bar is high — default REJECT.

The adversarial reviewer (Sonnet, `claudeMdClassification` check-type in `adversarial-review.sh`) judges: (a) classification accuracy against the inclusion rule + routing table, (b) that reference/convention relocations actually landed in the same commit (destination file staged), (c) that trap entries genuinely cause silent wrong work, (d) no content-free classifications, and (e) **placement fit** — each trap's target section holds up against the existing-section list and surrounding entries; a new section is justified only when no existing section fits.

**Trailer:** `Claude-MD-Classification:` appended by `prepare-commit-msg` for audit-time harvesting. Full bypass-flag and check-type documentation: `kit/docs/guide/hooks.md § Bypass flags + env hatches`.

### Layer C — Adversarial audit (`/ak-docs-review` § Section E)

The canonical hygiene gate. On every `/ak-docs-review` invocation (audit-time, not per-commit), the reviewer reads ALL of current CLAUDE.md and judges:

**Inclusion-rule sweep** — for every entry under `## Gotchas` (and any other content section), is it silent-failure-causing AND not a candidate for a closer home (area README, code comment, devshop guide)? Findings:

- **VERIFIED** — entry passes the inclusion rule; belongs in CLAUDE.md.
- **CHALLENGE** — entry could plausibly relocate now (a new area README owns the directory, the toolchain now catches the failure loudly, the lift to a devshop guide has landed since the entry was written). Reviewer proposes a destination + asks operator to confirm or override.
- **RELOCATE** — strong recommendation to move; high-severity finding.

**Section sweep** — for every `## ` header, does it match a recognized purpose per § What CLAUDE.md MAY contain? Sections that don't (e.g. a `## Vercel dashboard follow-ups` that should be in `TODOS.md`) → CHALLENGE with a proposed destination.

**Inline-marker re-examination** — all `<!-- justified: -->` markers re-judged regardless of whether the surrounding entry was touched in the audit range. Markers grant **deferred review**, not permanent immunity.

**Bypass trailer harvest** — `CLAUDE-MD-Bypass:` trailers from the audit's commit range are matched against inline markers in HEAD. Trailer without marker → finding (the operator added a trailer but forgot the inline marker, OR the entry was deleted later — either case wants surfacing).

**Size trend** — reports current size vs. the prior audit's snapshot. The reviewer doesn't enforce a threshold but flags growth rate (e.g., "CLAUDE.md grew by 3k chars across 5 entries since last audit; here are the 5 entries").

The reviewer doesn't block commits — it produces findings for the operator + audit log. Severity follows the existing rubric (`high` halts audit; `medium` recorded in `review.md` at Phase 6; `low` noted in `review.md`).

### Durable justification artifacts

Two complementary trailer mechanisms exist for CLAUDE.md additions:

- **`Claude-MD-Classification:`** trailer — emitted by Layer B's `prepare-commit-msg` hook when the `claudeMdClassification` bypass flag is set. Records the per-entry classification (trap/reference/convention) at commit time. This is the primary mechanism for new additions.
- **`CLAUDE-MD-Bypass:`** trailer + `<!-- justified: ... -->` inline marker — the legacy informational mechanism. The inline marker carries the justification next to the entry, re-examined by every `/ak-docs-review` run. Operator workflow: `kit/scripts/justify-claude-md.sh "<reason>"` inserts the marker and prints the trailer text.

Both trailers travel with the commit (survive rebase, push, clone) and are harvested at audit time.

## Rationale (design decisions captured during the planning conversation that produced this guide)

**Q1 — Cross-cutting gotcha index.** No dedicated index file. Adding one creates a maintenance surface that rots. Default: orientation pointers in CLAUDE.md route to area READMEs and `kit/docs/guide/*.md`. `/ak-status` may synthesize a consolidated gotchas view on demand if the operator asks; that synthesis is preferable to a maintained file because the source-of-truth files don't drift from themselves.

**Q2 — On-demand vs front-loaded navigation.** Default lean. Reading area READMEs and `kit/docs/guide/*` is part of normal work; the navigation cost is real but bounded. No size cap enforces this — the reviewer + the operator's diff-review keep CLAUDE.md from drifting back.

**Q6 — Layer B mechanical gate added after 41% regrowth evidence.** Initial plan (Wave 4) dropped Layer B in favor of pure judgment-based hygiene. After the Wave 5 trim, devshop CLAUDE.md regrew by ~41% within weeks — proving that judgment-only enforcement (Layers A + C) was insufficient for CLAUDE.md specifically. Layer B (`check-claude-md-classification.sh`) adds a commit-time gate: every addition must be classified (trap/reference/convention) and adversarially reviewed. The gate complements Layer A (prevents accidental drift from skills) and Layer C (catches drift that slipped through both) — Layer B prevents intentional additions that don't pass the inclusion test. Size cap and section allowlist remain dropped (those catch accidental drift; the router handles that upstream).

**Q3 — Interactive escalation in `/ak-build`.** No `AskUserQuestion`-style mid-task interruption. The router routes silently to its best-guess destination; the operator catches misroutes on diff review and overrides via the bypass mechanism. Mid-task interruption was nice-to-have and not foundational; removing it makes the design more uniform.

**Q4 — `/devshop/...` cross-references in project CLAUDE.md.** Forbidden (per devshop CLAUDE.md line-34 principle: "project CLAUDE.md is self-sufficient for public contributors"). The hook bridges the two layers at runtime; the committed file does not. When a convention applies project-side, either lift it into project-side guidance (project CLAUDE.md / area README) or trust the hook to deliver it at runtime.

**Q5 — Lalista 3-class taxonomy as the canonical pattern.** Adopted wholesale. Synthetic `S*` rows extend the pattern when a project-specific instance demonstrates a stack-wide pattern worth lifting alongside.

## Migration recipe for an existing project

When applying this convention to a project whose CLAUDE.md is already bloated:

### Step 1 — Classify every section + gotcha against the 3-class taxonomy

Produce `kit/notes/<project>-claude-md-classification.md` mirroring the format of the existing worked examples:

- `kit/notes/home-os-claude-md-classification.md` — fullest worked example. 28 gotchas + every non-Gotcha section classified. Sub-classes: stay verbatim / stay condense+pointer / lift / code-comment / delete-loud-or-historical.
- `kit/notes/lalista-claude-md-classification.md` — earlier instance (pre-migration). 26 gotchas with the original 3-class taxonomy + synthetic S-rows. Useful as a second worked example; format slightly older than home-os's.
- `kit/notes/devshop-claude-md-classification.md` — applied to devshop's own CLAUDE.md. Demonstrates the taxonomy on L1 (devshop convention) content.

For lalista specifically: the existing classification file is a starting point. Re-run against current state — some entries may now be covered by guide docs that didn't exist at the time (e.g., `llm-trust-boundaries.md`, `date-handling.md`, the new `conventions.md § Verify state before public assertion`, the new `security.md § Authoring locked files`).

### Step 2 — Verify each lift target has the canonical recipe

For every "Lift to `kit/docs/guide/*.md`" entry, grep the target for distinctive phrases from the source content. If the recipe isn't there yet, **add it before deleting from project CLAUDE.md**. Method: see `kit/notes/migration-info-loss-audit.md` for the home-os pattern (grep per entry).

If lifting to a NEW guide doc, also update `kit/docs/guide/README.md`'s routing index (add a routing row + alphabetical-list entry).

### Step 3 — Populate area READMEs from the Where Things Happen entries

Fan out by nearest directory (`apps/<x>/README.md`, `supabase/README.md`, `packages/<x>/README.md`, `supabase/functions/README.md`). Each entry from project CLAUDE.md § Where Things Happen routes to ONE of these by file path. Cross-cutting entries that touch ≥3 distinct directories may stay in CLAUDE.md, but in practice they're rare.

### Step 4 — Move operational content out

- Known user-facing issues (Safari Private Browsing, SMTP rate limit, etc.) → `KNOWN-ISSUES.md`.
- Operator TODOs (dashboard config follow-ups, etc.) → `TODOS.md`.
- Deploy config detail (URLs, project IDs, hooks, status commands) → `DEPLOY.md`.

### Step 5 — Trim project CLAUDE.md

Apply the inclusion rule: keep only silent-failure-causing entries that have no closer home. The home-os trim went 79k → 7.5k (91% reduction). Lalista's may differ depending on how much of its current CLAUDE.md is project-specific stay-class.

### Step 6 — Trim devshop CLAUDE.md if its own size is over the warning threshold

This step is only relevant when running the migration on the devshop itself (Wave 5 of home-os migration was this case). For a project migration without touching devshop, skip.

### Step 7 — Land enforcement after the trim

The router (Layer A via routing index → claude-md.md) + the adversarial reviewer (Layer C via `/ak-docs-review` Section E) are now active devshop-wide and require no per-project change. They start enforcing the inclusion rule on the next PR after the trim lands.

### Step 8 — Audit for info loss

Produce `kit/notes/<project>-migration-info-loss-audit.md` mirroring the home-os audit (`kit/notes/migration-info-loss-audit.md`). For each lift target + each area README + each code-comment relocation + each operational move, grep for distinctive phrases. Document any orphans.

### Estimated effort

Home-os migration ran across 8 commits + ~5 hours of focused work (1 session). Lalista's may be faster if the existing classification file remains accurate — most of Step 1 is already done.

## Cross-references

- `kit/docs/guide/README.md § Dev + meta` — routing index entry for CLAUDE.md-touching work (added by Wave 4 of the home-os migration).
- `kit/docs/guide/conventions.md § Project Docs Hierarchy` — the broader convention this guide refines for the CLAUDE.md-specific case.
- `kit/notes/lalista-claude-md-classification.md` — first instance of the 3-class taxonomy; 26 gotchas worked example.
- `kit/notes/home-os-claude-md-classification.md` — second instance; 28 gotchas worked example.
- `kit/notes/claude-md-migration.md` — wave-by-wave migration record (one per project that migrates).
- `/devshop/CLAUDE.md § Context Loading` — the load-bearing principle (project CLAUDE.md self-sufficient; hook delivers devshop context at runtime).
- `/devshop/.claude/skills/ak-docs-review/SKILL.md § Section E` — adversarial audit of CLAUDE.md hygiene (added by Wave 4) — canonical hygiene gate.
- `/devshop/kit/scripts/justify-claude-md.sh` — operator helper for the durable justification artifact (inline marker + commit-trailer text).
- `anthropics/claude-code#22583` — upstream bug: `additionalDirectories` doesn't load CLAUDE.md natively. The SessionStart hook bridges this gap.
