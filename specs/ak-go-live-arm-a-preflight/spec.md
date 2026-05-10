<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: ak-go-live-arm-a-preflight -->
<!-- date: 2026-05-10 -->

# Spec: ak-go-live-arm-a-preflight (PR N)

**Sources:**

- `/devshop/kit/ROADMAP.md § /ak-go-live post-merge prod-config sync + pre-flight surface` — primary scope (Arm A + Arm B; this PR ships Arm A only)
- `/devshop/.claude/skills/ak-go-live/SKILL.md` — the skill getting the new Step 1.8
- `/devshop/.claude/skills/ak-build/SKILL.md § PR body conventions` — defines the section headers Arm A's parser will recognize (`## Test plan`, `### Manual review`, `## Out-of-band deploy items`, `### CI gates`)
- `/devshop/kit/docs/guide/workflow.md § Step 6: /ak-go-live (devshop skill) — autonomous deploy` — paired-doc target for the one-paragraph reference, per the docs-coverage hook contract
- Lalista PR #58 (chapter 1n, db-hardening) — empirical reference for PR-body section-header structure (verified 2026-05-10)
- Lalista PR #43 (chapter 1l, auth-ux-rework) — original motivation per ROADMAP entry; shipped 2026-05-04

Add a pre-flight surface to `/ak-go-live` that reads the merging PR's body + latest audit/ready-for-review comment, parses every `[ ]` checkbox grouped by section, annotates each as `[manual]` or `[deferred]`, prints a "Pending tasks before live" section, and blocks on `[manual]` prereqs only (items under `## Out-of-band deploy items`). Arm B (Management API integration that converts most `[manual]` to `[auto]`) is deferred.

---

## Decisions (resolved at spec time)

6 `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without re-asking.

### D1: SKILL.md placement

**Decision:** New step lands as **Step 1.8: Pending tasks pre-flight surface** — between current Step 1.7 (Auth-config deploy reminder) and Step 2 (Land and deploy).

**Rationale:** Pre-flight steps already number 1.5 (prod health probe) / 1.6 (migration sequencing) / 1.7 (auth-config reminder); Step 1.8 keeps the cluster discoverable. Position is "after PR readiness, before merge invocation" — exactly where Arm A wants to surface its annotated checkbox list. Step 1.7's auth-config-specific reminder stays in place; 1.8 generalizes it (every chapter, not just auth-config) and the two co-exist without conflict (overlap = double reminder, which is fine).

### D2: Section recognition list

**Decision:** Recognized headers (case-insensitive substring match):

- `Out-of-band deploy items`
- `Manual review`
- `Operator follow-up`
- `Test plan` (sub-items — checkboxes left unmarked when CI auto-marker should have flipped them count as a sanity-check concern)

Unrecognized → grouped under "Other".

**Rationale:** Empirically verified against lalista PR #58: those are the canonical headers from `/ak-build § PR body conventions`. Section names are stable across projects (the PR body convention is a devshop-wide rule); keyword heuristics over checkbox text would be fragile. The "Test plan" sub-bucket exists because if `/ak-build` Phase 5.3 forgot to mark a CI checkbox, surfacing it as `[!]` (different from `[manual]` / `[deferred]`) lets the operator notice the bookkeeping miss without blocking the deploy.

### D3: Annotation logic for `[manual]` vs `[deferred]`

**Decision:** Section-based, not keyword-based:

- `Out-of-band deploy items` → `[manual]` (deploy prereq, blocks)
- `Operator follow-up` → `[manual]` (post-deploy reminder, non-blocking)
- `Manual review` → `[deferred]` (PR-review concern; the PR is already approved by the time `/ak-go-live` runs)
- `Test plan` `[ ]` items → flag as `[!]` (CI checkbox the auto-marker should have flipped — sanity-check concern, non-blocking)
- "Other" → `[manual]` non-blocking (default conservative)
- No `[auto]` items in Arm A — that requires Arm B's automation core

**Rationale:** Section semantics match the PR-body convention's intent — headers were chosen specifically so reviewers know what a checkbox means at a glance. Keyword heuristics ("BEFORE merge", "must be") fail on phrasings the convention doesn't anticipate; section-based rules degrade gracefully (unrecognized section → `[manual]` non-blocking, surface but don't block).

### D4: Block scope (which items gate the merge)

**Decision:** Block (via `AskUserQuestion`) only on `[ ]` items under `## Out-of-band deploy items`. Items in `Operator follow-up`, `Manual review`, `Test plan`, and "Other" surface as a printed reminder but do NOT block.

