## Gate 6: review

**Scope:** `git diff origin/main..HEAD` — skill-prose change to `/ak-build`'s SKILL.md
(Phase 6: drop the audit-trail PR comment; make Part D Gate A autonomous) + a
cross-reference sweep across sibling skills (devshop-mode, docs-review, tests-review,
go-live, pre-ship, spec) + guide docs (workflow, FAQ, OVERVIEW, claude-md, conventions)
+ bats coverage (`util-product-update-blurb.bats`). No runtime code.

**Posture:** gstack `/review` adapted to skill-prose grain — correctness, intent-match,
control-flow integrity, cross-reference accuracy. Read against `spec.md` (D1–D4) for intent.

### Verdict: clean. No high/medium findings. One low (tracker-closure timing) for Phase 4.0.

---

### What was verified (all PASS)

1. **Autonomous Gate A logic is a coherent, self-consistent instruction.** The 3-way
   classify (Accurate / Edit-and-self-resolve / Escalate) is unambiguous: each row has a
   distinct trigger and a distinct action; the triggers partition the space (match vs.
   fixable-drift vs. genuine-judgment-call) with no overlap. Escalate is explicitly the
   ONLY operator prompt (SKILL.md:2918), and that string is what the new bats assertion
   greps for. Mirrors Part C's auto-attest posture as the spec (D2) directs.

2. **Every input the new Gate A prose references actually exists in the surrounding bash.**
   `$DIFF_RANGE` (defined SKILL.md:2835), `$GATE_B_FINDINGS` (built 2859–2878), the
   `awk`/`sed` blurb-extraction snippet (preserved, feeds `SPEC_HEADLINE`/`SPEC_DETAIL`),
   the `/tmp/product-update-diff-files.txt` summary (2908), the `review.md § Product update
   verification` log target (2916–2917), and the `/tmp/phase6-partD.done` marker (2939) are
   all present and correctly named. No dangling variable reference.

