# home-os CLAUDE.md classification

> Applies the lalista 3-class taxonomy (`lalista-claude-md-classification.md`) to `/workspace/CLAUDE.md` at HEAD on branch `feature/claude-md-architecture`. Drives Waves 2-3 of the migration tracked in `claude-md-migration.md`.

Source: `/workspace/CLAUDE.md` (~79k chars / ~33k tokens, 28 gotchas, ~70 Where Things Happen entries).

## Classifications used

- **Already in devshop — delete + pointer.** Already covered in `/devshop/kit/docs/guide/*.md` or `/devshop/CLAUDE.md`. Project deletes the duplicate; hook delivers canonical version at runtime.
- **Generalizable — lift.** Stack-wide / pattern-wide; lift into a `kit/docs/guide/*.md` section (new or existing). Delete from project CLAUDE.md.
- **Project-specific — stay.** Load-bearing on this project's specific names AND causes silent wrong work AND has no better home. Leave verbatim in project CLAUDE.md.
- **Project-specific — code comment.** Tied to one file or migration; comment at the call site survives renames + shows in diffs. Delete from project CLAUDE.md.
- **Delete (loud failure / out-of-scope).** Toolchain teaches it loudly OR moves to a different file (`KNOWN-ISSUES.md`, `TODOS.md`) OR is historical context already covered by commit message + migration intent.

## Gotchas (28 entries from `/workspace/CLAUDE.md § Gotchas`)

