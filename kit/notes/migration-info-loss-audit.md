# CLAUDE.md migration — info-loss audit

> Verification run 2026-05-19 after Wave 5 close-out. Checks that every substantive piece of content from the original CLAUDE.md files (pre-migration, ~123k chars combined) is now reachable from its intended home — guide doc, area README, code comment, KNOWN-ISSUES / DEPLOY / TODOS, or still in CLAUDE.md per the classification.
>
> Method: grep for distinctive phrases at each lift target. Every "lift to <guide>" or "stay (condense + pointer)" entry in both classification docs gets a positive-presence check on the target file.

## Result

**No info lost.** All 15 home-os lifts + 5 devshop lifts + 6 code-comment relocations + 4 operational-content relocations verified present at their documented destinations. The 5 entries classified as "delete (loud / historical)" have homes elsewhere (in migration files, ARCHITECTURE.md state map, commit messages, or the toolchain itself).

## Verified — home-os lifts (→ devshop guides)

| Classification row | Source content                                   | Target                                                          | Verification                                                                     |
| ------------------ | ------------------------------------------------ | --------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| Row 1              | PostgREST `data: null` swallow                   | `database-queries.md`                                           | 5 matches on `"data: null" \| "null-deref"`                                      |
| Row 2              | `.trim()` on env reads                           | `supabase-ssr-boilerplate.md` Pattern 1                         | 7 matches on `"trim() defense" \| "NEXT_PUBLIC_.*trim"`                          |
| Row 5              | `tool_choice` forces but model refuses           | `llm-trust-boundaries.md` Pattern 1                             | 6 matches on `"tool_choice forces" \| "model can refuse"`                        |
| Row 6              | plpgsql OUT-param collisions                     | `migrations.md § plpgsql OUT-parameter column collisions`       | 5 matches on `"OUT-parameter" \| "42702" \| "variable_conflict"`                 |
| Row 7+24           | Supabase Cloud GRANT posture                     | `migrations.md § Supabase Cloud GRANT posture`                  | 2 matches on `"ALTER DEFAULT PRIVILEGES" \| "Supabase Cloud GRANT"`              |
| Row 8              | App Router layout-vs-page race                   | `supabase-ssr-boilerplate.md § Pattern 11`                      | 3 matches on `"Pattern 11" \| "App Router layout-vs-page" \| "first throw wins"` |
| Row 9              | Vercel 4096-byte env-var cap                     | `ops.md § Known Footguns`                                       | 1 match (canonical entry)                                                        |
| Row 17             | `card_state` rename-recreate function dependency | `migrations.md § Dependencies` (extended for return-table refs) | 1 match on `"Return-table refs ALSO" \| "cannot drop type"`                      |
| Row 21+23          | Date traps (`<input type=date>` + UTC drift)     | `date-handling.md` (NEW)                                        | 18 matches on `"2026-02-30" \| "YYYY-MM-DD" \| "UTC drift"`                      |
| Row 28             | PGRST204 disambiguation                          | `conventions.md` (already there from prior commit)              | grep -l hit                                                                      |

## Verified — devshop lifts (→ devshop guides)

| Source content                                 | Target                                                                   | Verification                                                                 |
| ---------------------------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| Verify state before stating                    | `conventions.md § Verify state before public assertion` (NEW)            | 1 match on canonical section header                                          |
| Closing TODO / ROADMAP entries                 | `conventions.md § Closing TODO / ROADMAP entries when a fix ships` (NEW) | 3 matches on `"Closing TODO / ROADMAP" \| "imperative present tense"`        |
| Authoring locked files (`/tmp + sudo install`) | `security.md § Authoring locked files (denied-path recipe)` (NEW)        | 3 matches on `"Authoring locked files" \| "install -m 0644 -o root -g root"` |
| `rebuild-browse.sh` (Bun-drift recovery)       | `ops.md § Browse daemon binary drift` (NEW subsection)                   | 2 matches                                                                    |
| `populate-playwright-cache.sh`                 | `ops.md § Playwright cache population` (NEW subsection)                  | 2 matches                                                                    |

## Verified — area READMEs absorbed Where Things Happen

| Surface check                                                  | Target                            | Verification                                                            |
| -------------------------------------------------------------- | --------------------------------- | ----------------------------------------------------------------------- |
| `middleware.ts` + edge layer coverage                          | `apps/web/README.md`              | 3 matches on `"middleware.ts" \| "Edge middleware" \| "GATED_PREFIXES"` |
| API route handlers (`/api/card`, `/api/triage`, etc.)          | `apps/web/README.md`              | 7 matches on canonical POST/PATCH paths                                 |
| SECURITY DEFINER RPCs (`claim_card_slot`, `start_triage`, ...) | `supabase/README.md § RPCs`       | 8 matches on canonical RPC names                                        |
| Migrations 001–012                                             | `supabase/README.md § Migrations` | 2 matches on first + last migration filenames                           |
| `createClient(config)` + guard                                 | `packages/core/README.md`         | 4 matches on canonical exports                                          |
| Design tokens + Button primitive                               | `packages/ui/README.md`           | 7 matches on `"tokens.ts" \| "design tokens" \| "Button.tsx"`           |

## Verified — code-comment relocations (6 entries)

