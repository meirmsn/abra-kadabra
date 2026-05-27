## Gate 6: /review

**Verdict: findings (1) pending**

Reviewed `git diff origin/main...HEAD` (6 files, +311/-26 lines) across 7 commits on `feat/pr-hygiene-hash-cache`. All 31 bats tests pass.

### Finding 1 (medium): Hash cache does not invalidate on new commits

**File:** `kit/hooks/pre-push.sh` lines 184-195

**Description:** The hash cache keys on `sha256(PR_TITLE + PR_BODY)` and skips the adversarial review when the hash matches the last successful review. However, the adversarial reviewer's accuracy dimension (dimension (a)) judges whether the PR title+body describes ALL commits on the branch (`origin/main..HEAD`). If new commits are pushed between reviews without editing the PR text, the hash matches (text unchanged) and the LLM call is skipped -- but the PR body is now stale relative to the commit range.

**Scenario:**
1. Push 1: branch has commit A ("feat: add login"). PR body says "Add login feature". Review PASSes. Hash cached.
2. Developer adds commit B ("feat: add signup"). Does NOT edit PR text.
3. Push 2: PR text re-fetched, hash recomputed, matches cached value. `PR_TEXT_UNCHANGED=true`. Adversarial review skipped. Push succeeds despite PR body being stale (describes 1 of 2 commits).

**Severity:** Medium. The accuracy dimension of the hygiene check exists specifically to catch this class of staleness. The SHA-enumeration fast-path (`PR_BODY_HAS_ALL_SHAS`) is `false` in this scenario (body doesn't mention commit B's SHA), so the hash-cache is the only thing preventing the reviewer from firing.

**Fix shape:** Include the commit range in the hash. For example: `printf '%s%s%s' "$PR_TITLE" "$PR_BODY" "$BRANCH_SHAS" | sha256sum | cut -d' ' -f1`. `BRANCH_SHAS` is already computed at line 167 for the SHA-enumeration check (but only inside `if [ -n "$PR_BODY" ]`). The hash computation would need to move inside that conditional or `BRANCH_SHAS` would need to be computed unconditionally. The tradeoff is minimal -- `git log --format='%H'` is fast. Alternatively, the hash could include the HEAD SHA: `$(git rev-parse HEAD)` -- simpler, and any new commit changes HEAD.

**Missing test:** No test covers the "new commit with unchanged PR text" scenario. A T5 test case should be added alongside the fix.

### Positive observations

- **Shell safety is solid.** All variable expansions are properly quoted. `printf '%s%s'` avoids trailing-newline ambiguity from `echo`. The `|| echo "{}"` fallback on `gh pr view` failure produces valid JSON for `jq`.
- **Worktree correctness.** `git rev-parse --git-dir` resolves to the worktree-specific directory in linked worktrees, so parallel worktrees get independent hash files.
- **Cache write only on success.** The `printf '%s' "$CURRENT_HASH" > "$HASH_FILE"` is inside the adversarial-passes block, after the `exit 1` on failure. Failed reviews never write the hash.
- **Test quality.** T1-T4 cover the four key states (no cache + pass, cache hit, cache miss, no cache + fail). The "adversarial would FAIL if invoked" trick in T2 is a clean way to prove the cache prevented the call.
- **Stub migration.** Existing tests correctly migrated from `create_stub gh "42"` to `gh_stub_with_pr_body` where needed (the `view` subcommand now returns JSON instead of the PR number).
- **No security escalation.** The hash file lives in `.git/` which is already trust-boundary-internal. Pre-seeding it requires `.git/` write access, which already implies full repo control.
- **Doc update is accurate.** The `hooks.md` addition correctly describes the mechanism and its location.
- **TODOS closure is clean.** The tracker entry is deleted in the same commit as the doc update.

## Dismissals

None