| #   | Title (first 70 chars)                                                                                            | Classification                               | Target                                                                      | Rationale                                                                                                                                                                                            |
| --- | ----------------------------------------------------------------------------------------------------------------- | -------------------------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | PostgREST returns `data: null` + populated `error` on a non-existent column                                       | Generalizable — lift                         | `database-queries.md § PostgREST error swallowing`                          | Stack-wide PostgREST behavior; silent TypeError downstream. Reproduces on every Supabase+PostgREST project.                                                                                          |
| 2   | `.trim()` on every `NEXT_PUBLIC_*` env read                                                                       | Generalizable — lift                         | `supabase-ssr-boilerplate.md` (new § Env-var trim defense)                  | Silent 500 on trailing whitespace; reproduces on any Next.js + env-driven SDK.                                                                                                                       |
| 3   | `PRODUCTION_URL` lives in two places with different formats                                                       | Already in devshop — delete + pointer        | `ops.md § Env Var Naming Convention`                                        | Lalista row 14 covers the equivalent for SUPABASE_PROD_URL; the bare-host vs full-URL split is the same convention surface.                                                                          |
| 4   | Anthropic SDK `web_search` server-tool name drifts with SDK version                                               | Project-specific — code comment              | `apps/web/app/api/triage/_lib/anthropic.ts`                                 | Single-file constant + grep recipe to re-verify. Lives where the next reader of the file will see it; survives SDK bumps.                                                                            |
| 5   | `tool_choice: { type: 'tool', name: '…' }` forces but model can refuse                                            | Generalizable — lift                         | `kit/docs/guide/llm-trust-boundaries.md` (NEW)                              | LLM-output trust boundary pattern: runtime validation required even with tool_choice forcing. Stack-wide for any Anthropic / OpenAI tool-use surface.                                                |
| 6   | plpgsql OUT-parameter names from `returns table (...)` collide with table columns                                 | Generalizable — lift                         | `migrations.md § plpgsql OUT-parameter column collisions`                   | Structural Postgres behavior; reproduces on any SECURITY DEFINER RPC with a `returns table (...)` shape that touches a same-named column.                                                            |
| 7   | Supabase Cloud projects don't ship `ALTER DEFAULT PRIVILEGES` block                                               | Generalizable — lift                         | `migrations.md § Supabase Cloud GRANT posture`                              | Cloud-vs-local divergence; reproduces on every Supabase project until migration 008 equivalent ships. Fold #24 (column inheritance for `ADD COLUMN`) into same section.                              |
| 8   | In Next.js App Router, the layout and the page's server-component data fetches run in parallel — first throw wins | Generalizable — lift                         | `supabase-ssr-boilerplate.md` (new § App Router layout-vs-page race)        | Stack-wide for Next.js App Router; auth-gate-via-layout-only is racy. Reproduces on every authenticated App Router page.                                                                             |
| 9   | Vercel env-var limit is 4096 bytes per variable                                                                   | Generalizable — lift                         | `ops.md § Out-of-band dashboard surfaces` (extend)                          | Vercel-platform-specific; matters for any operator-tunable prompt or config env var. Pair with PROMPT_MAX_CHARS pattern.                                                                             |
| 10  | Magic-link sign-in fails in Safari Private Browsing                                                               | Delete (move to KNOWN-ISSUES.md)             | `/workspace/KNOWN-ISSUES.md`                                                | Operational known-issue, not a development trap. Belongs in the user-facing-issues doc, not the developer-traps doc.                                                                                 |
| 11  | Supabase inbuilt-SMTP rate limit is ~2 magic-link emails/hour project-wide                                        | Delete (move to KNOWN-ISSUES.md)             | `/workspace/KNOWN-ISSUES.md`                                                | Same as #10: operational known-issue. The copy-bug subitem (form says "wait a minute") belongs in TODOS.md.                                                                                          |
| 12  | Q&A `is_location_ask` flag is set on BOTH the user reply row AND assistant question row                           | Project-specific — code comment              | `supabase/migrations/20260516111757_010_triage_conversation.sql` (function) | Load-bearing on the specific RPC. Comment at the `answer_triage_round` definition AND in the route handler at the dispatch site.                                                                     |
| 13  | Q&A location dual-write to `users.location`: silent miss is tolerable, not 500-worthy                             | Project-specific — stay                      | n/a (stays in project CLAUDE.md)                                            | Architectural decision rationale about error-handling tolerance; silent-failure-causing if forgotten (would 500 the Q&A loop). Load-bearing on the design philosophy, not a single file.             |
| 14  | `users.location` is stored verbatim — no geocode, no normalization                                                | Project-specific — stay                      | n/a (stays in project CLAUDE.md)                                            | Data model invariant; future row #5 (monitor-beta) consumer depends on this shape. Silent wrong work if a session adds geocoding/normalization.                                                      |
| 15  | Q&A force-confirm at round 3 + skip — server-side cap, server-side parse defense                                  | Project-specific — code comment              | `apps/web/app/api/triage/answer/route.ts`                                   | The generalizable pattern is row #5 (tool_choice forces but model refuses). The project-specific application lives at the route. Comment at the parse-and-dispatch block.                            |
| 16  | Migration 010 `tool_name` backfill targets PR #19's initial-read rows                                             | Delete                                       | n/a                                                                         | Historical context for a one-off backfill. The migration file itself documents the intent; future migrations don't need this.                                                                        |
| 17  | `card_state` rename-recreate now happens through functions — drop dependent functions BEFORE the rename           | Generalizable — lift                         | `migrations.md § Enum rename-recreate with function dependencies`           | Postgres-wide pattern: drop dependent functions before `ALTER TYPE ... RENAME` when functions hold return-table refs. Migration 011 is the specific instance; pattern reproduces.                    |
| 18  | Locked-jsonb-shape validation lives in TWO places (deliberate DRY-tension)                                        | Project-specific — stay                      | n/a (stays in project CLAUDE.md)                                            | Architectural decision about shared `estimate-shapes.ts` module across LLM-output + user-PATCH trust boundaries. Silent shape drift if forgotten — both validators must use the shared module.       |
| 19  | `<ChoosePath />` decide_path_changed fires from a snapshotted prop                                                | Project-specific — code comment              | `apps/web/app/(app)/cards/[id]/_components/ChoosePath.tsx`                  | File-specific behavior (prop snapshot before router.refresh); next reader of the file will see it.                                                                                                   |
| 20  | `card_state='decide'` is the new "confirmed, awaiting path" state — legacy synonym                                | Delete                                       | n/a (delete; ARCHITECTURE.md state map covers)                              | Historical migration transition context. Once backfill ran, the synonym distinction matters only in code review of migration 011 — which the commit message + migration file cover.                  |
| 21  | Native `<input type="date">` value format vs JS `new Date()` permissive coerce                                    | Generalizable — lift                         | `kit/docs/guide/date-handling.md` (NEW — fold with #23 + #26)               | JS/Postgres date semantics gotchas; reproduce everywhere. Reminder-PATCH route is the specific instance.                                                                                             |
| 22  | `isReminderDue` is derived in TWO layers by design                                                                | Project-specific — code comment              | `apps/web/app/(app)/cards/[id]/page.tsx`                                    | File-specific architectural choice; will become moot when PR #4 (dashboard) ships and the second layer materializes. Comment at the derivation point.                                                |
| 23  | Date comparison vs CURRENT_DATE — UTC drift trap; strip clock time, compare as strings                            | Generalizable — lift                         | `kit/docs/guide/date-handling.md` (NEW)                                     | Stack-wide JS+Postgres date-comparison trap; reproduces everywhere a date-only column gets compared to "now" in JS.                                                                                  |
| 24  | Migration 008's `ALTER DEFAULT PRIVILEGES` covers new COLUMNS automatically — but NEW tables still need GRANT     | Generalizable — lift                         | `migrations.md § Supabase Cloud GRANT posture` (fold with #7)               | Same root concept as #7; lift into the same section. Audit pattern (information_schema.role_table_grants query) lifts too.                                                                           |
| 25  | No SQL view in migration 012 — premature centralization rejected                                                  | Delete                                       | n/a (in commit message / spec rationale)                                    | YAGNI decision rationale; doesn't belong in the always-loaded gotcha list. Future PR #4 (dashboard) decision can revisit; the spec history is the audit trail.                                       |
| 26  | `days_out` in PostHog reminder events is SIGNED                                                                   | Project-specific — code comment              | `apps/web/app/(app)/cards/[id]/_components/ReminderEditor.tsx`              | File-specific behavior + PostHog event contract. Comment at the `days_out` computation in `ReminderEditor.tsx` + a comment in METRICS.md where the event is taxonomized.                             |
| 27  | Every column-adding migration MUST carry a `-- ROLLBACK:` marker block                                            | Already in devshop — delete + pointer (LOUD) | `migrations.md § ROLLBACK marker` + `ci-rollback-explain.sh`                | LOUD failure (CI catches via `ci-rollback-explain.sh`). Per silent-failure inclusion rule, can be deleted from CLAUDE.md entirely. If `migrations.md` doesn't already cover it, lift the rule there. |
| 28  | PGRST204 in CI is almost always a downstream symptom of a missing column                                          | Generalizable — lift                         | `migrations.md § PGRST204 root-cause loop` (fold with #27's rationale)      | Debugging recipe is universal; the specific case (migration 012's missing ROLLBACK marker) is what's already lifted in #27. The diagnostic ladder (psql → curl OpenAPI → docker restart) lifts.      |

**Count by classification:**

- **Already in devshop — delete + pointer**: 2 (rows 3, 27)
- **Generalizable — lift**: 12 (rows 1, 2, 5, 6, 7, 8, 9, 17, 21, 23, 24, 28) — affects 6 distinct devshop guide docs (1 new: `llm-trust-boundaries.md`; 1 new: `date-handling.md`; 4 existing extended: `migrations.md`, `database-queries.md`, `supabase-ssr-boilerplate.md`, `ops.md`)
- **Project-specific — stay**: 3 (rows 13, 14, 18)
- **Project-specific — code comment**: 6 (rows 4, 12, 15, 19, 22, 26)
- **Delete (loud / out-of-scope)**: 5 (rows 10, 11, 16, 20, 25) — rows 10+11 move to `KNOWN-ISSUES.md`

Sum-check: 2 + 12 + 3 + 6 + 5 = 28 ✓

## Other sections (non-Gotchas)

| Section                           | Classification                              | Target                                                                                         | Rationale                                                                                                                                                         |
| --------------------------------- | ------------------------------------------- | ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Orientation block (top)           | Project-specific — stay (rewritten)         | Project CLAUDE.md                                                                              | Becomes thin pointer block: OVERVIEW / ARCHITECTURE / area READMEs / PLAN+BUILD-LOG+TODOS+KNOWN-ISSUES. Drops devshop refs (line 34 principle).                   |
| Project paragraph                 | Project-specific — stay                     | Project CLAUDE.md                                                                              | Frames every conversation. Tiny. Keep.                                                                                                                            |
| Where Things Happen (~70 entries) | Mostly — fan out to area READMEs (Wave 2)   | `apps/web/README.md`, `supabase/README.md`, `packages/core/README.md`, `packages/ui/README.md` | Each entry routes to nearest area README by directory. Rare cross-cutting entries (e.g. CSP rules touching multiple surfaces) may stay; most fan out.             |
| Testing section                   | Already in devshop — delete + pointer       | `kit/docs/guide/testing.md` + `conventions.md § Test Presence`                                 | Devshop owns test-presence convention; project doesn't need to restate.                                                                                           |
| Stack                             | Project-specific — stay (one line)          | Project CLAUDE.md                                                                              | One-line summary stays as project framing. Full list moves to ARCHITECTURE.md if not already there.                                                               |
| Env Var Naming table              | Project-specific — stay                     | Project CLAUDE.md                                                                              | The Next.js prefix table is project-stack-specific. Devshop ships the principle ("base name in secrets, prefix per surface"); project's table is the application. |
| Migration Workflow (commands)     | Project-specific — stay                     | Project CLAUDE.md                                                                              | 4-line command block. Project-specific (Supabase). Used often. Stays.                                                                                             |
| Deploy Configuration (full block) | Project-specific — split                    | `DEPLOY.md` (new) + 1-line pointer in CLAUDE.md                                                | Full block (URLs, project IDs, commands, follow-ups) moves to DEPLOY.md. CLAUDE.md keeps a 1-line "Deploy: Vercel auto-on-push. See DEPLOY.md."                   |
| Custom deploy hooks               | Project-specific — code comment / DEPLOY.md | `DEPLOY.md`                                                                                    | Detail belongs with the full deploy block. Tiny pointer in CLAUDE.md if anything.                                                                                 |
| Vercel dashboard follow-ups       | Delete (move to TODOS.md)                   | `/workspace/TODOS.md`                                                                          | Operator-action TODOs, not CLAUDE.md content.                                                                                                                     |

## Projected final shape of `/workspace/CLAUDE.md`

- Project paragraph (tiny)
- Orientation pointers (OVERVIEW, ARCHITECTURE, area READMEs, PLAN/BUILD-LOG/TODOS/KNOWN-ISSUES — NO `/devshop/...` refs)
- Where Things Happen — rare cross-cutting entries only (most fan out to area READMEs)
- Gotchas — 3 stay + brief context = ~6-10 entries vs current 28
- Stack (one line)
- Env Var Naming table (project-specific Next.js prefixes)
- Testing — delete (devshop owns it; hook delivers `conventions.md § Test Presence`)
- Migration Workflow (4 commands)
- Deploy (1-line pointer to DEPLOY.md)

Projected size: ~6-10k chars (vs current 79k).

## Devshop guide doc impact

Files extended (existing):

- `database-queries.md` — row #1 (PostgREST error swallowing)
- `supabase-ssr-boilerplate.md` — row #2 (env-var trim) + row #8 (App Router layout-vs-page race)
- `migrations.md` — rows #6, #7, #17, #24, #27, #28 — six entries lifted (largest impact)
- `ops.md` — row #9 (Vercel 4096-byte env-var cap)

Files created (new):

- `llm-trust-boundaries.md` — row #5 (tool_choice forcing + runtime validation). Future home for Anthropic / OpenAI trust-boundary patterns.
- `date-handling.md` — rows #21, #23 (and #26's pattern, though #26 stays as code comment). Future home for JS/Postgres date-only column semantics.

Wave 1 only DRAFTS the additions in the migration-note + classification file. Actual writes to the devshop guide docs happen in Wave 2.

## Synthetic generalizable patterns (lalista S-rows analogue)

For each "Project-specific — stay" row, consider whether a synthetic generalizable pattern can be lifted alongside.

- **Row #13** (Q&A location dual-write silent miss tolerable) — synthetic S1: **Side-channel write failures shouldn't roll back the primary write**. Pattern: when an RPC owns the atomic write and a follow-up UPDATE is the secondary cache, prefer Sentry-warn + return success over rolling back the primary. → Lift to `kit/docs/guide/conventions.md § Side-channel write tolerance` (or a new guide).
- **Row #14** (users.location stored verbatim) — synthetic S2: **Lock the v0 data shape to defer geocoding decisions to the consumer**. Pattern: when v0 doesn't need geocoding but v1 might, store verbatim string; v1 introduces normalization at the point of need. → Lift to `kit/docs/guide/conventions.md § Defer normalization to the consumer` (or `database-queries.md`).
- **Row #18** (locked-jsonb in two places) — synthetic S3: **Shared validator module for the same shape at two trust boundaries**. Pattern: when LLM-output validation + user-input validation cover the same schema, the validator is one module imported at both call sites. → Lift to `llm-trust-boundaries.md § Shared schema at LLM + user trust boundaries` (folds with row #5).

These synthetic lifts deferred to Wave 2 alongside the row-#-specific lifts.

## Open questions surfaced during classification

- **Row #4 (Anthropic SDK web_search name)** — is this really silent? SDK type system surfaces the wrong constant at compile time. If LOUD, can be deleted entirely (toolchain teaches via type error). Verify by reading `_lib/anthropic.ts` + grepping for type drift. If type-checked, downgrade to "Delete (loud)".
- **Row #27 (ROLLBACK marker)** — confirmed LOUD (CI script catches it). Per silent-failure inclusion rule, this DOESN'T need to be in CLAUDE.md at all. But the diagnostic recipe (row #28) is universal and worth lifting. So row #27's content essentially folds into row #28's lift to `migrations.md`.
- **Where Things Happen — rare cross-cutting entries.** Are there any genuinely cross-cutting WTH entries (touching ≥3 areas) that resist fan-out? Audit during Wave 2; if zero qualify, CLAUDE.md drops the WTH section entirely.

## Wave 3 trim sequence

Wave 3 trims project CLAUDE.md in this order:

1. Move rows 10, 11 to KNOWN-ISSUES.md (Wave 1 already creates the file).
2. Move Vercel-dashboard follow-ups + #11's copy-bug subitem to TODOS.md (Wave 1).
3. Move Deploy Configuration block to DEPLOY.md (Wave 1).
4. Delete rows 16, 20, 25 (historical context covered elsewhere).
5. Delete row 27 (loud / toolchain-enforced).
6. After Wave 2 lifts: delete rows 1, 2, 3, 5, 6, 7, 8, 9, 17, 21, 23, 24, 28 from project CLAUDE.md (canonical lives in devshop guide; hook delivers).
7. Add code comments for rows 4, 12, 15, 19, 22, 26 (file-specific). Delete from CLAUDE.md.
8. Rewrite orientation block (drop `/devshop/...` refs per line-34 principle).
9. Delete Testing section (devshop owns).
10. Trim Deploy Configuration to one line.
11. Measure final size; record for Wave 4 cap calibration.
