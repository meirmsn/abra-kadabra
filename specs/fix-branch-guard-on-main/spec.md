<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: fix-branch-guard-on-main -->
<!-- date: 2026-05-26 -->

# Spec: fix-branch-guard-on-main

**Sources:**

- `kit/TODOS.md` § `check-branch-not-main.sh` PreToolUse hook didn't block — primary scope + investigation plan
- `PLAN.md` § Planned (v0) row `fix-branch-guard-on-main` — scope summary
- Prior spec `specs/bats-hang-on-main-commit/` — style + structure reference

Close the TOCTOU race between the PreToolUse `check-branch-not-main.sh` hook
and actual `git commit` execution that allowed a commit to land on main during
a multi-session interleaving (2026-05-20 incident, commit `ef6db18`).

---

## Product update

### Headline (user-facing)

Prevent Claude from accidentally committing to main when parallel sessions switch branches.

### Detail (team-facing)

Close the TOCTOU race between the PreToolUse `check-branch-not-main.sh` hook and actual `git commit` by adding a Claude-specific (`$CLAUDECODE=1`) branch guard in `.husky/pre-commit`. The PreToolUse hook stays as fast feedback; the husky guard is the backstop that runs at actual commit time with no race window. Bats tests cover both layers.

---

## Decisions (resolved at spec time)

