## Gate 6: /review

- Result: findings (1) fixed
- Summary: Detection block is correct for the primary squash path; one medium finding on the phantom-rebase merge-fallback path which also commits without the detection guard.

### Findings

**M1 (medium): Phantom-rebase merge-fallback path bypasses the rename-detect block.**

The detection block is correctly positioned between `$GIT_CMD reset --soft "$ANCHOR"` (line 771) and `$GIT_CMD commit -F` (line 806) in the primary squash path. However, the phantom-rebase-error merge-fallback code block (lines 852-858) contains its own `$GIT_CMD reset --soft "$ANCHOR"` followed by `$GIT_CMD commit -F "/tmp/squash-message-${FEATURE}.txt"` -- and this second commit path has no rename-detect guard before it. If a virtiofs phantom-rebase error fires AND the staged delta contains a rename+symlink combo, the merge-fallback path will hit the same lint-staged stash crash that the detection block was designed to prevent.

Severity rationale: medium, not high -- the phantom-rebase path is itself a rare edge case (virtiofs on macOS only), and the rename+symlink combo is also rare. The intersection of both is very unlikely. The operator can still recover manually via the Known Limitations recipe. But the gap means the auto-detection promise in the updated prose ("now detected inline before the commit step") is incomplete for one of the two commit paths.

Fix options (pick one):
- **(a) Duplicate the detection block** into the merge-fallback code block, between its `$GIT_CMD reset --soft "$ANCHOR"` and `$GIT_CMD commit -F`. Same pattern, same variables.
- **(b) Add a prose note** in the merge-fallback section stating: "The rename-detect block from the primary path does not fire here. If the staged delta triggers the rename+symlink combo, the commit will fail at lint-staged; fall back to the Known Limitations recovery recipe." This is the minimal fix -- documents the gap without duplicating code.
- **(c) Extract the detection into a reusable inline function** called before both commit sites. This is cleaner but adds complexity to the LLM prompt.

Recommendation: option (b) is proportionate -- the intersection of both edge cases is very rare, and documenting it is sufficient.

### Notes (no action required)

- **$GIT_CMD usage is correct throughout** -- all 5 git commands in the detection block route via `$GIT_CMD`. No bare `git` that should be `$GIT_CMD`.
- **Empty-variable edge case is safe** -- when `RENAME_SRCS` or `ADDED_PATHS` is empty, `echo ""` produces one blank line, but `comm -12` on two blank lines outputs one blank line, and command substitution strips the trailing newline, leaving `COLLISIONS=""`. `[ -n "" ]` is false. No false-positive.
- **Paths with spaces** -- `awk '{print $2}'` would break on paths with spaces, but this is devshop-internal (no spaces in /devshop paths by convention) and the spec's Gotchas section already acknowledges this (`awk '{print $2}'` works because `--name-status` output for renames is `R<sim>\tOLD\tNEW`). Not a finding for this review.
- **Known limitations section reads coherently** -- the new auto-detect paragraph leads naturally into the existing mechanism explanation, and the updated TODOS cross-reference is accurate.
- **Bats tests are solid** -- 9 tests covering the required prose dimensions, all pass (88/88 green in the full suite). Coverage is consistent with sections A-K.
- **TODOS closure is clean** -- the detect-and-fallback entry is removed; the companion lint-staged entry is updated with a shipped note; no stale cross-references remain.

## Dismissals

None
