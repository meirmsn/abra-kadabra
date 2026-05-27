# Tests Review — Audit 1

**Range**: `origin/main..HEAD`
**Feature**: `specs/release-propagation-review`

## Findings

### [domain: tests] [section: B] [severity: medium]

**File**: `kit/tests/propagation-entry.bats:226-233`
**What**: Test "release.sh --no-push exits before commit" asserts a false invariant. The grep pattern `CLAUDECODE=.*commit` matches line 227 — an `echo` string inside the `--no-push` block itself (`echo "  2. Committing: CLAUDECODE= git commit -m ..."`), NOT the actual `git commit` command at line 239. The real commit uses a line continuation (`CLAUDECODE= git \` on line 239, `commit` on line 242), so `CLAUDECODE=` and `commit` never appear on the same line — the grep never matches it. The test proves line 220 < line 227 (both inside the same `if` block), which is trivially true and says nothing about the ordering of `--no-push exit` relative to the actual commit.
**Why**: The test gives false confidence that the `--no-push` exit-before-commit invariant is verified. If someone moved the `--no-push` block after the commit (breaking the invariant), this test would still pass — the echo string would move with the block and remain after the `if` line.
**Fix**: Change the grep to match the actual commit invocation. The real commit is `CLAUDECODE= git \` (line 239). Use a pattern that matches the non-echo `CLAUDECODE=` line, e.g.:

```bash
# Match the actual CLAUDECODE= git commit, not the echo instruction
commit_line=$(grep -n '^CLAUDECODE= git' "$RELEASE_SCRIPT" | grep -v 'echo' | head -1 | cut -d: -f1)
no_push_exit=$(grep -n 'exit 0' "$RELEASE_SCRIPT" | head -1 | cut -d: -f1)
# Or match the exit 0 inside the --no-push block vs the CLAUDECODE= git \ line
```

### [domain: tests] [section: A] [severity: medium]

**File**: `kit/tests/propagation-entry.bats` (missing test)
**What**: No test verifies that `--finalize` without a prior `--no-push` (i.e., no staged release files) fails gracefully. The `--finalize` block reads `VERSION_FILE` and commits whatever is staged, with no guard that the expected files (`kit/version`, `template/.devshop-version`, `CHANGELOG.md`) are actually staged. A bare `release.sh --finalize` on a clean tree would produce an empty commit or a commit with only PROPAGATION.md (from the re-stage).
**Why**: Could silently produce a malformed release commit (missing version bump, missing changelog) if invoked out of sequence.
**Fix**: Add a behavioral test that runs `release.sh --finalize` on a clean tree (no prior `--no-push`) and asserts it exits non-zero with an error message. Alternatively, add a guard to `release.sh` itself and test the guard.

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/propagation-entry.bats` (missing test)
**What**: No test verifies that the `--finalize` block has rollback behavior on failure. The `--finalize` block exits at line 94, before the rollback trap is registered at line 207. If `git tag` or `git push` fails inside `--finalize`, the script exits with an error and no cleanup — the commit is kept but there's no guidance message (unlike the `committed` phase rollback in the main path).
**Why**: Operator gets no recovery instructions if `--finalize` partially fails (commit lands, tag or push fails). The main path handles this gracefully via the `rollback` trap's `committed` phase, but `--finalize` bypasses that trap entirely.
**Fix**: Either register a similar trap inside the `--finalize` block, or add a structural test asserting that `--finalize` sets `PHASE` and uses the same rollback trap. The current test suite only checks the happy path.

## Summary

- **Section A** (coverage of new behavior): 1 medium, 1 low. The new `--no-push` and `--finalize` flags have structural tests but are missing error-path coverage. The `--finalize` without prior `--no-push` path is untested.
- **Section B** (test quality): 1 medium. The `--no-push exits before commit` test has a weak assertion that matches an echo string instead of the actual commit command, proving nothing about the invariant it claims to verify.
- **Section C** (bypass trailers): 0 trailers in range. Nothing to audit.

`high=0 medium=2 low=1`