**Rationale:** "Out-of-band deploy items" is the section the PR body convention reserves for "things needed to complete the deploy that don't auto-deploy" (e.g., `supabase functions deploy`, paste email templates, run `terraform apply`). Those are deploy prereqs by definition. The other sections are post-deploy concerns or PR-review concerns; gating the deploy on them would surface false friction (the operator already approved the PR, and `Manual review` items are review-time items). Single source of "what blocks" matches `/ak-go-live`'s existing pattern (Step 1.5 blocks on real-prod 4xx/5xx; Step 1.6 blocks on mutating migrations without a deploy plan).

### D5: Comment scan strategy

**Decision:** Scan latest two comments where the body matches case-sensitive substring `Pre-ship audit trail` OR `Ready for review` (the canonical headers `/ak-build` Phase 6 + Phase 7 emit). Apply the same parser; `[ ]` items found in comments are prefixed `(comment)` in the output to distinguish from PR-body items. Annotation rules carry through identically (section-based).

**Rationale:** The ROADMAP entry directs reading both sources. Empirical check of lalista PR #58 found zero `[ ]` checkboxes in the audit comment (all narrative tables) and zero in the ready-for-review comment — but the convention allows them, and a comment-side checkbox someone added during review would be a real signal. Cheap scan (one extra `gh pr view --json comments` call), low false-positive risk.

### D6: Defer Arm B — how to record

**Decision:** Edit `/devshop/kit/ROADMAP.md § /ak-go-live post-merge prod-config sync + pre-flight surface`:

- Delete the "Arm A — Pre-flight surface" subsection (it shipped via this PR).
- Add a `**Status:**` line at the top noting "Arm A shipped <YYYY-MM-DD> via PR #<N>; Arm B (Management API integration + `SUPABASE_ACCESS_TOKEN` credential surface) remains as scoped below."
- Preserve the "Arm B — Automation core" subsection verbatim.
- Update the "Cross-ref" + "Cost/risk" + "Trigger" subsections to remove Arm A bullets and keep only Arm B's.

**Rationale:** Per `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`, partial closure deletes the shipped-portion description but keeps the deferred-portion. Strikethrough was considered but rejected — it leaves "Without this" / "before Arm A ships" prose that reads identically whether the prereq is met or not. Imperative present-tense rewrites of the remaining Arm B prose protect against the same future-session-misreads-the-prereq footgun the closing-TODOs convention exists to prevent.

---

## In scope

1. New `## Step 1.8: Pending tasks pre-flight surface` section in `/devshop/.claude/skills/ak-go-live/SKILL.md`, inserted between Step 1.7 and Step 2.
2. New paragraph in `/devshop/kit/docs/guide/workflow.md § Step 6 § Pre-flight` (alongside existing 1.5/1.6/1.7 paragraphs).
3. Updated `/devshop/kit/ROADMAP.md § /ak-go-live post-merge prod-config sync + pre-flight surface` per D6.

## Files to create/modify

| Path                                                  | Change                                                                              |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `/devshop/.claude/skills/ak-go-live/SKILL.md`         | + Step 1.8 (~60 lines); bump version `1.2.0` → `1.3.0` in frontmatter               |
| `/devshop/kit/docs/guide/workflow.md`                 | + paragraph in § Step 6 (~3-5 sentences)                                            |
| `/devshop/kit/ROADMAP.md`                             | strike Arm A subsection; add Status line; trim Cross-ref/Cost/Trigger to Arm B only |
| `/devshop/specs/ak-go-live-arm-a-preflight/spec.md`   | this file (Phase 1 expands below this marker)                                       |
| `/devshop/specs/ak-go-live-arm-a-preflight/tasks.md`  | written by Phase 2 (`/ak-implement`)                                                |
| `/devshop/specs/ak-go-live-arm-a-preflight/review.md` | written by Phase 3 (`/ak-pre-ship`)                                                 |

## Tests

This is a pure-prose change to a SKILL.md + a guide doc + a ROADMAP entry. No code paths to unit-test. The "test" is:

