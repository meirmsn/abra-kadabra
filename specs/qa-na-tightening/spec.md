<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: qa-na-tightening -->
<!-- date: 2026-05-10 -->

# Spec: qa-na-tightening (PR N)

**Sources:**

- `PLAN.md` row #1 (`qa-na-tightening`) — primary scope (will be reframed during this PR; see Decisions § D0)
- `kit/ROADMAP.md § Tightening /qa's n/a criteria` (lines 1965-1985) — original problem statement, ACCEPT/REJECT vocabulary, mechanism (`adversarial-review.sh`)
- `.claude/skills/devshop/pre-ship/SKILL.md § Gate 9` (lines 591-692) — Gate 9 outcome contract; the Core user story N/A carve-out at lines 678-682
- `kit/scripts/preship/verify-story.sh` (lines 44-58, 125-129) — where N/A body parsing + skip-assertion live; D2's call site
- `kit/scripts/adversarial-review.sh` (lines 90-330, 332-372) — case-statement + per-check-type prompt + convention-inlining map; surface for the new check-type
- `kit/tests/util-adversarial-review-localTestSkipReason.bats` — pattern reference for the new BATS suite
- `kit/docs/guide/hooks.md § Bypass mechanism table` (lines 128, 232) — doc landing for the new check-type
- `kit/docs/guide/workflow.md § Core user story requirement` (lines 181-191) — convention-inlining target for D4
- Prior spec `specs/post-pr-c-deferred-polish/spec.md` — style + structure reference (most recent devshop-self spec)

Tighten the residual self-attestation rung in Gate 9: when a spec declares `## Core user story: N/A — <reason>`, route the rationale through `adversarial-review.sh` so an interpretive vibe ("no visible UI change", "cosmetic only") fails and a verifiable file/path claim ("no `.tsx` files modified", "diff is `supabase/migrations/**` only") passes — closing the gap that currently lets `verify-story.sh` skip artifact assertion on operator prose alone.

---

## Decisions (resolved at spec time)

Six `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded
below so Phase 1 preserves them verbatim and a crashed Phase 1 resumes
without re-asking. D0 captures the scope-reframe step (the original PLAN
row presupposed a Gate 9 `n/a` outcome that no longer exists post-`408b007`).

### D0: Scope reframe — "Gate 9 `n/a` outcome" → "Core user story: N/A rationale"

**Decision:** Target the `## Core user story: N/A — <reason>` body in `verify-story.sh`'s N/A branch (lines 125-129), not a Gate 9 `n/a` outcome.

**Rationale:** `pre-ship/SKILL.md § Gate 9 § Outcome contract` (line 602) was tightened to three outcomes (`pass | findings | blocked`) — `n/a` is no longer an officially supported Gate 9 outcome. The residual self-attestation rung migrated into `verify-story.sh`'s "Core user story is N/A — artifact assertion skipped" path (line 127), where the operator-supplied `<reason>` text bypasses Gate 9's evidence requirement with no adversarial review. The plan's principle (require a verifiable file:line claim, not interpretive prose) and mechanism (reuse `adversarial-review.sh`) carry over directly to this surface.

### D1: New check-type vs. extend `dismissalLog`

**Decision:** New check-type `coreUserStoryNaReason` in `adversarial-review.sh`.

**Rationale:** `dismissalLog` fires on a gate's `## Dismissals` body (per-finding rationale within a gate's report). The Core-user-story N/A reason lives in the spec, not in a gate's dismissal log — different surface deserves a dedicated check-type. Mirrors `localTestSkipReason` precedent (named for the bypass surface, not the gate it gates). Easier to test in isolation and gives the BATS suite a clean per-check-type case.

### D2: Where the call fires

**Decision:** Inside `verify-story.sh`'s N/A-body branch at lines 125-129, immediately before `return 0`.

**Rationale:** `is_na_core_story` already detects the surface (line 126). The rationale text is the body after `N/A — `. On reject → exit non-zero with the reviewer verdict appended → Gate 9 reports `blocked` with the rejection as fix recipe. Single chokepoint; matches the existing "exit 1 with summary" pattern in `verify_all` (line 168).

### D3: ACCEPT/REJECT vocabulary in the prompt

**Decision:** Copy verbatim from `kit/ROADMAP.md § Tightening /qa's n/a criteria` lines 1973-1974 — ACCEPT positive file/path-based claims (`no .tsx files modified`, `diff is supabase/migrations/** only`, `apps/web/components/** untouched`); REJECT interpretive prose (`no visible UI change`, `nothing user-facing changed`, `cosmetic only`).

**Rationale:** The vocabulary is already authored at the source; copying preserves intent and avoids paraphrase drift. The prompt's worked examples land directly in the check-type's documentation block, matching `localTestSkipReason`'s shape.

### D4: Convention-inlining target

**Decision:** Inline `kit/docs/guide/workflow.md § Core user story requirement` (lines 181-191) into the reviewer's context block.

**Rationale:** Per the `(check_type, gate_name)` routing map at `adversarial-review.sh:332-372`, the reviewer needs the contract for what `Core user story: N/A` means and when it's appropriate. `workflow.md:181-191` is the single load-bearing definition — covers the literal `N/A — <reason>` form, which PRs are migration-only / non-user-facing, and points to the Gate 9 enforcement contract.

### D5: Model routing (Haiku 4.5 vs. Sonnet 4.6)

**Decision:** Sonnet 4.6.

**Rationale:** Mirrors existing `dismissalLog` and `localTestSkipReason` routing (`adversarial-review.sh:52`). Interpretive judgment of operator prose ("does this rationale name a verifiable file claim, or is it a vibe?") is Sonnet-tier, not deterministic-rule application. Haiku is reserved for purely textual checks (e.g., manifest-reviewed) where the rule maps 1:1 to surface signals.

### D6: Backwards compatibility for already-shipped specs

**Decision:** None needed.

**Rationale:** The check fires only at pre-ship time on new invocations. Already-merged specs aren't re-exercised. Existing `specs/<feature>/` directories on disk that happen to declare `Core user story: N/A — <interpretive prose>` from before this PR don't trigger the check until a new pre-ship runs over them — and any such fresh pre-ship is by definition for a new commit on a current branch, where the operator can re-author the rationale.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Screens, Data
     model changes, API contracts, Offline behavior, Metrics, Files to
     create/modify, Tests, Dependencies, Task order, Gotchas, Acceptance /
     rollout / rollback. The Decisions section above stays verbatim. -->
