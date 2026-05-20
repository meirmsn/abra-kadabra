### [domain: tests] [section: A] [severity: medium]

**File**: `kit/tests/structural-invariants.bats` (assertion not added)
**What**: `spec.md § Tests` claims "E5 placeholder rewrite — `kit/tests/structural-invariants.bats` (or equivalent) gets an assertion that `grep -r PROJECT_NAME_PLACEHOLDER template/packages/core/` returns zero hits after the rewrite." The E5 commit (`c810c39 fix(template): vitest config comment header placeholder-free`) rewrites `template/packages/core/vitest.config.ts:1` from `// What: Vitest config for @PROJECT_NAME_PLACEHOLDER/core` to `// What: Vitest config for packages/core`, but no corresponding grep assertion was added to any bats file in the range. `grep -rn 'PROJECT_NAME_PLACEHOLDER' kit/tests/` returns zero hits — the regression-protection assertion the spec promised is missing.
**Why**: Future template churn (a contributor copy-pasting a placeholder header into another `template/packages/core/**` file, or a future skill re-introducing the `@PROJECT_NAME_PLACEHOLDER` pattern) will re-leak the placeholder into instantiated project configs with no test signal. Placeholder leaks into vitest config caused test-runner identification confusion historically; the spec correctly identified this as worth a regression guard.
**Fix**: Add an assertion to `kit/tests/structural-invariants.bats` along the lines of:

```bash
@test "template: packages/core/ contains no PROJECT_NAME_PLACEHOLDER hits" {
  run grep -r 'PROJECT_NAME_PLACEHOLDER' "$DEVSHOP/template/packages/core/"
  [ "$status" -ne 0 ]   # grep returns 1 on no-match, 0 on match
}
```

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/util-pre-push.bats:259-280` (B3 short-circuit cases)
**What**: All four new B3 test cases use a single-commit fixture (`setup_branch_with_commits` + one `git commit`). The new short-circuit loop in `kit/hooks/pre-push.sh:133-142` iterates over multiple SHAs with an early `break` on first non-match. The multi-commit-partial-match path (e.g. PR body names commit 1 but not commit 2 → fall through) is not exercised — every test has exactly one branch SHA, so the `break` branch never fires.
**Why**: A regression that flips the loop logic (e.g. inverting `PR_BODY_HAS_ALL_SHAS=false` to `=true` on the partial-match branch, or changing `break` to `continue`) would pass all four existing tests because the partial-match codepath is dead in single-commit fixtures. The "PR body missing one commit SHA" spec case is conceptually present (Case 3 uses a body with zero SHAs) but conflates "all missing" with "some missing".
**Fix**: Add a fifth case with two commits where the PR body names only the first SHA:

```bash
@test "project pre-push: B3 fall-through — PR body names some but not all SHAs → adversarial reviewer fires" {
  setup_branch_with_commits
  echo "feat1" > "$TEST_REPO/feat1.txt"; git add feat1.txt
  git -c user.email=t@t.com -c user.name=T commit -q -m "feat: first"
  local sha1; sha1=$(git rev-parse HEAD)
  echo "feat2" > "$TEST_REPO/feat2.txt"; git add feat2.txt
  git -c user.email=t@t.com -c user.name=T commit -q -m "feat: second"
  # PR body names only the first SHA — second commit is unreferenced.
  gh_stub_with_pr_body "42" "PR body references $sha1 but not the second commit."
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  assert_output --partial "fails the text-hygiene gate"
}
```

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/structural-invariants.bats` (or equivalent — assertion not added)
**What**: `spec.md § Tests` claims "E10 `[OPERATOR-ONLY]` markers — grep assertion that Step 6 + Step 7 headers carry the marker." Commit `89a9a7b fix(ak-new-project): mark Steps 6 + 7 [OPERATOR-ONLY], add STOP openers` adds the markers to `.claude/skills/devshop/new-project/SKILL.md`, but no grep assertion was added.
**Why**: A future SKILL.md rewrite (e.g. step renumbering during a larger restructure) could silently drop the `[OPERATOR-ONLY]` markers; without a structural-invariant grep, the operator-vs-Claude attribution would regress with no test signal. This is operator-facing UX prose rather than executable behavior, but the spec explicitly promised the guard.
**Fix**: Add an assertion such as:

```bash
@test "ak-new-project: Step 6 + Step 7 carry [OPERATOR-ONLY] marker" {
  local skill="$DEVSHOP/.claude/skills/devshop/new-project/SKILL.md"
  grep -qE '^### Step 6.*\[OPERATOR-ONLY\]' "$skill"
  grep -qE '^### Step 7.*\[OPERATOR-ONLY\]' "$skill"
}
```

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/` (extension to existing test not made)
**What**: `spec.md § Tests` claims "A5 symlink shape — extend an existing bats test that asserts `/ak-new-project § Step 9` mentions the symlink invariant (grep-based; full integration test deferred to a fresh scaffold)." Commit `dd317d2 fix(ak-new-project): symlink ~/.claude/skills/gstack → workspace clone` adds the symlink instruction to Step 9, but no grep-based assertion was added to any existing bats test.
**Why**: A future SKILL.md edit could remove or relocate the `~/.claude/skills/gstack → /workspace/.claude/skills/gstack` symlink instruction at Step 9 with no test signal. The full integration test is reasonably deferred ("full integration test deferred to a fresh scaffold" — accepted), but the grep-based shape guard was the in-scope deliverable per spec.
**Fix**: Add an assertion such as:

```bash
@test "ak-new-project: Step 9 documents ~/.claude/skills/gstack symlink" {
  local skill="$DEVSHOP/.claude/skills/devshop/new-project/SKILL.md"
  grep -qE '~/\.claude/skills/gstack.*->.*\.claude/skills/gstack' "$skill" \
    || grep -qF 'ln -s' "$skill" # accept either prose or command shape
}
```

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/util-pre-push.bats:244-256` (`gh_stub_with_pr_body` helper)
**What**: The stub generator uses a nested-heredoc pattern where the outer heredoc is unquoted (`<<STUB`) and the inner heredoc is single-quoted (`<<'BODY'`). The outer-heredoc interpolation expands `$pr_body` before file-write, so the inner-heredoc's literal body ends up containing the already-expanded text. This works for plain ASCII bodies but is fragile: if a future test passes a body containing literal `$` characters (e.g. a body that mentions `$PR` or `$VAR`), the outer heredoc will attempt to interpolate those as shell variables at stub-creation time, silently producing the wrong stub text.
**Why**: The four tests in this PR all use either plain-text bodies or bodies referencing locally-expanded `$sha` / `$short` — none currently trip this. But the helper is a footgun for future contributors adding a regression test with a more realistic PR body (e.g. one that copies a real PR description containing `$PR_NUMBER` interpolations).
**Fix**: Either (a) document the constraint in a comment on the helper ("body must not contain literal `$` characters"), or (b) make the outer heredoc quoted (`<<'STUB'`) and pass `$pr_body` via an environment variable that the stub reads at runtime. Option (a) is the lower-effort fix and matches the test corpus's actual usage.

### [domain: tests] [section: C] [severity: low]

**File**: n/a — no `Tests-Coverage-Bypass:` trailers in `origin/main..HEAD`.
**What**: Bypass trailer harvest returned zero rows for this range. The bypass-trailer mechanic activates with PR-C and the spec explicitly notes this audit moment may legitimately harvest zero rows.
**Why**: Nothing to validate. Forward-compatible.
**Fix**: No action.
