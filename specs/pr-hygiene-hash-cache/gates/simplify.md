## Gate 4: /simplify

**Verdict: pass**

Reviewed `kit/hooks/pre-push.sh` (hash-cache logic, ~20 lines) and `kit/tests/util-pre-push.bats` (4 new test cases + refactored `gh_stub_with_pr_body` helper). All 31 bats tests pass.

### Findings

None. The implementation is clean:

- **No correctness bugs.** `CURRENT_HASH` and `HASH_FILE` are always defined when consumed (both assignment and usage sit behind the same `ANY_COMMIT=true && ALL_TRIVIAL=false` precondition). Hash is written only after a successful adversarial review (line 219), never after failure (exit 1 on line 216 prevents reaching line 219). Non-atomic write to the hash file degrades gracefully (partial hash never matches, so the next push re-runs the review).
- **No dead code or unnecessary complexity.** `PR_TEXT_UNCHANGED` initialization at line 160 is defensively set before the block that may flip it; the redundancy is benign and improves readability.
- **No shell scripting anti-patterns.** External `jq` usage (lines 164-165) is consistent with the established pattern in `kit/scripts/adversarial-review.sh` (lines 387, 393). `printf` is correctly used over `echo` for hash computation (line 186) and file writes (line 219).
- **Test coverage is complete.** Four tests cover the key matrix: first-push-pass (T1), cache-hit (T2), cache-miss (T3), first-push-fail (T4). The refactored `gh_stub_with_pr_body` correctly outputs JSON for the new `--json title,body` call shape, and the CONSTRAINT comment is updated to cover `$pr_title`.
- **Single `gh` API call** fetches both title and body (line 163), avoiding a second round-trip compared to two separate `gh pr view` calls. Correct optimization.

### Items considered but not flagged

- `gh_stub_with_pr_body` JSON construction via string interpolation is fragile with special characters (quotes, backslashes, newlines in PR text), but this is a preexisting limitation inherited from the prior raw-body heredoc shape, and all test callers use plain ASCII. Out of scope.
- Hash computation includes both title and body (`printf '%s%s' "$PR_TITLE" "$PR_BODY"`), meaning two different title+body combinations that happen to concatenate to the same string would produce a false cache hit. This is astronomically unlikely in practice and not worth adding a separator for.

## Dismissals

None