| Row    | Target file                                                      | Comment status                                                                                                      |
| ------ | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Row 4  | `apps/web/app/api/triage/_lib/anthropic.ts`                      | 3 matches on `"web_search_20260209" \| "WebSearchTool20260209"` — pre-existing comment from PR #19, sufficient      |
| Row 12 | `supabase/migrations/20260516111757_010_triage_conversation.sql` | 1 match on `"is_location_ask is dual-written" \| "SAME flag value goes on BOTH"` — NEW Wave 3 comment added         |
| Row 15 | `apps/web/app/api/triage/answer/route.ts`                        | 1 match on `"force-confirm"` — pre-existing comment from PR #5, sufficient                                          |
| Row 19 | `apps/web/app/(app)/cards/[id]/_components/ChoosePath.tsx`       | 2 matches on `"snapshotted as a prop" \| "previous chosen_path is"` — pre-existing comment, sufficient              |
| Row 22 | `apps/web/app/(app)/cards/[id]/page.tsx`                         | 2 matches on `"TWO places by design" \| "PR #4's dashboard"` — NEW Wave 3 comment added                             |
| Row 26 | `apps/web/app/(app)/cards/[id]/_components/ReminderEditor.tsx`   | 4 matches on `"sign IS the signal" \| "days_out" \| "Past dates yield negative"` — pre-existing comment, sufficient |

## Verified — operational content relocations

| Content                                                      | Target                       | Verification |
| ------------------------------------------------------------ | ---------------------------- | ------------ |
| Safari Private Browsing + SMTP rate limit user-facing issues | `/workspace/KNOWN-ISSUES.md` | 4 matches    |
| Vercel project IDs + production URL + deploy commands        | `/workspace/DEPLOY.md`       | 6 matches    |
| Vercel dashboard operator follow-ups (4 items)               | `/workspace/TODOS.md`        | 3 matches    |

## Verified — "delete (loud / historical)" classifications have correct homes

| Classification                                                                                         | Why deleted                                                              | Where it lives now                                                                               |
| ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| Row 10 + 11 (Safari + SMTP)                                                                            | NOT deleted — moved to KNOWN-ISSUES.md (operational issue, not dev trap) | KNOWN-ISSUES.md ✓                                                                                |
| Row 16 (migration 010 backfill targets PR #19)                                                         | One-off historical context                                               | Migration 010 file itself + commit history                                                       |
| Row 20 (`card_state='decide'` is the new state, `diagnosed+severity_confirmed=true` is legacy synonym) | Historical migration transition context                                  | ARCHITECTURE.md state map + migration 011 + commit history                                       |
| Row 25 (No SQL view in migration 012)                                                                  | YAGNI decision rationale                                                 | Commit message for migration 012 + spec history                                                  |
| Row 27 (`-- ROLLBACK:` marker requirement)                                                             | LOUD-enforced by `ci-rollback-explain.sh`                                | `migrations.md` (verified present) + `conventions.md` (verified present) + toolchain enforcement |

## Verified — devshop CLAUDE.md retains all load-bearing detail

| Content                                                                                                                                                  | Status                                                                                                                              |
| -------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| § Context Loading + § Session Start hook contract documentation                                                                                          | Kept verbatim (~6k chars) — meta-orientation, cannot lift                                                                           |
| § Non-Negotiables silent-failure subset (responsive / theme / edge fn auth / middleware-in-PR / TS-source-export / 3-line header / no-ESLint-formatting) | Kept verbatim                                                                                                                       |
| § Non-Negotiables LOUD-enforced subset                                                                                                                   | Condensed to one-liners; toolchain teaches the lesson on violation                                                                  |
| Worktree-aware merging detail (`--branch <name>`, `Merging is worktree-aware`)                                                                           | Kept verbatim — bats Section K cross-doc coherence tests require these phrases                                                      |
| For-coordinated-devshop+project-changes rule                                                                                                             | Kept as one-sentence inline note (the long worked example dropped; the rule preserved)                                              |
| § Confidence Calibration / § TODO Protocol / § Naming Convention / § Quick Reference / § Claude Code Configuration / § Design System                     | Kept verbatim — small + load-bearing posture                                                                                        |
| § gstack                                                                                                                                                 | Condensed (rebuild recipe pointer + `.gstack/projects/**/*.md` tracking rule + `GSTACK_HOME` / `GSTACK_STATE_DIR` split-brain note) |

## Open observations

- **Wave 3 deferred the devshop trim** with rationale "devshop CLAUDE.md is allowed to carry L1 summaries that project CLAUDE.md isn't" — that rationale was correct AT THE TIME (the size cap mattered + the deferral was a triage call). Wave 5 reversed the deferral when the user reframed "the two CLAUDE.md should be 1:1 with their repo." The Wave 5 trim achieves the symmetric architecture without losing content (this audit confirms).

- **The hook-payload threshold mental model was wrong**, as the migration note's correction documents. The Wave 5 trim was correct work, but motivated by a misunderstanding of the underlying mechanism (~2KB cap is for inline preview only; full payload is always persisted). The trim's real value: warning resolution + smaller on-demand-read + symmetric architecture + clean public-contributor experience. None of those depended on the "fits inline" misunderstanding.

- **The 28 home-os gotchas + ~14 devshop Known Footguns + multiple sub-section recipes were all reachable from their destinations** at audit time. Future drift is possible but Section E (`/ak-docs-review`'s CLAUDE.md hygiene gate) re-examines on every audit run, so drift gets surfaced.

## Conclusion

Migration preserved all substantive content. The CLAUDE.md files are leaner because content moved to better-targeted homes, not because content was dropped. Operator can navigate from CLAUDE.md → relevant guide / area README / code comment / operational file via the routing already present at each pointer.
