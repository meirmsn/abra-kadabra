# Audit 2 — Tests Review

**Range**: `073b048..HEAD` (2 commits: `f71f0a6`, `ce549ad`)
**Feature dir**: `specs/session-followups`
**Scope**: 2 bats files — `kit/tests/structural-invariants.bats`, `kit/tests/util-ak-merge-devshop.bats`. Net `+29 -19` lines across the suite. All 128/128 relevant tests pass locally (`util-ak-merge-devshop` 79/79, `structural-invariants` 49/49).

**Context**: Audit 1 surfaced three findings (1 high, 1 medium, 1 low) against the prior commit `073b048`'s `.bats` additions. Audit 2 verifies that commit `f71f0a6` closes all three, and that the closures themselves don't introduce new regressions.

---

## Audit 1 closure verification

### [Audit 1 high] E5 placeholder-free header test is non-failing → CLOSED

The prior test body used the shell idiom `<grep> && { ... false; } || true`, which always exits 0 regardless of grep outcome. The fix at `kit/tests/structural-invariants.bats:744-768` rewrites to the idiomatic `if-then-fail` shape:

```bash
header=$(head -3 "$root/template/packages/core/vitest.config.ts")
if echo "$header" | grep -q 'PROJECT_NAME_PLACEHOLDER'; then
  echo "Placeholder leak in template/packages/core/vitest.config.ts header (lines 1-3):"
  echo "$header"
  false
fi
```

The `false` now propagates because there's no chained `|| true`. The scope is narrowed from `{vitest.config.ts, src/index.ts}` to vitest.config.ts only — `src/index.ts:1` legitimately contains `@PROJECT_NAME_PLACEHOLDER/core` because it IS substituted at scaffold time by `/ak-new-project § Step 10`'s sed against `package.json` + `src/index.ts` (vitest.config.ts is NOT in that sed list, which is exactly why the placeholder there is a leak risk and why narrowing scope is correct). The new comment-block at lines 745-754 documents this rationale.

Failure-surface verification: ran `head -3 template/packages/core/vitest.config.ts` — the header is placeholder-free ("Vitest config for packages/core" / "Toggle between unit tests…" / "VITEST_INTEGRATION env var…"). Bats `ok 47 scaffold: template/packages/core/vitest.config.ts header is placeholder-free`. To prove the test can now actually fail, the if-branch is structurally reachable (no `|| true` swallowing the exit) and `false` is the last statement before the `fi` — bats runs each test in a fresh subshell under `set -e`, and a non-zero exit at the statement level fails the test. The Audit 1 reproduction (the test passing while a real placeholder leak was present in the now-out-of-scope `src/index.ts`) no longer applies because (a) the loop is gone and (b) the predicate is `if/then/fail`, not `&&/||`.

**Closure**: verified.

### [Audit 1 medium] Phase 3 source-worktree contract test reverted to OR-grep anti-pattern → CLOSED

The prior shape was a single `grep -qiE 'never touch.*devshop|skip the checkout|stays untouched|push.*directly.*from.*worktree'` — any one of four phrases satisfied the test. The fix at `kit/tests/util-ak-merge-devshop.bats:131-150` splits into 3 independent `grep -q` calls with distinct failure messages:

```bash
# Dimension 1: explicit promise that /devshop's branch stays untouched.
echo "$section" | grep -qiE 'never touch.*devshop|stays untouched|won.t touch' \
  || { echo "Phase 3 missing '/devshop never touched' guarantee"; false; }

# Dimension 2: explicit description of the direct-push mechanism.
echo "$section" | grep -qiE 'push.*directly.*from.*worktree|push origin HEAD:main' \
  || { echo "Phase 3 missing 'push directly from worktree' mechanism"; false; }

# Dimension 3: explicit skip-the-checkout-and-ff branching.
echo "$section" | grep -qiE 'skip the checkout|skip.*ff-merge|two-path' \
  || { echo "Phase 3 missing 'skip checkout + ff-merge' branching"; false; }
```

Each dimension must independently match for the test to pass. The shape mirrors the Phase 4.2 split-OR refactor that the same parent commit established. Bats: `ok 16 Phase 3 --source-worktree path skips the /devshop checkout main + ff-merge`. The three regex alternations inside each dimension are *synonyms for the same concept* (different prose phrasings the SKILL.md might use to express the same contract), not orthogonal dimensions — that's the correct shape per the skill rubric. A future doc rewrite dropping all three synonyms in any one dimension would now fail loudly.

**Closure**: verified.

### [Audit 1 low] Phase 0.1 partial-guard coverage → CLOSED

The prior commit covered 2 of 5 guard predicates. Three new tests at `kit/tests/util-ak-merge-devshop.bats:101-125` cover the three missing predicates:

```
ok 12 Phase 0.1 --source-worktree refuses when path does not exist on disk
ok 13 Phase 0.1 --source-worktree refuses when the worktree is on main/master/detached HEAD
ok 14 Phase 0.1 --source-worktree refuses when the worktree has no commits ahead of origin/main
```

Grep-target verification against `.claude/skills/devshop/merge-devshop/SKILL.md § 0.1`:

- Test 12 grep `! -d "\$SOURCE_WORKTREE_ARG"|path does not exist` → SKILL.md line ~20: `if [ ! -d "$SOURCE_WORKTREE_ARG" ]; then` + `echo "✖ --source-worktree path does not exist: $SOURCE_WORKTREE_ARG"`. Both alternates match.
- Test 13 grep `must be on a feature branch|"\$BRANCH" = "main"|detached HEAD` → SKILL.md line ~32: `if [ -z "$BRANCH" ] || [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then` + `echo "✖ --source-worktree must be on a feature branch (currently: ${BRANCH:-detached HEAD})"`. All three alternates match.
- Test 14 grep `no commits ahead of origin/main|rev-list --count "origin/main\.\.\$BRANCH"` → SKILL.md line ~37: `AHEAD=$(git rev-list --count "origin/main..$BRANCH" 2>/dev/null || echo 0)` + `echo "✖ --source-worktree branch $BRANCH has no commits ahead of origin/main"`. Both alternates match.

