<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: ak-build-phase6-pr-surface -->
<!-- date: 2026-05-28 -->

# Spec: ak-build-phase6-pr-surface (devshop)

**Sources:**

- `kit/ROADMAP.md § /ak-build Phase 6 PR-surface fixes` — primary scope + decisions
- `PLAN.md` Planned row `ak-build-phase6-pr-surface` — scope summary + source pointer
- `.claude/skills/devshop/build/SKILL.md` Phase 6 (§ Post audit trail comment + Part D Gate A) — the edit target
- Prior shipped spec `specs/todo-merge-devshop-worktree-aware/spec.md` — style/structure reference

Completes a partial cleanup of `/ak-build` Phase 6: stop posting the gate-table
PR comment (the body + Phase 7 comment were already removed; Phase 6 was missed),
and make Part D's Gate A review the PR description autonomously instead of always
asking the operator to confirm it.

---

## Product update

Both blurbs as approved at Phase 0.2. Single source-of-truth — devshop mode
routes Headline → `BUILD-LOG.md` `Headline:` and Detail → `Summary:`, and
`/ak-merge-devshop` reads this section for the squash commit body. Verified
against the diff at Phase 6 Gate A + Gate B.

### Headline (user-facing)

`/ak-build` no longer drops a gate-status comment on your PRs, and it now reviews
the PR description itself instead of pausing to ask you to confirm it.

### Detail (team-facing)

Phase 6 stops posting the audit-trail comment — gate results stay in the
committed `review.md`. Part D's Gate A now reviews the Product-update blurbs
against the diff autonomously (mirroring Parts A/B/C), escalating to the operator
only when a real claim-vs-diff mismatch needs a product-judgment call the diff
can't settle.

---

## Decisions (resolved at spec time)

Four decisions resolved in Phase 0 with the operator (pre-resolved in the ROADMAP
entry). Recorded so Phase 1 preserves them verbatim and a crashed Phase 1 resumes
without re-asking.

### D1: How much of the Phase 6 audit comment to remove

**Decision:** Drop the `gh pr comment` audit-trail post entirely (the
`## Phase 6: Post audit trail comment` body block, ~SKILL.md:2663–2710). Keep the
Parts A–D verification sweeps — they validate the PR body; they just post nothing
afterward.

