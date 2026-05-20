### [domain: docs] [section: A] [severity: medium]
**File**: kit/docs/guide/hooks.md
**What**: New `advisorBypassReason` adversarial check-type added in `kit/scripts/adversarial-review.sh` (line 413 case branch, line 510 CONVENTIONS_TO_INCLUDE entry, line 639 Sonnet routing entry, line 449 surviving-check-types list) but `hooks.md` — which is the canonical home for the check-type matrix, model-routing table, and bypass-flag inventory — was not touched in this range.
**Why**: Devshop convention from `CLAUDE.md § Non-Negotiables` ("Every devshop tooling change includes doc updates in the same commit") and the coverage rubric for `kit/scripts/commit-hooks/**`-and-equivalent surfaces. `hooks.md § Adversarial review` + `§ Per-check-type model routing` + `§ Bypass flags + env hatches` is where operators look up which check-types exist; a new one shipping without a docs row leaves the matrix stale.
**Fix**: Add `advisorBypassReason` to (a) the Sonnet 4.6 row of the model-routing table at hooks.md line 385, (b) a new entry/sentence describing the check-type and its surface (pre-ship gate `advisor-clean`, not a git hook), and (c) the "Pre-ship-time additions to the adversarial-review surface" paragraph near line 251 so the inventory is complete.

### [domain: docs] [section: C] [severity: medium]
**File**: kit/docs/guide/hooks.md:421
**What**: Claim "This is the only adversarial-review check-type whose surface isn't a git hook" (referring to `testReviewSkipReason` firing inside `/ak-build` Phase 5.8) contradicts the new `advisorBypassReason` check-type, which also fires from a non-git-hook surface (`kit/scripts/preship/advisor-clean.sh`, invoked inside `/ak-pre-ship` Gate 2g).
**Why**: A reader using this sentence as ground truth would conclude no other non-git-hook adversarial surface exists, missing the advisor gate's adversarial path. The sentence was already arguably imprecise (pre-ship `dismissalLog` fires inside `/ak-pre-ship` rather than a git hook), but this PR makes the contradiction concrete.
**Fix**: Either soften to "`testReviewSkipReason` is invoked from `/ak-build` Phase 5.8 rather than a git hook — like `advisorBypassReason` and the pre-ship `dismissalLog`, it extends the adversarial-review surface beyond commit/push." Or rewrite the section as a non-comparative description.

### [domain: docs] [section: C] [severity: medium]
**File**: kit/docs/guide/hooks.md:385
**What**: Sonnet 4.6 model-routing row in the `Per-check-type model routing` table lists 6 check-types but does not include `advisorBypassReason`, which `kit/scripts/adversarial-review.sh` line 639 routes to Sonnet via the same case statement.
**Why**: The table is the docs reader's reference for which model adjudicates each bypass. Omitting the new entry while the script routes to Sonnet means the docs and the implementation diverge silently. (Note: pre-existing omission of `coreUserStoryNaReason` from the same row shortens the gap but doesn't excuse adding a fresh one.)
**Fix**: Add `advisorBypassReason` to the Sonnet 4.6 row's check-type list (and extend the rationale column to name the DB-hardening blast-radius reason — false-pass would ship an un-pinned SECURITY DEFINER or unwrapped RLS policy).

### [domain: docs] [section: B] [severity: low]
**File**: kit/docs/guide/security.md:5-20
**What**: The `## Contents` TOC was not updated to include the new `## DB hardening — SQL conventions for Supabase projects` H2 (added at line 130) that this PR ships.
**Why**: The TOC is a navigation aid; a new H2 anchor that doesn't appear in the TOC is invisible to readers scanning the file head. (Pre-existing context: the `## Authoring locked files (denied-path recipe)` H2 is also missing from the TOC, indicating lax TOC discipline in this file — but this PR could have closed the new gap.)
**Fix**: Insert `- [DB hardening — SQL conventions for Supabase projects](#db-hardening--sql-conventions-for-supabase-projects)` between the `RLS-bypass write fallback ladder` and `Per-environment secret split` entries. Optionally also close the pre-existing `Authoring locked files` omission in the same edit.

### [domain: docs] [section: B] [severity: low]
**File**: kit/docs/guide/README.md:140
**What**: The alphabetical-list summary for `security.md` reads "Security model, root-owned files, DCG, edge-fn auth, secrets isolation, known gaps" and does not mention the new DB hardening SQL conventions section.
**Why**: The alphabetical list is the orientation summary for what each guide covers. Adding a substantial new section (3 SQL rules + enforcement contract) without updating the one-line summary leaves the index orientation stale.
**Fix**: Update the summary to "Security model, root-owned files, DCG, edge-fn auth, secrets isolation, DB hardening SQL conventions, known gaps".

### [domain: docs] [section: B] [severity: low]
**File**: kit/docs/guide/README.md:34
**What**: The Data routing row for `supabase/migrations/**` points only at `database-queries.md` + `migrations.md § Supabase Hardening Defaults`, not at the new `security.md § DB hardening — SQL conventions for Supabase projects`. Readers following routing for a migration change reach the SQL conventions only transitively via the see-also block in `migrations.md` (added by this PR).
**Why**: Routing acts on file-glob + keyword triggers; a Supabase migration touching a `SECURITY DEFINER` function, RLS policy, or new FK should route to the DB-hardening rules directly. The transitive path works but is fragile (any future reflow of the see-also block hides the rule).
**Fix**: Either add a dedicated routing row keyed on "`SECURITY DEFINER`" / "RLS policy" / "foreign key" keywords targeting `security.md § DB hardening`, or extend the existing row's Notes column to name the security.md section as a paired target.

### [domain: docs] [section: D] [severity: low]
**File**: (range-wide)
**What**: No Docs-Coverage-Bypass: trailers in range.
**Why**: Forward-compatible reporting per skill § Section D.
**Fix**: n/a — informational only.
