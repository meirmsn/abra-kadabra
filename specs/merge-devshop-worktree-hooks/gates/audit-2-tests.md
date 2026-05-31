findings: high=0 medium=0 low=1

### [domain: tests] [section: B] [severity: low]

**File**: kit/tests/util-ak-merge-devshop.bats:877-887 — "Phase 3 ff-merge gitleaks scan is ordered before the git merge --ff-only $BRANCH"
**What**: The ordering test extracts the ff-merge anchor line via `grep -nE 'git merge --ff-only "\$BRANCH"' | head -1`, but there are TWO matches for that pattern inside the `## Phase 3:` → `## Phase 4:` awk range: SKILL.md:1300 (the real code line) and SKILL.md:1310 (a recovery-prose sentence: "If `git merge --ff-only "$BRANCH"`fails …").`head -1`happens to select the code line only because the code precedes the prose. The gitleaks scan line (1294) sits before both, so the assertion is currently correct — but the test relies on incidental line ordering, not a guard. By contrast the sibling Phase 2 ordering test (test 104) is robust because`commit -F`is single-match in its range.
**Why**: If the Phase 3 prose were ever reworded to lead with the recovery sentence above the code (or the code line refactored to a different literal),`head -1`could latch onto the prose mention and the test would assert against the wrong anchor — passing or failing for the wrong reason rather than catching a real regression.
**Fix**: Tighten the anchor to the unique code form, e.g. match the trailing comment`git merge --ff-only "$BRANCH"`followed by`# ff main` (or assert exactly one non-prose match). Non-blocking — the gitleaks-presence test (106) already pins the load-bearing "gate exists" invariant, and this test's intent (halt-before-ff-merge) holds at HEAD. Low.

Coverage (Section A, devshop rubric — `.claude/skills/devshop/**/SKILL.md` → util-`<skill>`.bats): the post-Audit-1 source change is the Phase 3 ff-merge gitleaks gate (a7058e4) in merge-devshop/SKILL.md. It is covered by THREE new Section G bats tests, all green at HEAD (ok 105/106/107):

- test 105 (cwd-pin): pins Phase 2's `( cd "$WORKTREE_PATH" && gitleaks protect --staged` subshell — closes Audit 1's [low] kit/tests:220 finding that the cwd-pin was unpinned. Mutation: dropping the subshell fails this test.
- test 106 (presence): pins `gitleaks git --redact --log-opts "$ANCHOR..$BRANCH"` exists in the Phase 3 range. Mutation: deleting the gate fails it. awk bounds verified — `## Phase 3:` (SKILL.md:1225) → `## Phase 4:` (1352) are real unique headers; the invocation matches once in range.
- test 107 (ordering): pins the scan precedes `git merge --ff-only "$BRANCH"` (halt-before-merge). See the [low] above re: the two-match `head -1` fragility — correct at HEAD, but anchor could be tightened.

The (b) `pnpm install` recipe change is prose-only (CLAUDE.md recipe + security.md) with no executable surface, so no dedicated test is the right call — same judgment as Audit 1.

Test quality (Section B): the 5 Section G tests use grep-against-skill-prose at the right granularity for a SKILL.md (matches the file's existing 100+ test style). Non-empty guards (`[ -n "$gitleaks_line" ]` / `[ -n "$commit_line" ]` / `[ -n "$ffmerge_line" ]`) prevent a vacuous pass if an anchor regex stops matching — a future refactor that drops a line fails loudly rather than silently green. No weak `toBeTruthy`-class assertions (n/a — bats). No skipped tests, no `.only`, no LLM/edge/realtime/RLS surface in range (devshop self-mode — no application code). Full suite green: 109/109 (`util-ak-merge-devshop.bats`), 1575/0 across `kit/tests/` per BUILD-LOG.

Bypass trailer audit (Section C): no `Tests-Coverage-Bypass:` trailers in range. (none)
