# Audit 1 — Tests Review

**Range**: `origin/main..HEAD` (single commit `900c572`)
**Scope**: 3-file commit — `.claude/skills/devshop/merge-devshop/SKILL.md` (3 hardenings), `.claude/skills/devshop/build/SKILL.md` (Phase 5.8 cross-ref), `kit/tests/util-ak-merge-devshop.bats` (1 updated + 3 new grep-against-SKILL.md assertions). Skill-prose change branch — no runtime code paths, no migrations, no edge functions. Test surface is grep-against-SKILL.md only.

## Section A — Coverage of new behavior

Three SKILL.md hardenings landed in this commit; each has a corresponding new or updated bats assertion in `kit/tests/util-ak-merge-devshop.bats`:

1. **Phase 2 anchor-selection block** (decide between `origin/main` and local `main` based on `git rev-list --count origin/main..main`) → covered by new test #47 `Phase 2 anchor-selects between origin/main and local main` (grep-pins the detection command + the `ANCHOR=` assignment) AND updated test #46 `Phase 2 uses $GIT_CMD on rebase + reset --soft + commit` (now accepts both `origin/main` and `"$ANCHOR"` shapes, with an in-test comment naming the forward-compat rationale).

2. **Phase 1 medium-severity interactive halt** (devshop's Phase 5.8 equivalent via `AskUserQuestion` + `DEVSHOP_AUDIT_MEDIUM_POLICY` env hatch) → covered by new test #44 `Phase 1 interactively pauses on medium-severity findings (devshop Phase 5.8 equivalent)` (two grep groups — one pins the prose semantics `medium-severity|interactive pause|AskUserQuestion`, the other pins the env hatch + cross-ref `DEVSHOP_AUDIT_MEDIUM_POLICY|Phase 5\.8`).

3. **Phase 4.2 DCG-safe per-step teardown** (instructs operators to split `submodule deinit -f` + `worktree remove --force` into separate Bash tool calls so the DCG `core.git:push-force-short` rule's pattern-match doesn't trip on chained `-f`/`--force`) → covered by new test #60 `Phase 4.2 warns operators to run each teardown step as a separate Bash call (DCG -f pattern-match)` (alternation pin `DCG.*pattern-match|separate.*Bash.*tool call|do not chain` captures the three distinctive prose phrases).

The fourth change — `/ak-build § Phase 5.8` cross-ref to merge-devshop's Phase 1 medium-halt — is a doc-only cross-reference; covered by the docs review side of this audit, not the tests side. No bats coverage required.

Devshop-side rubric satisfied: no new `kit/scripts/**.sh`, no new `kit/scripts/preship/**.sh`, no new `.claude/skills/devshop/**/SKILL.md` (only edits to existing). The existing `kit/tests/util-ak-merge-devshop.bats` proves-by-grep is the canonical pattern for this skill — extending it (not adding a new file) is the right move.

Section A: 0 findings.

## Section B — Test quality

**Weak assertions**: N/A — these are grep-against-SKILL.md bats assertions, not value-comparison unit tests. The relevant quality dimension here is "are the grep patterns distinctive enough to fail when the SKILL.md drifts away from the intent, and lax enough not to false-positive on cosmetic edits." Verified per-test below.

**Test #44 (Phase 1 medium-halt)**: Two grep groups, both AND'd. First group pins three semantic-content phrases via alternation — `medium-severity|interactive pause|AskUserQuestion`. Each appears in the actual SKILL.md prose (verified by running the grep against the file: all three phrases hit). Second group pins the env hatch identifier + cross-ref to project-side phase — `DEVSHOP_AUDIT_MEDIUM_POLICY|Phase 5\.8`. Both alternations distinctive; neither tautological. Removing the new behavior would fail both groups. Quality: solid.

**Test #46 (updated — $GIT_CMD on rebase + reset + commit)**: Pre-fix shape was `origin/main` literal; post-fix is `"$ANCHOR"`. Test now accepts both via `(origin/main|"\$ANCHOR")`. In-test comment names the rationale (test name pins the `$GIT_CMD` invariant, not the anchor literal). Concern noted: a hypothetical regression that reverted `"$ANCHOR"` back to `origin/main` literal would still pass test #46 — but the anchor-detection block test #47 catches that regression independently. Defense-in-depth via the pair, not a redundancy. Quality: thoughtful — explicit forward/back compat with the rationale comment-pinned, and the regression-vector is covered by the paired test.

**Test #47 (Phase 2 anchor-selection)**: Two grep pins. First — `git rev-list --count origin/main\.\.main` — is load-bearing: this exact command appears only in the anchor-detection block; if the block is gutted, this grep fails. Second — `ANCHOR=(origin/main|main)` — verifies an `ANCHOR=` assignment line exists with either of the expected values. The skill ships both (default `ANCHOR=origin/main` + conditional `ANCHOR=main`), so both are pinned by the alternation. Minor: a partial revert that removed only the conditional override would still pass the second grep (the default-assignment line satisfies it). But the first grep alone is enough to detect "block removed entirely," which is the realistic regression vector. Quality: solid — primary pin is distinctive; secondary pin is a sanity check.

**Test #60 (Phase 4.2 DCG warning)**: Single grep with three-way alternation `DCG.*pattern-match|separate.*Bash.*tool call|do not chain`. Each branch matches an actual phrase in the SKILL.md (`DCG -f pattern-match constraint`, `Always run each teardown step as a SEPARATE Bash tool call`, `DO NOT chain`). The alternation is generous (any one of three matches), which is appropriate for prose-content matching where the exact wording may evolve. A cosmetic edit that rewords two of three phrases still passes via the third; gutting the warning entirely fails all three. Quality: solid.

**Missing error / invalid input tests**: N/A — bats grep assertions don't have error-path / invalid-input failure modes. The grep either matches or doesn't.

**Untested auth boundaries (RLS)**: N/A — devshop-side test surface; no database, no RLS.

**Implementation detail tests**: The grep-against-SKILL.md pattern IS testing implementation detail by definition — the contract is "this prose appears in this file." But the alternative (running the skill end-to-end with mocked git operations and asserting behavior) is prohibitively expensive for skill-prose changes, and the bats coverage acts as a "doc-drift sentinel" rather than a behavior test. The risk profile (skill prose updated without test updates → silent regression) is the right one to monitor here. Acceptable per the established pattern in this test file (70 existing tests, all grep-based). No finding.

**Missing boundary conditions**: N/A for grep-based tests.

**Shape-only assertions**: N/A — these aren't shape assertions on rendered output. Bypass via established pattern (grep-against-SKILL.md is the canonical devshop-skill test shape).

**WebKit form-state hydration race**: N/A — no Playwright E2E in this diff.

**Realtime test missing publication migration**: N/A — no realtime subscriptions in this diff.

**Wrapper API design — lifecycle events not just data**: N/A — no `packages/core/src/api/**` changes in this diff.

**`routeWebSocket` after initial subscribe is a dead test**: N/A — no WebSocket routing in this diff.

**Runtime validation at LLM / edge-function boundaries**: N/A — no `client.functions.invoke<T>` or `fetch(...).then(r => r.json()) as T` in this diff.

**Skipped tests audit**:

```bash
git diff --diff-filter=AM origin/main..HEAD -- '*.spec.ts' '*.test.ts' '*.test.tsx' \
  | grep -nE '^\+.*\b(test|describe|it)\.(skip|only)\b' | grep -v '^+++'
```

Returns nothing. No `.only` / `.skip` patterns introduced. The diff is bats-only (no `.spec.ts` / `.test.ts`); skip-pattern audit on bats files is N/A (bats has its own `skip` mechanism via `skip` builtin, none of the new tests use it). Verified via direct grep on the diff: zero `skip` invocations in new tests. 0 findings.

Full suite verified: 70/70 in `kit/tests/util-ak-merge-devshop.bats` pass against the post-fix SKILL.md (operator-confirmed; spot-checked by running the suite from the worktree).

Section B: 0 findings.

## Section C — Bypass trailer audit

Harvest:

```bash
git log --format='%H%n%B%n---' origin/main..HEAD | grep -E 'Tests-Coverage-Bypass:'
```

Returns zero rows. No `Tests-Coverage-Bypass:` trailers in the range. The bypass-trailer mechanic activates in PR-C; this range legitimately has none.

Section C: 0 findings.

## Summary

Tests look solid — no findings.

The three new bats assertions + one updated assertion exactly match the three SKILL.md hardenings (Phase 2 anchor selection, Phase 1 medium halt, Phase 4.2 DCG-safe teardown). Each new test grep-pins distinctive phrases tied to the new behavior contract, with alternation generous enough to survive cosmetic rewording but distinctive enough to fail on intent-regression. The updated test #46 explicitly accepts both pre-fix and post-fix anchor shapes (with rationale-comment); the paired test #47 catches the regression vector that test #46 alone would tolerate. Full suite passes 70/70 from the worktree.

`high=0 medium=0 low=0`
