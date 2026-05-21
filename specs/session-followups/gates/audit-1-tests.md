# Audit 1 — Tests Review

**Range**: `origin/main..HEAD` (1 commit: `073b048`)
**Feature dir**: `specs/session-followups`
**Scope**: 3 bats files — `kit/tests/structural-invariants.bats`, `kit/tests/util-pre-push.bats`, `kit/tests/util-ak-merge-devshop.bats`. Net +30 assertions across the suite. All passing locally (76/76 ak-merge-devshop, 5/5 new pre-push, 3/3 new structural-invariants).

---

## Findings

### [domain: tests] [section: B] [severity: high]

**File**: `kit/tests/structural-invariants.bats:747-762`
**What**: The E5 placeholder-free header test is structurally incapable of failing. The loop body uses `<grep> && { ... false; } || true`. The `|| true` at the end of the chain swallows the `false` exit unconditionally, so the loop iteration always returns 0 — regardless of whether the placeholder was detected.

Reproducing against the current worktree confirms the bug. The actual source file `template/packages/core/src/index.ts` line 1 is:

```
// What: Barrel export for @PROJECT_NAME_PLACEHOLDER/core
```

That comment header **contains** `PROJECT_NAME_PLACEHOLDER`. The "regression" the test claims to guard against is **already present** in the file the test purports to assert on. Yet the test passes (verified via `./kit/tests/lib/bats-core/bin/bats kit/tests/structural-invariants.bats` — `ok 47`). Direct subshell reproduction:

```
$ for f in template/packages/core/vitest.config.ts template/packages/core/src/index.ts; do
    head -3 "$root/$f" | grep -q 'PROJECT_NAME_PLACEHOLDER' \
      && { echo "Placeholder leak in $f header (lines 1-3)"; head -3 "$root/$f"; false; } || true
  done
  Placeholder leak in template/packages/core/src/index.ts header (lines 1-3)
  // What: Barrel export for @PROJECT_NAME_PLACEHOLDER/core
  ...
$ echo $?
0
```

The leak is printed; the test still exits 0. This is the canonical "shape-only, fake green" anti-pattern — looks like a regression guard, has zero failure surface, creates false confidence in coverage that doesn't exist.

**Why**: This is a load-bearing scaffold-time invariant (per the commit body it closes a home-os-skill-polish-batch Audit 1 finding). Shipping the test in this broken shape means:

1. The actual regression risk the test claims to catch (placeholder leaking into a comment header) goes uncaught — both this commit's regression AND any future drift.
2. The audit machinery will record this as "test coverage added" for the E5 finding, closing the audit loop on a false signal.
3. Either the source file needs to be patched to be placeholder-free in the comment header (line 1 of `template/packages/core/src/index.ts`), OR the test description / scope is wrong (the comment-header placeholder is acceptable). Either way, the diff is internally inconsistent: the test claims one invariant; the source ships another.

**Fix**: Two distinct issues to resolve:

(a) Restructure the loop body so failures actually fail the bats test. The idiomatic bats shape uses `run` + explicit assertion:

```bash
for f in template/packages/core/vitest.config.ts template/packages/core/src/index.ts; do
  run head -3 "$root/$f"
  refute_output --partial 'PROJECT_NAME_PLACEHOLDER'
done
```

…or, if staying with the inline grep, drop `|| true` and let `false` propagate (bats `-e`-style semantics will fail the test on a non-zero exit inside the test body):

```bash
for f in template/packages/core/vitest.config.ts template/packages/core/src/index.ts; do
  if head -3 "$root/$f" | grep -q 'PROJECT_NAME_PLACEHOLDER'; then
    echo "Placeholder leak in $f header (lines 1-3):"
    head -3 "$root/$f"
    return 1
  fi
done
```

(b) Reconcile against the source. `template/packages/core/src/index.ts` line 1 currently contains `@PROJECT_NAME_PLACEHOLDER/core`. Either:

- Rewrite that header line to be placeholder-free (mirroring how `vitest.config.ts`'s header was rewritten in `c810c39`), making the new test green, OR
- Narrow the test scope to `vitest.config.ts` only and document why `src/index.ts`'s header legitimately retains the placeholder (scaffold-time sed target).

The bats test passing locally only because of the `|| true` bug is the worst outcome — it hides the source inconsistency from CI.

---

### [domain: tests] [section: B] [severity: medium]

**File**: `kit/tests/util-ak-merge-devshop.bats:106-118`
**What**: The new Phase 3 contract test `Phase 3 --source-worktree path skips the /devshop checkout main + ff-merge` collapses 4 named contract dimensions into a single OR-grep:

```bash
awk '/^## Phase 3:/,/^## Phase 4:/' "$SKILL_FILE" \
  | tr -d '\n' \
  | grep -qiE 'never touch.*devshop|skip the checkout|stays untouched|push.*directly.*from.*worktree'
```

Matching ANY ONE of the 4 phrases satisfies the test. This is precisely the loose-OR anti-pattern that the *other* test in this same commit (`Phase 4.2 warns operators to run each teardown step as a separate Bash call`) was just refactored away from — splitting an OR grep into 3 independent `grep -q` calls so any single missing dimension fails. The refactor's commit-body rationale: "the previous OR-shape would pass when only one keyword survived a doc rewrite."

**Why**: A future doc rewrite that drops the "stays untouched" framing, drops the "never touch /devshop" framing, AND drops the "skip the checkout" framing — but happens to retain the "push directly from worktree" prose — would silently pass this test. Three of four documented contract dimensions can drift away unnoticed. The Phase 3 two-path contract is load-bearing (the whole point of `--source-worktree` is to NOT touch /devshop's branch state), so the dimension that survives the rewrite isn't necessarily the most safety-critical one.

**Fix**: Mirror the Phase 4.2 split-OR refactor introduced in the same commit. Each dimension gets its own `grep -q` with a distinct failure message:

```bash
local section
section=$(awk '/^## Phase 3:/,/^## Phase 4:/' "$SKILL_FILE" | tr -d '\n')

# Dimension 1: the contract that /devshop's branch stays untouched.
echo "$section" | grep -qiE 'never touch.*devshop|stays untouched' \
  || { echo "Phase 3 --source-worktree path missing 'do not touch /devshop branch' contract"; false; }

# Dimension 2: explicit skip of the default-path ff-merge.
echo "$section" | grep -qiE 'skip the checkout|skip.*ff-merge' \
  || { echo "Phase 3 --source-worktree path missing 'skip the checkout + ff-merge' instruction"; false; }

# Dimension 3: the push-from-worktree mechanic.
echo "$section" | grep -qiE 'push.*directly.*from.*worktree' \
  || { echo "Phase 3 --source-worktree path missing 'push directly from worktree' mechanic"; false; }
```

Optional: drop dimension 3 if the existing `Phase 3 has a --source-worktree branch that pushes via git -C WORKTREE_PATH push origin HEAD:main` test (101-104) already covers it — but split the other two.

---

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/util-ak-merge-devshop.bats` (Phase 0.1 coverage gaps)
**What**: The Phase 0.1 `--source-worktree` short-circuit (40+ lines of new bash logic in the SKILL.md prose) adds five guard predicates; the new tests cover only two:

| Guard | Covered? |
|---|---|
| `[ -d "$SOURCE_WORKTREE_ARG" ]` — path-exists check | No |
| `git worktree list --porcelain | grep -qxF` — registered-worktree check | Yes (test "Phase 0.1 --source-worktree refuses when path is not a registered worktree") |
| `[ -z "$BRANCH" ]` — detached HEAD refusal | No |
| `[ "$BRANCH" = "main" \| "master" ]` — wrong-branch refusal | No |
| `AHEAD=0` — no-commits-ahead refusal | No |

The bats corpus shape is prose-grep guards over markdown, not actual behavioral coverage, so coverage of every guard predicate is somewhat lower-stakes than for executable scripts. Treat as low.

**Why**: A future SKILL.md edit could drop any of the four uncovered guards (e.g., remove the `BRANCH = main` refusal) and no test would catch it. That guard is load-bearing — without it, `--source-worktree /devshop` (passed by an operator confused about the flag's purpose) would attempt to squash-from-main onto main.

**Fix**: Add three grep guards in `## Phase 0.1` (~lines 80-95 of the bats file). Each is one line; total marginal cost is minimal:

```bash
@test "Phase 0.1 --source-worktree refuses path that exists but is not a directory" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qE '\[ ! -d "\$SOURCE_WORKTREE_ARG" \]'
}

@test "Phase 0.1 --source-worktree refuses detached-HEAD / main / master branches" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qE '\[ "\$BRANCH" = "main" \] \|\| \[ "\$BRANCH" = "master" \]'
}

@test "Phase 0.1 --source-worktree refuses branch with zero commits ahead of origin/main" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qiE 'AHEAD.*-eq 0|no commits ahead'
}
```

---

## Section C — Bypass trailer audit

`git log --format='%B' origin/main..HEAD | grep -E 'Tests-Coverage-Bypass:'` returns zero matches. No bypass trailers in range. Section C is empty.

---

## Summary

- Section A (coverage): 1 low finding — Phase 0.1 partial-guard coverage.
- Section B (quality): 1 high (E5 placeholder test is non-failing), 1 medium (Phase 3 contract test reverts to the OR-grep anti-pattern the same commit just refactored away).
- Section C (bypass): clean.

The high-severity finding is load-bearing — the E5 test ships as a coverage signal for a home-os-skill-polish-batch Audit 1 finding, but the test body cannot fail. The source file the test purports to guard already contains the placeholder it claims to reject. This needs reconciliation (fix the test logic + decide whether to rewrite the source header or narrow the test scope) before merge.

---

## Tally

`high=1 medium=1 low=1`