3. **No control-flow gap from removing the comment-post.** Searched the entire file for
   orphaned posting phrasing (`before posting` / `will/does not post` / `posts against` /
   `NOW post` / `to post` / `posting time`): zero hits. The Part D exit transition
   (2935–2937: "If `$EVIDENCE_MISSING` is empty … → Phase 6's verification sweeps are
   complete. If any halt fires, Phase 6 does not exit clean.") cleanly replaces the old
   "→ continue to the audit-comment post." The exit-checklist (2941–2967) verifies the
   four `/tmp/phase6-part{A..D}.done` markers and ends with "The PR body is trustworthy" —
   the removed `# NOW post the audit-trail comment` trailer is gone, and nothing downstream
   (Phase 7) hands off to a comment that no longer exists. The heading rename
   (`Post audit trail comment` → `Verify the PR surface`) is reflected in the architecture
   diagram (line 132), the resume-table phase list (line 400), and the top-of-file mode
   description (line 6).

4. **Faithful to spec intent; no over-/under-reach.** D1 (drop the `gh pr comment` block +
   "intentionally concise" preamble + exit-checklist trailer) — done; the only surviving
   `gh pr comment` is the unrelated Phase 5.5 CI-failure escalation (SKILL.md:2200), outside
   the Phase 6 region, exactly as the spec gotcha predicts. D2 (autonomous Gate A; delete the
   two justification paragraphs) — done; both "Why operator attention" and "~30s of operator
   attention" paragraphs are gone, replaced by a single "Why autonomous" paragraph.
   D3 (consistency sweep) — `grep -nE 'audit comment|audit-trail comment|Post audit trail|
   post the audit|renders? in.*comment'` over SKILL.md returns nothing in a posting frame.
   D4 (no Existing-projects block) — correct; diff touches only `.claude/skills/**`,
   `kit/docs/**`, `kit/tests/**`, `PLAN.md`, `kit/ROADMAP.md` — none of the propagation-block
   trigger paths (`template/**`, `kit/scripts/**`, `kit/hooks/**`, `.devcontainer/**`,
   `manifest.txt`).

5. **Cross-reference rewrites are accurate.** Spot-checked each: devshop-mode.md ("no Phase 6
   (PR-surface verification)"), docs-review/tests-review/claude-md severity rubrics
   ("medium → recorded in review.md; Phase 6 verifies the PR surface against it"),
   go-live.md (`[ ]`-checkbox source reworded to "PR body (plus any legacy audit comment on
   PRs that pre-date the removal)" — correctly handles already-merged PRs), spec.md Phase-6
   verification line (now describes the 3-way classify), conventions.md PR-body-structure +
   product-update sections (Gate A "verifies … autonomously … escalating … only on a genuine
   … mismatch"), workflow.md pipeline diagram + Phase 6 narrative + HUMAN-REVIEW line
   ("review.md audit trail" replaces "audit comment"). All describe the NEW behavior correctly.
   The go-live backfill-script paragraph correctly reframes historical comments as legacy.

6. **bats coverage matches the new contract and is green.** Ran
   `kit/tests/util-product-update-blurb.bats` via the vendored bats — 39/39 pass. The
   rewritten assertion (Gate A autonomous + the three `**Accurate**`/`**Edit-and-self-resolve**`/
   `**Escalate**` outcomes + Gate B automated cross-check), the new "escalation is the only
   operator prompt" assertion, and the new "Phase 6 posts no audit-trail PR comment" assertion
   (anchored Phase-6→Phase-7, asserts `! grep gh pr comment` — targets the comment verb, not
   the legitimate `gh pr edit` body-fix calls) all pass against the actual prose.

7. **No missed live cross-reference elsewhere.** Repo-wide grep for surviving "Phase 6
   posts/post a comment" assertions in skills + docs found only two hits, both correct and
   intentionally retained: conventions.md:593 (historical worked-incident describing lalista
   PR 18 in past tense — accurate history, its forward codification points at the still-extant
   "Phase 6 Part B evidence-sweep posture") and workflow.md:239 (the 5.3.5 body-consistency
   check, unrelated to the comment). Neither asserts a live posting behavior.

---

### Findings

**[low] Tracker-closure timing — ROADMAP entry + PLAN row still present, owned by Phase 4.0.**
The `kit/ROADMAP.md § /ak-build Phase 6 PR-surface fixes` entry and the `PLAN.md` Planned row
for `ak-build-phase6-pr-surface` were both added by this branch's planning commit (`293746e`,
not pre-existing on `origin/main`) and are still present in the diff. Per
`CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`, the PR that ships the fix must
delete its own ROADMAP entry and clear the PLAN Active/Planned row. This is **not** a
`/review`-gate code-correctness finding and is **expected** to be open at review time — the
BUILD-LOG + PLAN/ROADMAP closure is Phase 4.0's job, which has not yet run (per the live task
tracker, Phase 4.0 is pending). Flagged only so the orchestrator confirms at Phase 4.0 that
BOTH the PLAN row AND the ROADMAP entry are removed (the ROADMAP one is easy to miss — closure
usually focuses on PLAN/BUILD-LOG). No action required at this gate.

---

## Dismissals

- **gstack `/review` SQL-safety / LLM-trust-boundary / conditional-side-effect checks** —
  `n/a`. This PR contains no runtime code, no SQL, no LLM call sites, no edge functions —
  it is skill-prose + Markdown docs + bats test prose only. The structural-bug surface
  `/review` targets does not exist in this diff.
- **`gh pr comment` still present at SKILL.md:2200** — dismissed. This is the Phase 5.5
  CI-failure escalation comment (`## CI failing — help needed`), explicitly out of scope per
  spec gotcha "Distinguish `gh pr comment` from `gh pr edit`" and the new bats assertion's
  comment, which anchors the no-comment check to the Phase-6→Phase-7 region only. Correct.
- **`gh pr edit --body-file` calls in Parts A/B (SKILL.md:2688)** — dismissed. These are
  legitimate stale-checkbox body fixes the spec (D1, Out-of-scope) explicitly preserves; the
  removal targets the comment verb only.

findings: high=0 medium=0 low=1