**Rationale:** Gate results already live in the committed
`specs/<feature>/review.md`. The comment duplicates them onto the PR timeline,
contradicting the no-clutter convention (Phase 4.1 "body … clean of devshop
process artifacts"; Phase 7 "the PR being open IS the notification").

### D2: New Gate A (Part D) behavior

**Decision:** Rewrite Gate A from "always `AskUserQuestion`" to autonomous review
mirroring Part C: read both blurbs against the diff + `$GATE_B_FINDINGS`, classify
into **Accurate** (log + continue) / **Edit-and-self-resolve** (rewrite blurb,
save back to `spec.md § Product update` + re-splice PR body + commit + re-run
Gate B once + log) / **Escalate** (`AskUserQuestion` ONLY when a genuine
claim-vs-diff mismatch's correct wording is a product-judgment call the diff can't
settle). Remove the "Why operator attention rather than auto-attest" + "~30s of
operator attention" justification paragraphs.

**Rationale:** The orchestrator already has every input needed (spec blurbs +
full diff + Gate B's automated cross-check). The escalation path still exists for
genuine mismatches. Consistent with Parts A/B/C, which auto-attest and only halt
on a real problem.

### D3: Consistency-reference sweep

**Decision:** In the same edit, rename the Phase 6 heading (no longer "Post audit
trail comment"); update the exit-checklist gate wording ("before posting the
audit-trail comment…"); the architecture-diagram line (~131–132); the
top-of-file mode description (line 6 "audit comment"); and the prose references
that say Phase 6 "posts"/"renders in" the audit comment (e.g. lines 21, 75, 842,
1288, 1349, 2284, 2361, 2454, 2468, 2722). Each becomes "records in
`review.md`" / equivalent. Sanity-check Phase 7 stays comment-free.

**Rationale:** Partial cleanup is the exact bug being fixed; a dangling reference
re-seeds the contradiction a future session reads as "Phase 6 posts a comment."

### D4: No Existing-projects propagation block

**Decision:** This PR needs no `**Existing projects:**` migration block.

**Rationale:** It edits only `.claude/skills/devshop/build/SKILL.md` — it does not
touch `template/**`, `kit/scripts/**`, `kit/hooks/**`, `.devcontainer/**`, or
`manifest.txt`, the only paths the squash hygiene check requires a block for.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Task order, Tests,
     Gotchas, Acceptance. The Product update + Decisions sections above stay
     verbatim. This is devshop-self-mode: no METRICS.md, no UI; the test surface
     is bats (kit/tests/), not vitest/Playwright. -->

## Core user story

N/A — devshop skill-prose edit only; no user-facing product flow added or modified. The "user" is the `/ak-build` orchestrator (Claude) reading the skill; observable behavior changes are covered by `## Acceptance` + bats, not a qa-walk.

## In scope

All edits land in **one file**: `.claude/skills/devshop/build/SKILL.md`.

1. **Drop the Phase 6 audit-trail PR comment (D1).** Remove the `gh pr comment "$PR" --body "$(cat <<COMMENT ... ## Pre-ship audit ... COMMENT )"` post (the fenced bash block ~SKILL.md:2677–2708 plus its "The audit comment is intentionally concise…" preamble ~2672–2675). Keep the Parts A–D verification sweeps that precede it — they validate the PR body and stay. Remove the trailing `# NOW post the audit-trail comment (the gh pr comment call below).` step in the exit checklist (~3009).

2. **Make Part D / Gate A autonomous (D2).** Rewrite Gate A (~2920–2977) from "always surface via `AskUserQuestion`" to autonomous review mirroring Part C's factual-checkbox closure: read both blurbs against the diff + `$GATE_B_FINDINGS`, then classify into one of three outcomes:
   - **Accurate** — blurbs match the diff → log a one-line attestation in `review.md § Product update verification`, continue. (No operator prompt.)
   - **Edit-and-self-resolve** — a fixable drift (stale wording, missing-claim, audience-shape leak Gate B flagged) → rewrite the blurb in `spec.md § Product update`, re-splice the PR body's `## Product update` section, commit on the feature branch (`chore(<feature>): refine product blurb post-Gate-A`), re-run Gate B once, log. After two loops, accept and continue.
   - **Escalate** — `AskUserQuestion` ONLY when a genuine claim-vs-diff mismatch's correct wording is a product-judgment call the diff can't settle.
   Delete the two justification paragraphs ("Why operator attention rather than auto-attest" ~2973 and "Why ~30s of operator attention…" ~2975). Preserve the `awk` blurb-extraction snippet (~2922–2938) and the Gate-B-findings input — they're still the orchestrator's inputs.

3. **Consistency-reference sweep (D3).** In the same edit, rewrite every reference that frames Phase 6 as posting/rendering-in an audit comment so each describes Phase 6 as recording results in `review.md` / validating the PR body:
   - Phase 6 heading (~2663): `## Phase 6: Post audit trail comment` → reframe (e.g. `## Phase 6: Verify the PR surface`).
   - Top-of-file mode description (~6): `project (default — PR-based, CI watch, audit comment, /ak-go-live)`.
   - Architecture diagram line (~131–132): `reads review.md … for audit comment`.
   - Exit-checklist wording (~2981–2983, ~3000–3004): "Before posting the audit-trail comment…" / "The audit-trail comment will NOT post."
   - Prose refs that say Phase 6 "posts" / "renders in" the audit comment (the grep hits at ~21, 75, 400, 433, 589, 842, 1288, 1349, 1768, 1777, 2262, 2284, 2361–2362, 2454, 2468, 2577, 2604, 2655, 2711, 2722, 2855, 2977, 3111). Each: rephrase to record-in-`review.md` / validate-the-PR-body. Lines that legitimately reference Phase 6 doing other work (CI-green watch, evidence sweep) stay; only the "comment" framing changes.
   - Sanity-check Phase 7 stays comment-free (it already is per the Phase 7.2 bats assertions).

## Out of scope

- Any change to Phase 7 behavior (already comment-free; only sanity-checked here).
- Project-mode CI watch / preview-deploy reconciliation logic in Parts A/B — they keep validating the PR body; only the comment *post* is removed.
- `/ak-merge-devshop`, `/ak-go-live`, or any downstream skill — they read `spec.md § Product update` / `review.md`, not the dropped comment.
- No `**Existing projects:**` propagation block (D4 — edits only `.claude/skills/**`, none of `template/**`, `kit/scripts/**`, `kit/hooks/**`, `.devcontainer/**`, `manifest.txt`).
- No `kit/docs/**` changes anticipated — the audit comment lives only in the SKILL.md prose. If a guide doc turns out to describe Phase 6 as posting a comment, fold the fix into this PR (it's the same logical change), but the grep below confirms scope.

## Files to modify

- `.claude/skills/devshop/build/SKILL.md` — D1 + D2 + D3 (the only production-surface file).
- `kit/tests/util-product-update-blurb.bats` — update the Gate-A assertion to match the autonomous rewrite, add a "Phase 6 posts no audit comment" assertion (see `## Tests`).

## Tests

The test surface is **bats** (`kit/tests/`), not vitest/Playwright. The only bats file asserting Phase 6 comment/Gate-A behavior is `kit/tests/util-product-update-blurb.bats`:

- **Existing assertion that WILL break and must be updated** — `@test "Phase 6 Part D names Gate A (operator confirmation) …"` (line 164) greps `Gate A.*operator confirmation`. D2 removes the "always operator confirmation" framing, so this string changes. Rewrite the assertion to match the new contract: Gate A is autonomous, with `AskUserQuestion` reserved for genuine claim-vs-diff escalation. Assert the three outcomes are present (e.g. grep for `autonomous` / `Accurate` / `Edit-and-self-resolve` / `Escalate` within the Part D region) rather than the old "operator confirmation" wording. Keep the Gate-B assertions (lines 171–181) — Gate B stays warn-not-block and still parses `spec.md § Product update` via `awk`. The `Part D.*Product update` anchor (lines 159–161) stays valid since the heading rename doesn't touch Part D's own heading.
- **New assertion warranted** — mirror the existing Phase-7 precedent (`@test "Phase 7.2 does not post a ready-for-review PR comment"`, line 189) with a Phase-6 analogue: assert Phase 6 posts NO `gh pr comment` audit/pre-ship comment. Anchor a region from the Phase 6 heading to `## Phase 7` and assert `! grep -qiE 'gh pr comment.*(audit|pre-ship)'` (the `gh pr edit` body-fix calls in Parts A/B legitimately remain, so target the *comment* verb specifically). This locks the D1 removal against regression.
- **Run** `pnpm turbo run test` (or `bats kit/tests/util-product-update-blurb.bats kit/tests/util-ak-build-skill.bats` for the fast inner loop) and confirm green. No other bats file references the audit comment in a way the edit changes (`util-ak-build-fix-loop.bats` line 89 asserts the Phase 5.5 *escalation* `gh pr comment`, which is unrelated and stays).

## Task order

1. **D1 + D3 — drop the audit-comment post and run the consistency sweep.** In `.claude/skills/devshop/build/SKILL.md`: remove the `gh pr comment` audit block + its "intentionally concise" preamble, drop the `# NOW post…` exit-checklist step, rename the Phase 6 heading, and rewrite every audit-comment reference (top-of-file mode line, architecture diagram, exit-checklist wording, and the ~20 prose hits) to "records in `review.md` / validates the PR body." Sanity-check Phase 7 stays comment-free. Done when `grep -nE 'audit comment|audit-trail comment|Post audit trail comment' SKILL.md` returns nothing in a posting/rendering frame.
2. **D2 — rewrite Part D / Gate A to autonomous 3-way classify.** Replace the "always `AskUserQuestion`" flow + the two justification paragraphs with the Accurate / Edit-and-self-resolve / Escalate contract, preserving the `awk` blurb-extraction snippet and Gate-B input. Keep the Part D exit marker.
3. **Tests — update + add bats assertions.** In `kit/tests/util-product-update-blurb.bats`: rewrite the line-164 Gate-A assertion to match the autonomous contract; add the new "Phase 6 posts no audit comment" assertion mirroring the Phase 7.2 precedent. Run the suite; confirm green.

(Flat — 3 tasks, well under 15. Task 1 and 2 both edit the same file but are separable logical units; commit per task. Task 3 must follow because its assertions describe the post-edit prose.)

## Gotchas

- **Partial cleanup is the exact bug.** The body comment + Phase 7 comment were removed in a prior PR but Phase 6 was missed — a dangling reference re-seeds the contradiction. Per `CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`, sweep *every* reference in this one PR; don't leave a "Phase 6 posts a comment" phrasing anywhere. The D3 grep list is the checklist.
- **Distinguish `gh pr comment` from `gh pr edit`.** Parts A/B legitimately call `gh pr edit "$PR" --body-file` to fix stale checkboxes — those stay. Only the `gh pr comment` audit *post* is removed. The new bats assertion must target the comment verb, not the edit verb, or it will false-positive.
- **The line numbers in the Decisions + this body are pre-edit anchors.** They drift as soon as the first removal lands. Re-grep (`grep -n "audit comment\|gh pr comment\|Phase 6"`) after each task rather than trusting the numbers.
- **`bats` runs need the vendored submodule libs.** This is a worktree — if `bats` fails with `Could not find '…/bats-support/load'`, run `git -C <worktree> submodule update --init --recursive` (per `CLAUDE.md § Why the submodule step`). The orchestrator created the worktree with the submodule step, so this should already be satisfied.
- **`review.md` is the surviving audit trail.** Gate results were never *only* in the comment — they live in committed `specs/<feature>/review.md`. Removing the comment loses nothing a cold reviewer needs; the prose rewrites should point readers there.
- **devshop-self-mode** — no METRICS.md, no `## Render conditions` (no UI), no offline-behavior declaration, no migration/deploy-boundary rows. The Confidence-Calibration stop-and-ask categories don't fire (no schema, auth, third-party API, perf path, security logic, or test deletion — the bats change *adds* an assertion and *rewrites* one to track the new contract, it doesn't delete coverage).

## Acceptance

- [ ] `.claude/skills/devshop/build/SKILL.md` Phase 6 no longer contains a `gh pr comment` audit/pre-ship post; the Parts A–D verification sweeps remain.
- [ ] Part D / Gate A is autonomous: Accurate (log + continue) / Edit-and-self-resolve / Escalate (`AskUserQuestion` only on a genuine claim-vs-diff product-judgment mismatch). The two "Why operator attention" justification paragraphs are gone.
- [ ] `grep -nE 'audit comment|audit-trail comment|Post audit trail comment' .claude/skills/devshop/build/SKILL.md` finds no surviving phrasing that frames Phase 6 as *posting* or *rendering in* a comment (the Phase 6 heading, top-of-file mode line, architecture diagram, exit checklist, and the ~20 prose refs all reframed to record-in-`review.md` / validate-the-PR-body).
- [ ] Phase 7 confirmed comment-free (unchanged; sanity-checked).
- [ ] `kit/tests/util-product-update-blurb.bats`: the Gate-A assertion matches the autonomous contract; a new assertion verifies Phase 6 posts no audit comment.
- [ ] `pnpm turbo run test` green (devshop bats suite, including the updated + new assertions).
- [ ] No `**Existing projects:**` propagation block (D4 — only `.claude/skills/**` touched).
