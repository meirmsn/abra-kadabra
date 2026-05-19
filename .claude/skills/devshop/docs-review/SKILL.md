---
name: ak-docs-review
version: 1.0.0
description: |
  Coverage + adequacy + coherence audit of docs in a commit range.
  Audit-time companion to /ak-tests-review. Invoked by /ak-check-docs-and-tests orchestrator.
  Use when asked to "audit docs", "docs review", or as part of /ak-check-docs-and-tests. (devshop)
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Docs Review

Audit docs in a commit range with **fresh eyes** — coverage (did the right docs
get touched?), adequacy (are the updates substantive?), and cross-doc coherence
(do touched docs contradict reference docs that did NOT change?).

This is the audit-time successor to the per-commit `docsReviewed` adversarial
check. Per-commit fires at the wrong moment — docs are batched for end-of-feature.
This skill fires when docs have actually been written, judges a real artifact,
and harvests bypass trailers from the range so deferred coverage debt isn't lost.

## Inputs

The orchestrator (`/ak-check-docs-and-tests`) invokes with:

- `--range <SHA>..HEAD` — commit range to audit.
- `--feature-dir <path>` — `specs/<feature>/` for emitting findings.

Read `$GIT_ROOT` to branch the doc set:

- `/devshop` → devshop self-mode (this repo).
- anything else (`/workspace`, …) → project mode.

## Step 1 — Gather diff + bypass trailers

```bash
DIFF_STAT=$(git diff --stat "$RANGE")
DIFF_FULL=$(git diff "$RANGE" | head -800)
RENAMED_DELETED=$(git diff --name-status --diff-filter=DR -M "$RANGE")
REFERENCE_DOCS_TOUCHED=$(git diff --name-only "$RANGE" | grep -E '<repo-pattern>')

# Harvest Docs-Coverage-Bypass: trailers from the range.
BYPASS_TRAILERS=$(git log --format='%H%n%B%n---' "$RANGE" \
  | awk '/^Docs-Coverage-Bypass:/{print prev_sha, $0}/^[a-f0-9]{40}$/{prev_sha=$0}')
```

`<repo-pattern>` is the reference-doc set for this repo (see Step 2). Trailers
are produced by the per-commit bypass mechanism in PR-C; for now the harvest may
return zero rows — Section D's prompt still runs so the skill is forward-compatible.

## Step 2 — Inline the reference doc set (branch on `$GIT_ROOT`)

### Devshop self-mode (`$GIT_ROOT == /devshop`)

Inline FULL bodies (`Read`):

- `CLAUDE.md` (devshop)
- `kit/docs/OVERVIEW.md` (incl. § Concept)
- `README.md`

Flat catalog — `## headers only` via `grep -n '^##' <file> | head -20`:

- every `kit/docs/guide/*.md`
- `kit/docs/FAQ.md`

Selective full-body expansion: any `kit/docs/guide/<name>.md` staged in the diff
gets its FULL body inlined (the agent is judging that doc directly, not just its
headers).

`REFERENCE_DOCS_TOUCHED` pattern:

```
^(CLAUDE\.md$|kit/docs/(OVERVIEW|FAQ)\.md$|kit/docs/guide/)
```

### Project mode (anything else, e.g. `/workspace`)

Inline FULL bodies if present:

- `CLAUDE.md`
- `METRICS.md`
- `OVERVIEW.md`
- `ARCHITECTURE.md`
- `KNOWN-ISSUES.md` (post-2026-05-18 architecture migration — operational known-broken-behavior moved out of CLAUDE.md)
- `DEPLOY.md` (post-migration — deploy config moved out of CLAUDE.md)
- `kit/docs/guide/claude-md.md` (the inclusion rule + 3-class taxonomy that this audit applies)

Per-area READMEs FULL: `apps/*/README.md`, `packages/*/README.md`,
`supabase/functions/README.md`, `supabase/README.md` — each if present.

Use the existing convention from the per-commit hook:

- Top-level docs that are missing → mark `(missing — fail open since the file
the audit expects to exist does not; flag this in your review)`.
- `OVERVIEW.md` / `ARCHITECTURE.md` / per-area READMEs absent → mark `(not
present — opt-in doc; trigger does not fire)`. Do NOT flag absence of opt-in
  docs as a finding.

`REFERENCE_DOCS_TOUCHED` pattern:

```
^(CLAUDE|METRICS|OVERVIEW|ARCHITECTURE|KNOWN-ISSUES|DEPLOY)\.md$|^(apps|packages|supabase|supabase/functions)/[^/]+/README\.md$|^supabase/functions/README\.md$
```

The project-side surface→doc map you audit against is the union of per-area
READMEs (`apps/<x>/README.md`, `supabase/README.md`, `packages/<x>/README.md`,
`supabase/functions/README.md`) — **NOT `CLAUDE.md § Where Things Happen`**.
Post-2026-05-18 architecture migration, CLAUDE.md is reserved for silent-failure
traps + project framing per `kit/docs/guide/claude-md.md § The inclusion rule`;
surface inventory lives in the area READMEs at the directory boundary of the
touched file.

## Section A — Coverage

**Question**: did the right docs get touched for what changed in this diff?

**Devshop rubric** (surface → required staged doc):

| Surface path touched in diff                         | At least one of                                                  |
| ---------------------------------------------------- | ---------------------------------------------------------------- |
| `kit/scripts/**.sh`                                  | any `kit/docs/guide/*.md` OR `CLAUDE.md`                         |
| `kit/scripts/commit-hooks/**`                        | `kit/docs/guide/hooks.md`                                        |
| `kit/scripts/preship/**`                             | `.claude/skills/devshop/pre-ship/SKILL.md` OR `kit/docs/guide/*` |
| `kit/hooks/**`                                       | `kit/docs/guide/hooks.md` OR `CLAUDE.md`                         |
| `.claude/skills/**/SKILL.md`                         | `kit/docs/guide/workflow.md` OR `CLAUDE.md`                      |
| `template/**` (excl. `template/.devcontainer/.env*`) | `kit/docs/guide/{architecture,security,ops}.md`                  |
| `.devcontainer/**` (excl. `.env`)                    | `kit/docs/guide/{security,ops}.md`                               |
| `kit/manifest.txt`                                   | `kit/docs/guide/architecture.md`                                 |

Carve-outs (no firing): `kit/notes/**`, `kit/ROADMAP.md`, `kit/TODOS.md`,
`kit/docs/CHANGELOG.md`, `kit/version`, `kit/tests/**`, `kit/docs/**` itself
(audit handles guide-only commits).

**Project rubric** (post-2026-05-18 architecture migration — route to per-area
README by default, NOT CLAUDE.md):

- New page / layout / route under `apps/<x>/app/**` → `apps/<x>/README.md`
  entry (NOT CLAUDE.md). Plus `OVERVIEW.md` if the page is a new user-visible
  flow + `ARCHITECTURE.md` if the new surface affects the module map.
- New API handler under `apps/<x>/app/api/**` → `apps/<x>/README.md § API handlers`.
- New middleware → `apps/<x>/README.md § Edge layer`.
- New migration under `supabase/migrations/**` → `supabase/README.md § Migrations`.
- New SECURITY DEFINER RPC → `supabase/README.md § RPCs`.
- New edge function → `supabase/functions/README.md` + a `supabase/README.md`
  cross-reference (the migrations side may have RLS policies the function uses).
- New API wrapper in `packages/<x>/src/api/` → `packages/<x>/README.md`.
- New design token / primitive in `packages/ui/src/` → `packages/ui/README.md`.
- New non-obvious gotcha discovered while implementing → apply the 3-class
  taxonomy from `kit/docs/guide/claude-md.md § The 3-class taxonomy`:
  - **Already in devshop** → delete duplicate from project CLAUDE.md (if present);
    NO target doc edit required (canonical lives in `kit/docs/guide/*.md`).
  - **Generalizable** → lift to the right `kit/docs/guide/*.md` (devshop-side
    work — fires when the lift commit lands, not on the project PR that
    discovered it).
  - **Project-specific stay** → `CLAUDE.md § Gotchas` entry, applied with the
    `kit/scripts/justify-claude-md.sh` helper (inline marker + commit trailer).
  - **Project-specific code comment** → comment at the file site; no CLAUDE.md
    entry.
