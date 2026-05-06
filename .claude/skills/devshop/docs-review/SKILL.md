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

Per-package READMEs FULL: `apps/*/README.md`, `packages/*/README.md`,
`supabase/functions/README.md` — each if present.

Use the existing convention from the per-commit hook:

- Top-level docs that are missing → mark `(missing — fail open since the file
the audit expects to exist does not; flag this in your review)`.
- `OVERVIEW.md` / `ARCHITECTURE.md` / per-package READMEs absent → mark `(not
present — opt-in doc; trigger does not fire)`. Do NOT flag absence of opt-in
  docs as a finding.

`REFERENCE_DOCS_TOUCHED` pattern:

```
^(CLAUDE|METRICS|OVERVIEW|ARCHITECTURE)\.md$|^(apps|packages|supabase/functions)/[^/]+/README\.md$|^supabase/functions/README\.md$
```

The project-side surface→doc map you audit against is `CLAUDE.md § Where Things
Happen` — that's the canonical "this surface lives here, its docs live here"
ledger for any project repo.

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

**Project rubric**: cross-reference the diff's source paths against `CLAUDE.md
§ Where Things Happen`. New surfaces named there (e.g., a new screen under
`apps/web/app/<route>/page.tsx`, a new edge function, a new RLS policy in
`supabase/migrations/`) demand at least one matching doc edit:

- New page or route → `CLAUDE.md § Where Things Happen` entry mapping it.
- New edge function → `supabase/functions/README.md` + `CLAUDE.md`.
- New API wrapper in `packages/core/src/api/` → `packages/core/README.md`.
- New non-obvious gotcha discovered while implementing → `CLAUDE.md § Gotchas`.
- New user-facing event → `METRICS.md` taxonomy.

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
- **Where Things Happen line accuracy**: when a new entry is added to project
  `CLAUDE.md § Where Things Happen`, the cited file must exist at HEAD. `Read`
  one or two cited paths from each new entry to verify.

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
  Recorded in the audit, not escalated. (e.g., "deferring `CLAUDE.md § Where
Things Happen` update to end of feature" — and the doc IS updated by HEAD).
- **DEFER** — bypass remains pending (e.g., docs-update batched to end of
  feature; a subsequent audit will re-check). Recorded.
- **ESCALATE** — bypass was load-bearing at commit time but the diff has
  shifted such that the bypass would no longer be valid. Escalate to **medium**
  or **high** severity per Section A/B/C rubric.

If `BYPASS_TRAILERS` is empty (the bypass mechanic activates in PR-C of the
audit-migration roadmap; until then, harvest legitimately returns zero rows),
emit "No Docs-Coverage-Bypass trailers in range." and move on. Do not flag the
absence.

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
### [domain: docs] [section: A|B|C|D] [severity: high|medium|low]
**File**: <path>:<line>
**What**: <one-line>
**Why**: <bug class / missed risk>
**Fix**: <specific>
```

If 0/0/0 findings across all four sections, emit a single line:

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