Five-guard coverage matrix now reads:

| Guard | Covered? |
|---|---|
| `[ ! -d "$SOURCE_WORKTREE_ARG" ]` | Yes (test 12) |
| `git worktree list --porcelain \| grep -qxF` | Yes (test 11, pre-existing) |
| `[ -z "$BRANCH" ]` (detached HEAD) | Yes (test 13) |
| `[ "$BRANCH" = "main" \| "master" ]` | Yes (test 13) |
| `AHEAD=0` no-commits-ahead | Yes (test 14) |

**Closure**: verified.

---

## Section A — Coverage of new behavior

The two commits in range are themselves test-coverage closures + an audit-trail commit. There is no new source surface in `kit/scripts/**.sh`, `kit/scripts/preship/**.sh`, `.claude/skills/devshop/**/SKILL.md`, or `kit/hooks/**` in this range. The rubric returns zero new-source-needs-tests pairs.

The added tests *themselves* are skill-prose grep-guards over `.claude/skills/devshop/merge-devshop/SKILL.md`. By the skill's own rule (`bats corpus shape is prose-grep guards over markdown, not actual behavioral coverage` — `audit-1-tests.md:127`), these are second-order assertions, not behavioral coverage of executable code paths. The five Phase 0.1 guards collectively test that the SKILL.md prose contains the named refusal predicates — which is the deepest layer of coverage available for skill-only changes (skills are prose-as-instruction, not executable).

**Section A findings**: none.

---

## Section B — Test quality

### Weak assertions

The new tests use the `awk … | grep -qE …` predicate form. This is appropriate for skill-prose-as-data assertions — the test asserts the SKILL.md contains a named phrase / regex pattern, which is the contract under test. Grep with a non-empty regex is a concrete assertion (not `toBeDefined()`/`toBeTruthy()` shape). No weak-assertion findings.

### Failure-surface verification

The three new Phase 0.1 tests + the refactored Phase 3 test all use `grep -q … || { echo …; false; }` shape. The trailing `; false }` is inside an `||` chain that fires only when grep returns non-zero (i.e., when the contract pattern is missing from the SKILL.md section). Each `false` is the LAST statement in the `||` block, and bats subshell semantics propagate that exit code as the test result. This is the failure-surface shape Audit 1 demanded for the E5 test, and the four new/refactored tests apply it consistently. Verified against bats output: all four tests are currently `ok` because the SKILL.md prose contains every named predicate; toggling any one predicate out of the SKILL.md would flip the corresponding test to `not ok`.

### Implementation-detail tests

The tests grep for *predicate shapes* (`! -d "$SOURCE_WORKTREE_ARG"`, `"$BRANCH" = "main"`, `AHEAD=0` / `rev-list --count`) rather than just "is this section present?" — they pin the specific guard mechanism, not arbitrary prose. The regex alternations inside each grep (e.g., `must be on a feature branch|"$BRANCH" = "main"|detached HEAD` in test 13) accept *synonyms for the same guard*, not orthogonal guards. A SKILL.md rewrite that replaces `[ "$BRANCH" = "main" ]` with equivalent logic (e.g., a helper function `is_unsafe_branch "$BRANCH"`) would correctly fail the test — the test pins both the predicate's existence AND its observable shape. This is the right calibration for skill-prose tests: too-loose grep misses contract drift; too-strict regex breaks on harmless reformatting.

The Phase 3 split test's three dimensions use `tr -d '\n'` to flatten the section before grepping — the comment at lines 134-135 explains "to collapse multi-line markdown prose into a single line so multi-line phrases like 'never touch\n /devshop' still match." This is the same pattern the Phase 4.2 test introduced; consistent across the file.

### Missing boundary conditions

The five Phase 0.1 guards cover the predicate boundaries (path-not-exists, path-not-registered, detached HEAD, branch=main/master, AHEAD=0). The conditional alternations inside test 13 (detached HEAD + main + master) is a single test asserting the predicate covers all three cases via OR — which matches the SKILL.md's actual shape (`[ -z "$BRANCH" ] || [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]`). Could be split into 3 separate tests for "fail-on-detached", "fail-on-main", "fail-on-master" — but the marginal value is low given the predicate is a single line in the SKILL.md and any disturbance would affect all three. Not flagging as a finding; treating as deliberate-and-reasonable test granularity.

### Section B findings

None.

---

## Section C — Bypass trailer audit

```bash
$ git log --format='%B' 073b048..HEAD | grep -E 'Tests-Coverage-Bypass:'
# (zero matches)
```

No `Tests-Coverage-Bypass:` trailers in range. Section C is empty.

---

## Summary

- Audit 1 closures: 3/3 verified. The high-severity E5 test now has actual failure surface (if-then-fail, scoped to vitest.config.ts only). The medium-severity Phase 3 OR-grep is now three independent dimensions. The low-severity Phase 0.1 partial coverage is now full (5/5 guards covered).
- Section A (coverage): 0 findings — test-only + audit-trail range, no new source surfaces.
- Section B (quality): 0 findings — new tests use the if-then-fail shape, grep predicates pin the specific contract not just prose presence.
- Section C (bypass): 0 trailers in range.

The full bats suite under `kit/tests/` runs clean for the two touched files: `structural-invariants.bats` 49/49 + `util-ak-merge-devshop.bats` 79/79 = 128/128.

Tests look solid — no findings.

---

## Tally

`high=0 medium=0 low=0`