4 `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below
so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking.

### D1: Root cause

**Decision:** Parallel-session TOCTOU race, NOT a `-c` flag bug.

**Rationale:** Empirically verified: `-c` flag stripping + `git commit` regex detection works correctly in `check-branch-not-main.sh`. The gap is between PreToolUse "allow" and actual `git commit` — a parallel session can switch the branch in that window.

### D2: Where to add the enforcement backstop

**Decision:** `.husky/pre-commit` — early, before lint-staged — gated on `$CLAUDECODE=1`.

**Rationale:** Husky runs inside the git process at actual commit time; no TOCTOU window. Only blocks Claude; humans still commit on main (release.sh). `$CLAUDECODE=1` is an env var the Claude Code harness already sets in all subprocesses.

### D3: Keep the PreToolUse hook

**Decision:** Yes — fast feedback layer. Husky guard is the backstop.

**Rationale:** PreToolUse catches 99%+ of cases instantly. The husky guard catches the rare TOCTOU race from parallel sessions.

### D4: Test shape

**Decision:** `kit/tests/check-branch-not-main.bats` — exercises both PreToolUse and husky guards.

**Rationale:** Command-form coverage for PreToolUse (various `-c` flag combos, `cd` chains, non-git commands). Claude-detection + branch-detection for husky guard.

---

## In scope

1. **Husky branch guard** — add a `$CLAUDECODE=1`-gated branch check in `.husky/pre-commit`, placed after the bash re-exec block and before `pnpm exec lint-staged`. When `CLAUDECODE=1` and the current branch is `main` or `master`, exit with a clear error. Humans (`CLAUDECODE` unset) pass through unconditionally.
2. **Bats tests for PreToolUse hook** — the existing `kit/tests/guard-branch-not-main.bats` already covers the PreToolUse hook (`check-branch-not-main.sh`). Task 1 adds a few targeted tests for the multi-`-c`-flag incident command form to confirm the existing hook handles it (regression anchor).
3. **Bats tests for husky branch guard** — new tests exercising the Claude-detection + branch-detection logic in `.husky/pre-commit`, covering: Claude on main (blocked), Claude on feature branch (allowed), human on main (allowed), human on feature branch (allowed).
4. **Documentation** — update `CLAUDE.md § Known Footguns` "Never commit directly to main" entry to document the TOCTOU race, the two-layer defense (PreToolUse + husky), and the worked incident (`ef6db18`).
5. **Close the TODOS entry** — delete the investigation-plan entry from `kit/TODOS.md` lines 53-68.

## Out of scope

- Modifying the PreToolUse hook (`check-branch-not-main.sh`) itself — it works correctly; the race is architectural.
- Session-level locking / worktree-level mutex for parallel sessions — filed as a separate ROADMAP item if needed.
- Changing the PreToolUse matcher glob in `.claude/settings.json`.
- Template propagation — `.husky/pre-commit` is devshop-only (projects have their own husky config).

## Files to create/modify

| File | Action | What changes |
|---|---|---|
| `.husky/pre-commit` | **modify** | Add 6-line Claude branch guard block after bash re-exec, before lint-staged |
| `kit/tests/guard-branch-not-main.bats` | **modify** | Add 2-3 regression-anchor tests for the exact incident command form (`git -c ... -c ... commit`) |
| `kit/tests/guard-husky-branch.bats` | **create** | New bats file: 6-8 tests for the husky Claude branch guard (Claude/human x main/feature matrix, edge cases) |
| `CLAUDE.md` | **modify** | Expand "Never commit directly to main" Known Footgun with TOCTOU explanation + two-layer defense |
| `kit/TODOS.md` | **modify** | Delete the `check-branch-not-main.sh` investigation entry (lines 53-68) |

## Tests

### Existing tests to extend: `kit/tests/guard-branch-not-main.bats`

These tests already cover the PreToolUse hook comprehensively. Task 1 adds regression anchors for the exact incident form:

- **`blocks exact incident form: git -c docsReviewed=... -c docsCoverageReason=... commit`** — the command shape from the 2026-05-20 incident. Confirms the existing hook handles it (it does; the race was the bug, not the hook).
- **`blocks git -c with env-var prefix: VAR=val git -c key=val commit`** — compound form combining env-var assignment and `-c` flags.

### New test file: `kit/tests/guard-husky-branch.bats`

Tests the husky branch guard in isolation by extracting the guard logic into a small testable script snippet run against a temp git repo.

**Test matrix (Claude x branch):**

| # | Test name | `CLAUDECODE` | Branch | Expected |
|---|---|---|---|---|
| 1 | `blocks Claude commit on main` | `1` | `main` | exit 1, stderr contains "BLOCKED" |
| 2 | `blocks Claude commit on master` | `1` | `master` | exit 1, stderr contains "BLOCKED" |
| 3 | `allows Claude commit on feature branch` | `1` | `feat/x` | exit 0 |
| 4 | `allows human commit on main` | unset | `main` | exit 0 |
| 5 | `allows human commit on feature branch` | unset | `feat/x` | exit 0 |

**Edge cases:**

| # | Test name | Scenario | Expected |
|---|---|---|---|
| 6 | `allows when CLAUDECODE is empty string` | `CLAUDECODE=""` on main | exit 0 (not Claude) |
| 7 | `allows when CLAUDECODE is 0` | `CLAUDECODE=0` on main | exit 0 (guard checks `= 1`) |
| 8 | `blocks even with -c flags (TOCTOU regression)` | `CLAUDECODE=1`, main, simulated `-c` flag commit | exit 1 |

**Testing approach:** The husky guard lives inline in `.husky/pre-commit` (not a separate script). Tests will extract just the guard logic into a small wrapper that sources the relevant lines, OR test the guard by running the full `.husky/pre-commit` in a controlled environment where lint-staged/gitleaks are stubbed out. Given that `.husky/pre-commit` calls `pnpm exec lint-staged`, `gitleaks`, and bats, the cleaner approach is to:

1. Extract the guard block into a self-contained function or script snippet.
2. Test that snippet directly — the guard is early-exit, so it can be tested in isolation without running the full pre-commit pipeline.

Concrete plan: create a helper function in the test file that runs only the guard portion of `.husky/pre-commit` by `sed`-extracting lines between known markers (or simpler: write a 6-line guard script that mirrors the production guard exactly and test that, then visually verify parity in the commit). The production code stays inline in `.husky/pre-commit` (no new file to maintain); the test exercises an extracted copy whose parity is enforced by a bats test that diffs the guard block against the production file.

**Simpler approach (preferred):** The guard is only ~6 lines. Inline it in `.husky/pre-commit` and write the bats tests to run a small standalone script that contains the identical logic. Add a parity test: `guard logic in .husky/pre-commit matches test fixture` — `grep` the production file for the guard block and compare against the test's embedded copy. This catches drift without extracting a separate script.

## Dependencies

- **bats-core + bats-assert + bats-support** — already vendored as submodules under `kit/tests/lib/`. No new deps.
- **jq** — already available in the devcontainer; used by existing tests.
- **`$CLAUDECODE` env var** — set by Claude Code harness in all subprocesses. No action needed; we just read it.

## Task order

### Task 1: Add regression-anchor bats tests for PreToolUse hook

**File:** `kit/tests/guard-branch-not-main.bats`

Add 2-3 tests to the existing file that reproduce the exact command forms from the 2026-05-20 incident:

```bash
@test "blocks exact 2026-05-20 incident form: git -c docsReviewed -c docsCoverageReason commit" {
  git -C "$TEST_REPO" branch -m main 2>/dev/null || true
  local json
  json=$(jq -n --arg cmd 'git -c devshop.docsReviewed="kit/docs affected: overview pointers updated" -c devshop.docsCoverageReason="docs-only commit" commit -m "docs: update overview"' '{"tool_input": {"command": $cmd}}')
  run bash -c "cd '$TEST_REPO' && bash '$CHECK'" <<< "$json"
  assert_failure 2
  assert_output --partial "BLOCKED"
}
```

**Done when:** All new tests pass. Existing tests unbroken.

### Task 2: Add Claude-specific branch guard in `.husky/pre-commit`

**File:** `.husky/pre-commit`

Insert after the bash re-exec block (after line 5: `fi`), before the symlink recreation block (before line 8: `# Recreate devshop symlinks`):