- New user-facing event (`posthog.capture(...)`) → `METRICS.md` taxonomy.
- **`CLAUDE.md § Where Things Happen` is no longer a destination.** Pre-migration
  entries may still exist (the trim was incremental); they're acceptable to leave
  until the next CLAUDE.md hygiene audit (Section E below) judges them.

**Coverage findings**: source change with NO matching doc edit AND no
`Docs-Coverage-Bypass:` trailer in the range → finding. Severity = **medium**
by default; **high** if the surface is load-bearing (auth, RLS, edge function
auth boundary, deploy config, security gotcha).

## Section B — Adequacy

**Question**: for docs that DID get touched, are the updates substantive?

Read each touched reference doc's diff hunks and check:

- **No-stub edits**: a doc touched only by whitespace, link reflow, or
  reformatting — without a corresponding new claim — fails coverage if the
  source change introduced a new behavior. Don't accept "I touched the file"
  as coverage proxy.
- **Named-section claims verified by grep**: when a doc edit asserts "X lives
  in `path/to/file.ts`" or "see § Foo Bar", `grep` for the path / heading and
  confirm it exists. Stale paths or dangling section references → finding.
- **Surface-trigger match**: if the diff added a `posthog.capture('event_x')`
  call, `grep -F event_x` against `METRICS.md`. If absent, finding.
- **Gotcha specificity**: a new bullet under `CLAUDE.md § Gotchas` should name
  the symptom, the root cause, AND the fix-or-mitigation. "Watch out for X"
  with no actionable guidance is a stub.
- **Area README entry path accuracy**: when a new entry is added to a project
  area README (e.g., `apps/web/README.md`, `supabase/README.md`), the cited
  files must exist at HEAD. `Read` one or two cited paths from each new entry
  to verify. (Pre-migration, this check was scoped to `CLAUDE.md § Where Things
Happen` — same check, different destination.)

**Adequacy findings**: stub edits, dangling references, missing actionable
guidance. Severity = **medium**; **high** if a load-bearing surface (auth, RLS,
deploy) is mis-described.

## Section C — Cross-doc coherence

**Question**: do the docs touched contradict any reference doc not in the diff?

For each touched reference doc, scan claims that overlap with NON-touched docs:

- A new gotcha in `CLAUDE.md` that contradicts an `ARCHITECTURE.md` invariant.
- A workflow change in `kit/docs/guide/workflow.md` that breaks `kit/docs/OVERVIEW.md
§ Concept`.
- A renamed file in this commit (`RENAMED_DELETED` from Step 1) — `grep -r` the
  old path across ALL inlined reference docs (not just touched ones); any hit
  is a stale-reference finding.
- A deleted file in this commit — same grep sweep; stale references → finding.

**Coherence findings**: contradictory claim across docs OR stale path/section
reference left in a doc not touched by this PR. Severity = **medium**;
**high** if the contradiction would mislead an operator on a security or deploy
boundary.

## Section D — Bypass trailer audit

For each `Docs-Coverage-Bypass:` trailer harvested in Step 1, judge against the
full diff context:

- **VERIFIED** — bypass was load-bearing AND remains valid given current diff.
  Recorded in the audit, not escalated. (e.g., "deferring an area README update
  to end of feature" — and the doc IS updated by HEAD).
- **DEFER** — bypass remains pending (e.g., docs-update batched to end of
  feature; a subsequent audit will re-check). Recorded.
- **ESCALATE** — bypass was load-bearing at commit time but the diff has
  shifted such that the bypass would no longer be valid. Escalate to **medium**
  or **high** severity per Section A/B/C rubric.

If `BYPASS_TRAILERS` is empty (the bypass mechanic activates in PR-C of the
audit-migration roadmap; until then, harvest legitimately returns zero rows),
emit "No Docs-Coverage-Bypass trailers in range." and move on. Do not flag the
absence.

## Section E — CLAUDE.md hygiene (canonical hygiene gate)

> Added 2026-05-18 alongside the CLAUDE.md architecture migration. This is the
> canonical gate that keeps CLAUDE.md from drifting back to its pre-migration
> shape. Project mode only (devshop mode runs a similar audit but with broader
> latitude per `kit/docs/guide/claude-md.md § What CLAUDE.md typically contains`).

**Mode**: project (skip in devshop mode). Reads ALL of current CLAUDE.md (not
just diff-scoped — CLAUDE.md is small post-migration; re-reading it every audit
is cheap and the canonical hygiene gate by design).

**What this section enforces**: the inclusion rule from
`kit/docs/guide/claude-md.md`:

> Belongs in CLAUDE.md = causes SILENT wrong work if not known.
> Belongs in toolchain / docs = causes LOUD failure if not known.

### Step E.1 — Inclusion-rule sweep

For every entry under `## Gotchas` (and every entry in any other content
section), judge against the rule:

- **VERIFIED** — entry passes the inclusion rule. Silent-failure-causing.
  No closer home (area README, code comment, devshop guide) is more
  appropriate. Belongs in CLAUDE.md.
- **CHALLENGE** — entry could plausibly relocate now. Common triggers:
  - A new area README exists that owns the directory the gotcha describes.
  - The toolchain now catches the failure loudly (CI script, pre-commit hook,
    type error) — the lesson is self-teaching and doesn't need CLAUDE.md
    space.
  - A devshop-side lift to `kit/docs/guide/*.md` has landed since the entry
    was written (per the 3-class taxonomy).
  - The entry is one-off historical context (PR-specific backfill,
    migration-transition synonym) that should be deleted; the commit
    message + migration file is the audit trail.
- **RELOCATE** — strong recommendation to move; high-severity finding.
  Surface with a specific destination ("Move this to apps/web/README.md
  § API handlers" / "Lift to kit/docs/guide/migrations.md § <new-section>"
  / "Delete — toolchain catches it; CI script <name> blocks the violation").

The reviewer doesn't auto-relocate. Surface the finding; the operator decides.

### Step E.2 — Section sweep

For every `## ` header in CLAUDE.md, judge whether it matches a recognized
purpose per `kit/docs/guide/claude-md.md § What CLAUDE.md typically contains`:

- **VERIFIED** — section fits the inclusion rule + serves project framing,
  silent-failure traps, or project-specific commands (Migration Workflow,
  Env Var Naming, etc.).
- **CHALLENGE** — section has drifted from its purpose. Common triggers:
  - A `## Vercel dashboard follow-ups` (operator TODOs — should be in
    `TODOS.md`).
  - A `## Known Issues` of user-facing broken behavior (should be in
    `KNOWN-ISSUES.md`).
  - A `## Deploy Configuration` block of detail (should be one-line pointer
    to `DEPLOY.md`).
  - An entire section that's the project's restatement of a devshop
    convention (should be deleted; hook delivers devshop context at runtime).

New sections that fit the inclusion rule (a project-genuinely-needs a
`## Capability flags` block, for example) are FINE — the reviewer judges
fit, not predefined allowlist membership. The convention doc is descriptive,
not enforced.

### Step E.3 — Inline marker re-examination

Search current CLAUDE.md for `<!-- justified: ... -->` markers. For each:

1. Parse the reason from the marker text (one-line; recorded by
   `kit/scripts/justify-claude-md.sh`).
2. Judge whether the reason still holds against the current entry + current
   project state:
   - **VERIFIED** — reason still applies; entry still belongs.
   - **CHALLENGE** — reason no longer applies (closer home now exists,
     toolchain now enforces, the rationale was project-state-specific and
     state has changed). Surface with a specific destination.

Markers grant **deferred review**, not permanent immunity. The operator
recorded their reasoning at commit time; the reviewer re-judges that reasoning
at every audit.

### Step E.4 — Bypass trailer harvest (CLAUDE-MD-Bypass)

In addition to `Docs-Coverage-Bypass:` (Section D), harvest `CLAUDE-MD-Bypass:`
trailers from the audit's commit range:

```bash
CLAUDE_MD_BYPASS_TRAILERS=$(git log --format='%H%n%B%n---' "$RANGE" \
  | awk '/^CLAUDE-MD-Bypass:/{print prev_sha, $0}/^[a-f0-9]{40}$/{prev_sha=$0}')
```

For each trailer found:

- **VERIFIED** — the trailer's commit also added a paired inline marker that
  survives to HEAD. The reasoning is durably recorded. No escalation.
- **MISSING-MARKER finding** — the trailer is in the range but no
  corresponding `<!-- justified: -->` marker exists in HEAD. Two cases:
  - The operator added the trailer but forgot the inline marker → surface a
    finding pointing at the trailer's commit + suggested marker text.
  - The entry was deleted later in the range → surface a finding noting the
    trailer is now orphaned (no action needed unless the deletion was
    accidental).

### Step E.5 — Size trend reporting

Run `wc -c CLAUDE.md` against HEAD and against the audit-range's base SHA.
Compute the delta and report:

- Growth ≤ 500 bytes: "CLAUDE.md size stable (+N bytes this audit window)."
- Growth 500-2000 bytes: "CLAUDE.md grew by N bytes; M new entries. Re-examine
  the new entries against the inclusion rule (Section E.1 above)."
- Growth > 2000 bytes: "CLAUDE.md grew by N bytes across M new entries. **This
  is the rate that historically led to bloat**; carefully audit the new entries
  for closer homes. Surface a CHALLENGE finding for each."

The reviewer doesn't enforce a size threshold — there is no hard cap. The
size-trend reporting exists so the operator (and the reviewer's own Step E.1
judgment) can spot regression patterns before they compound.

### Section E findings format

Same shape as Sections A-D, but use `[section: E]` in the tag line. Findings:

- **inclusion-rule CHALLENGE** → severity `medium`. Suggest destination.
- **inclusion-rule RELOCATE** → severity `high` if entry is misplaced + load-bearing on a security/auth/deploy surface; otherwise `medium`.
- **section CHALLENGE** → severity `medium`. Suggest destination.
- **marker re-examination CHALLENGE** → severity `medium`.
- **MISSING-MARKER** → severity `low`. Helpful nudge, not blocking.
- **size-trend report** → not a finding; recorded as an informational line
  in the audit log.

## Severity rules

Mirror `/ak-tests-review`:

- **high** → halt audit. Operator must fix before ship. Load-bearing
  contradiction, missing doc for a new auth/RLS/deploy surface, mis-described
  security boundary.
- **medium** → surface in the orchestrator's Phase 6 audit comment. Stub edits,
  dangling references, missing-but-recoverable coverage on non-load-bearing
  surfaces.
- **low** → noted in `review.md`'s audit section, not surfaced elsewhere.
  Style nits, formatting churn, "could be tighter" suggestions.

## Output format

For each finding (orchestrator's `## Audit N` appender consumes this shape):

```
### [domain: docs] [section: A|B|C|D|E] [severity: high|medium|low]
**File**: <path>:<line>
**What**: <one-line>
**Why**: <bug class / missed risk>
**Fix**: <specific>
```

If 0/0/0 findings across all five sections, emit a single line:

```
Clean — no docs findings.
```

The orchestrator harvests the structured block (or the clean-line) and folds it
into `specs/<feature>/review.md § Audit N § Docs findings`.

## Behavior

- Report findings, do NOT auto-fix.
- Pause for review — the orchestrator decides halt-or-continue based on
  `high`-severity counts.
- If no findings: report "Docs look solid" and auto-advance.