1. **Self-review** — re-read the new Step 1.8 prose to confirm the parser logic is unambiguous (an agent reading the skill at `/ak-go-live` invocation time can execute it without re-deriving the rules).
2. **Sample-input mental walkthrough** — using lalista PR #58's body as input (already merged, but the structure is canonical), trace what Step 1.8 would print and which items it would block on. Document the trace in this spec § Acceptance below.
3. **Convention check** — does the paired doc paragraph in `workflow.md` follow the docs-coverage hook contract (one paragraph, hyperlinks back to SKILL.md as canonical source)?

No bats / shell tests are added — devshop's `/ak-go-live` SKILL.md does not have existing bats coverage for prose-only steps (Step 1.5 / 1.6 / 1.7 don't have bats either; they're agent-executable prose).

## Task order

1. **Task 1 — SKILL.md Step 1.8 prose**: write the new step in `/devshop/.claude/skills/ak-go-live/SKILL.md` between Step 1.7 and Step 2. Bump version to `1.3.0`. Self-review the parser logic + the AskUserQuestion gate prose for unambiguity.
2. **Task 2 — workflow.md paired paragraph**: add the one-paragraph reference in `/devshop/kit/docs/guide/workflow.md § Step 6 § 1. Pre-flight` (alongside the existing prod-health / migration-sequencing bullets).
3. **Task 3 — ROADMAP cross-ref**: edit `/devshop/kit/ROADMAP.md` per D6. Update PLAN.md / BUILD-LOG / equivalent if devshop has them tracking this entry.

Tasks 1, 2, 3 are independent — order doesn't matter for correctness — but the listed order keeps the work organized: skill first (the substantive change), then doc (references the skill), then ROADMAP (records what shipped).

## Gotchas

- **`/ak-go-live` is invoked by an agent, not a CLI**: Step 1.8's prose must be executable by an agent reading the SKILL.md, not just descriptive. Match the existing 1.5/1.6/1.7 idiom — bash blocks the agent literally runs, AskUserQuestion as the blocking gate.
- **`gh pr view --json comments` returns ALL comments, not just bot-authored ones**: filter to comments matching the canonical `/ak-build` headers; don't accidentally parse a reviewer's casual comment that happens to contain `[ ]` markdown.
- **Section nesting**: PR-body convention has `### Manual review` nested INSIDE `## Test plan`. The parser must group items by their nearest enclosing recognized header (Manual review wins over Test plan when both apply); h3 takes precedence over h2 when items live under both.
- **Empty PR body**: not all PRs use `/ak-build`'s convention. If no recognized sections are found, surface a one-line message ("No structured Pending Tasks found in PR body — proceeding") and continue without blocking. The user can decide whether to manually verify out-of-band steps.
- **The skill must not assume `/ak-build` was used**: a hotfix PR opened by hand may not have a Test plan / Out-of-band deploy items section. The "no recognized sections found" path handles this.

## Acceptance / rollout / rollback

**Acceptance — sample trace** (lalista PR #58 body, all checkboxes already `[x]`; for the trace, imagine they were `[ ]`):

```
Pending tasks before live (PR #58 — db-hardening):

[manual] (blocks merge — Out-of-band deploy items):
  - After merge: paste subject "Your lalista password was changed" + body of supabase/templates/password-changed.html into prod Supabase dashboard → Auth → Templates → Password Changed tab. supabase/templates/** does NOT auto-deploy.
  - After merge: re-run Supabase Advisor against prod project; expect ≤ 2 findings.

[deferred] (Manual review — for PR reviewer; non-blocking):
  - Migration ROLLBACK semantics correct (drop indexes, restore old policies, revert search_path)
  - Combined profiles_select policy preserves household visibility (own row + same-household profiles via household_members join)
  - Password-changed email template visual review (terracotta-on-cream, lalista voice)

[!] (Test plan — CI checkboxes that should be auto-marked; non-blocking):
  (none)

Proceed? [y]es / [n]o (block on the [manual] prereqs above)
```

The trace shows the format the operator sees. After typing `y`, `/ak-go-live` continues to Step 2 (Land and deploy).

**Rollout:** docs-only diff. No deploy gate, no migration, no edge function. Lands on devshop merge to main.

**Rollback:** `git revert <commit>` on devshop main. The new Step 1.8 prose only fires inside `/ak-go-live` invocations; reverting it returns the skill to its pre-PR behavior (skip directly from 1.7 to 2). No persistent state to clean up.

<!-- /ak-spec (Phase 1) expands the file from here: any additional Screens / Data
     model changes / API contracts / Offline behavior / Metrics / Dependencies
     sections may stay empty for this prose-only PR. The Decisions section
     above stays verbatim. -->