```bash
# Claude-specific branch guard — backstop for the PreToolUse check-branch-not-main.sh hook.
# The PreToolUse hook runs BEFORE the Bash tool but has a TOCTOU race: a parallel session
# can switch branches between "hook allows" and "git commit executes". This husky guard
# runs inside git's commit process itself — no race window.
# Only blocks Claude ($CLAUDECODE=1); humans commit on main for release.sh version bumps.
if [ "${CLAUDECODE:-}" = "1" ]; then
  if [ "$_current_branch" = "main" ] || [ "$_current_branch" = "master" ]; then
    echo "BLOCKED: Claude commit on main/master (husky branch guard)." >&2
    echo "" >&2
    echo "A parallel session may have switched branches. Create a branch first:" >&2
    echo "  git checkout -b <type>/<topic>" >&2
    exit 1
  fi
fi
```

**Wait** — `_current_branch` is set on line 22 of the current file, AFTER lint-staged. The guard needs the branch check early, so it must compute the branch itself (or move `_current_branch` earlier). Simpler: compute `_current_branch` right at the top (duplicate the one-liner), then the existing line 22 assignment becomes a no-op reassignment. OR: move the existing `_current_branch=...` line up to just after the bash re-exec block, and reference it in both the guard and the bats block.

**Chosen approach:** Move the `_current_branch` assignment to just after the bash re-exec block (before the symlink recreation). The guard references it immediately after. The later bats block (line 22+) already uses `_current_branch` and will use the already-set value.

```
# After bash re-exec (line 5):

_current_branch=$(git branch --show-current 2>/dev/null || echo "")

# Claude branch guard (6 lines)
if [ "${CLAUDECODE:-}" = "1" ]; then
  if [ "$_current_branch" = "main" ] || [ "$_current_branch" = "master" ]; then
    echo "BLOCKED: Claude commit on main/master (husky branch guard)." >&2
    echo "" >&2
    echo "A parallel session may have switched branches. Create a branch first:" >&2
    echo "  git checkout -b <type>/<topic>" >&2
    exit 1
  fi
fi

# Recreate devshop symlinks if missing (existing line)
```

Then delete the duplicate `_current_branch=...` from its old position (current line 22). The bats-suite `if` block that references `_current_branch` continues to work because the variable is already set.

**Done when:** `CLAUDECODE=1 git commit` on main exits 1 with "BLOCKED". `git commit` on main without `CLAUDECODE` proceeds normally. Feature-branch commits unaffected regardless.

### Task 3: Add bats tests for the husky branch guard

**File:** `kit/tests/guard-husky-branch.bats` (new)

