## Audit 1 — Docs review

**Range**: `origin/main..HEAD` (`073b048`, 1 commit)
**Feature dir**: `specs/session-followups`
**Mode**: devshop self-mode (`$GIT_ROOT == /devshop/.worktrees/session-followups`, devshop worktree)
**Reviewer**: `/ak-docs-review` (audit-time)
**Reviewed at**: 2026-05-20

### Diff inventory

```
 .claude/skills/devshop/docs-review/SKILL.md   |  18 ++++-
 .claude/skills/devshop/merge-devshop/SKILL.md | 107 +++++++++++++++++++++-----
 kit/TODOS.md                                  |  21 +++++
 kit/docs/guide/hooks.md                       |   1 +
 kit/tests/structural-invariants.bats          |  62 +++++++++++++++
 kit/tests/util-ak-merge-devshop.bats          |  61 +++++++++++++--
 kit/tests/util-pre-push.bats                  |  31 ++++++++
 specs/home-os-skill-polish-batch/spec.md      |  14 ++--
 8 files changed, 280 insertions(+), 35 deletions(-)
```

No renamed/deleted files in range.

### Bypass trailers

No `Docs-Coverage-Bypass:` or `CLAUDE-MD-Bypass:` trailers in range.

### Section A — Coverage

Touched source surfaces and rubric verdicts:

- **`.claude/skills/devshop/docs-review/SKILL.md`** — skill internal-rubric expansion. Skill SKILL.md IS the doc. No external workflow.md / CLAUDE.md change required. **Pass**.
- **`.claude/skills/devshop/merge-devshop/SKILL.md`** — new `--source-worktree` operator escape hatch. Documented inline in Inputs + Phase 0.1 short-circuit + Phase 3 two-path branching. CLAUDE.md § Two repos, two commit flows already covers the default landing flow at the right grain; restating every flag would bloat CLAUDE.md against the inclusion rule. **Pass**.
- **`kit/docs/guide/hooks.md`** — IS a `kit/docs/guide/*.md` doc; self-documenting. **Pass**.
- **`kit/TODOS.md`** — carve-out (no firing).
- **`kit/tests/**`** — carve-out (no firing).
- **`specs/home-os-skill-polish-batch/spec.md`** — historical spec edit (Step 12.5 → 12.6 textual consistency with shipped `new-project` SKILL.md state). Specs are not in the rubric.

No Section A findings.

### Section B — Adequacy

For each touched reference doc, hunks inspected for substantive content + named-section claim verification:

1. **`.claude/skills/devshop/docs-review/SKILL.md`** — new "Named-mechanism empirical verification" rubric. Names symptom + root cause + cheap-verification examples (`dcg test`, `git config --get`, `gh api`, `node -e`) + severity rule (high, not medium, for wrong-but-cheap-to-verify claims) + worked incident citation (`home-os-skill-polish-batch` Audit 1, 2026-05-20, with the specific `/ak-merge-devshop § Phase 4.2` paragraph that triggered codification). Adequate.

2. **`.claude/skills/devshop/merge-devshop/SKILL.md`** — `--source-worktree <path>` flag. Inputs section explains use case (parallel-session WIP blocks branch-switch) + behavior (push direct via `git -C <worktree> push origin HEAD:main`) + side-effect note (local `main` ref in /devshop may lag origin/main). Phase 0.1 short-circuit includes 4 validations (path exists; is a registered worktree per `git worktree list --porcelain`; on a feature branch not main/master; ahead of origin/main). Phase 3 two-path branching with `-n "$SOURCE_WORKTREE_ARG"` switch; the existing checkout-failure error message gets a new "Alternative: re-invoke with --source-worktree" recovery hint. Worked-incident citation (2026-05-20 `fix/init-firewall-pipefail` parallel WIP blocker). Adequate.

3. **`kit/docs/guide/hooks.md § 3 — Husky pre-push § Short-circuits`** — new bullet for SHA-enumeration fast-path B3. States condition (every commit SHA in `origin/main..HEAD` literally appears in PR body as full SHA or any ≥7-char abbreviation; "Git's default minimum" qualifier present), justification (body up-to-date by construction → reviewer would PASS → short-circuit saves the round-trip), boundary (reviewer still fires on partial-SHA / commit-subject-overlap / missing-SHA / empty-body judgment cases), implementation citation (`kit/hooks/pre-push.sh § Check 2`) — VERIFIED, line 80 of pre-push.sh has `# --- Check 2: PR description staleness (project only) ---`, and test coverage citation (`kit/tests/util-pre-push.bats § B3`) — VERIFIED, file contains 7 B3 references. Adequate.

4. **`kit/TODOS.md`** — DCG `core.git:push-force-short` false-positive entry. Names rule, surfaces date, 5 empirical test cases with explicit blocked/allowed verdicts (including a one-line minimal reproducer `git push origin main && rm -f /tmp/x.txt`), investigation goal, current workarounds (links to `/ak-merge-devshop § Phase 4.2` and reason-text sanitization), and 3 fix-candidate paths (upstream patch / devshop-side wrapper / docs-only). Very substantive.

5. **`specs/home-os-skill-polish-batch/spec.md`** — textual `Step 12.5 → Step 12.6` consistency edit (7 occurrences). Verified against active state: `.claude/skills/devshop/new-project/SKILL.md` line 988 has `#### Step 12.6: Fill project CLAUDE.md skeleton`; CLAUDE.md references `/ak-new-project § Step 12.6` at the project-CLAUDE.md design-principle paragraph; no `Step 12.5` references remain in active docs (only historical narrative under `kit/notes/projects/home-os.md` and the intentional "previously Step 18" framing in `new-project/SKILL.md:990` which serves as authored historical context, not a stale reference). Adequate.

No Section B findings.

### Section C — Cross-doc coherence

- No renamed/deleted files → no stale-path sweep needed.
- Step 12.5 → 12.6 renumber sweep verified against active doc tree:
  - `.claude/skills/devshop/new-project/SKILL.md:988` — `Step 12.6` as live section header.
  - `CLAUDE.md` (loaded above via system reminder) — `Skill files (/ak-new-project § Step 12.6)` cross-reference correctly cites the new number.
  - `kit/notes/projects/home-os.md` and `kit/notes/roadmap/lalista-launch.md` still reference "Step 18" / "Step 12.5" — these are `kit/notes/**` historical notes (carve-out scope, no firing); their job is to document the state at the time of writing, not to track current numbering.
  - `.claude/skills/devshop/new-project/SKILL.md:990` reads `(Front-loaded — previously Step 18. ...)` — intentional authored historical framing explaining the front-loading decision, not a stale reference.
- Touched-doc claims do not contradict any reference doc not in the diff (CLAUDE.md, OVERVIEW.md, FAQ.md spot-checked).

No Section C findings.

### Section D — Bypass trailer audit

No `Docs-Coverage-Bypass:` trailers in range. Section is forward-compatible per skill spec; emit and move on.

### Section E — CLAUDE.md hygiene

Skipped (devshop self-mode; Section E is project-mode-only per `/ak-docs-review` skill spec).

### Verdict

**Clean — no docs findings.**

`high=0 medium=0 low=0`