Test approach: since the husky guard is inline in `.husky/pre-commit` and cannot be sourced independently without triggering lint-staged/gitleaks, extract the guard logic into a small test-harness script that:

1. Sets `_current_branch` from the test repo.
2. Runs the identical `if` block.
3. Exits with the same codes.

Then add a **parity test** that greps `.husky/pre-commit` for the guard block's signature lines and asserts they match the test harness — catches drift.

Tests (8 total, as enumerated in the Tests section above).

**Done when:** All 8 tests pass. Parity test confirms the guard block in `.husky/pre-commit` matches the test fixture.

### Task 4: Document multi-session TOCTOU footgun in `CLAUDE.md § Known Footguns`

**File:** `CLAUDE.md`

Replace the current "Never commit directly to main" bullet with an expanded version:

```markdown
- **Never commit directly to main** — every change goes through a feature branch.
  Before `git commit`, run `git branch --show-current`. If `main`/`master`, create
  a branch first: `git checkout -b <type>/<topic>`. Two layers enforce this for Claude:
  (1) `check-branch-not-main.sh` PreToolUse hook — fast feedback before the Bash tool
  runs; (2) `.husky/pre-commit` Claude branch guard (`$CLAUDECODE=1` gate) — backstop
  at actual commit time, closes the TOCTOU race where a parallel session switches
  branches between PreToolUse "allow" and `git commit` execution (worked incident:
  2026-05-20, commit `ef6db18` landed on main via parallel-session branch switch).
  Humans commit on main unconditionally (release.sh needs this).
  **Do not propose creating a GitHub PR on devshop** — that's the project workflow;
  devshop lands via `/ak-merge-devshop`.
```

Also delete the closed TODOS entry from `kit/TODOS.md`.

**Done when:** The Known Footgun entry documents both layers + the incident. The TODOS entry is removed.

## Gotchas

1. **`_current_branch` must be computed early.** The existing `.husky/pre-commit` sets `_current_branch` on line 22 (after lint-staged). The guard needs it before lint-staged. Solution: move the assignment up to just after the bash re-exec block. The later reference is a harmless re-read of an already-set variable — delete the duplicate to keep it clean.

2. **Dash re-exec is load-bearing.** The first 5 lines of `.husky/pre-commit` re-exec under bash when running under dash. The guard must go AFTER this block (it uses `${CLAUDECODE:-}` which is bash-safe but the `[` builtins work in both). Since the guard is after the re-exec, it always runs under bash. No dash compatibility concern.

3. **`$CLAUDECODE` is set by the Claude Code harness, not by us.** We only read it. If the harness ever stops setting it, the guard becomes a no-op (fails open to "allow") — same posture as the PreToolUse hook. This is intentional: fail-open for the husky guard means humans are never blocked; the PreToolUse hook is the primary defense for Claude.

4. **The husky guard cannot be tested by running `.husky/pre-commit` directly** because it calls `pnpm exec lint-staged`, `gitleaks`, and bats. Tests must extract and exercise the guard logic in isolation, with a parity check to catch drift.

5. **Exit code: use `exit 1` (not `exit 2`).** The PreToolUse hook uses `exit 2` (Claude Code convention for "block this tool call"). Husky hooks use standard exit codes: nonzero = abort commit. Use `exit 1`.

6. **The guard runs in every devshop + project repo commit.** `.husky/pre-commit` is shared across repos. The guard is harmless in project repos: Claude should never be on `main` there either (branch protection). But if a project legitimately needs Claude on main (unlikely), the `CLAUDECODE` gate means only Claude is affected — humans pass through.

7. **Worktree commits fire the same `.husky/pre-commit`.** Worktrees share the same `.git/hooks/` (or husky wiring). A worktree on `feat/x` will have `_current_branch=feat/x` and pass the guard. No worktree-specific concern.

8. **Template propagation.** `.husky/pre-commit` is NOT templated — it is specific to each repo. The guard lives only in the devshop's `.husky/pre-commit`. Projects get their own husky config from the template, which does not include this guard (projects use branch protection instead). No propagation concern.
