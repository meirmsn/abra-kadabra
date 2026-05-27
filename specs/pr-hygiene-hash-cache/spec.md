<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: pr-hygiene-hash-cache -->
<!-- date: 2026-05-26 -->

# Spec: pr-hygiene-hash-cache

**Sources:**

- `kit/TODOS.md` § prTextHygiene pre-push hook re-evaluates on every push — primary scope source
- `kit/hooks/pre-push.sh` § Check 2 (lines 113–205) — the code surface being modified
- `kit/scripts/adversarial-review.sh` — the adversarial review engine invoked by the hook
- `PLAN.md` row `pr-hygiene-hash-cache` — scope summary and priority

**One-liner:** After the first successful prTextHygieneReason adversarial review on a branch, cache a SHA-256 hash of the PR title + body so subsequent pushes with unchanged PR text skip the ~30s LLM call.

---

## Product update

### Headline (user-facing)

Repeat pushes on the same branch skip the ~30-second PR text-hygiene review when neither the PR title nor body has changed since the last successful review.

### Detail (team-facing)

After the first successful `prTextHygieneReason` adversarial review, the pre-push hook writes a SHA-256 hash of `$PR_TITLE$PR_BODY` to `$(git rev-parse --git-dir)/pr-hygiene-hash`. On subsequent pushes it re-fetches the PR text from GitHub, recomputes the hash, and short-circuits the LLM call when the hash matches. The hash file lives inside the git directory (worktree-safe, never committed, invisible to `git status`). Saves ~60s per typical `/ak-build` run (2-3 redundant reviews eliminated).

---

## Decisions (resolved at spec time)

Four `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below so Phase 1 preserves them verbatim and a crash-restart resumes without re-asking.

### D1: What to hash

**Decision:** `printf '%s%s' "$PR_TITLE" "$PR_BODY" | sha256sum | cut -d' ' -f1` — the concatenation of PR title and body text, hashed with SHA-256.

**Rationale:** Both fields are judged by the prTextHygieneReason reviewer (accuracy of title, readability of title, body shape). Both must be cache-invalidating. Concatenation is order-stable; `printf` avoids trailing-newline ambiguity from `echo`.

### D2: Where to store the hash

**Decision:** `$(git rev-parse --git-dir)/pr-hygiene-hash` — a single file inside the git directory.

**Rationale:** `git rev-parse --git-dir` is worktree-safe (resolves to `<main>/.git/worktrees/<name>/` in a linked worktree, `.git/` in a regular checkout). The file is never committed, invisible to `git status`, and cleaned up automatically when the worktree is removed. No PR-number keying needed — the hash itself is the identity (different PRs have different text = different hashes; if two PRs happen to have identical text, the review result is identical too).

### D3: When the cache invalidates

**Decision:** Natural invalidation on hash mismatch — no explicit clear needed. The hook re-fetches the PR title + body from GitHub on every push (`gh pr view`), recomputes the hash, and compares. If `gh pr edit` changed the body between pushes, the hash won't match and the review fires.

**Rationale:** Simpler than tracking baseline SHAs or commit ranges. The hook already fetches the PR body for the `PR_BODY_HAS_ALL_SHAS` fast-path; reusing that fetch adds zero API cost.

### D4: Scope boundary — project-side only

**Decision:** Cache only the project-side pre-push `prTextHygieneReason` path. The devshop-side squash-hygiene check (`DEVSHOP_HYGIENE_SURFACE=squash` at `/ak-merge-devshop` Phase 0.4.5) is not cached — it runs once per merge on fresh content.

**Rationale:** The devshop squash path fires exactly once (at merge time) and always on newly composed text. Caching it would save zero seconds and add dead code.

---

## In scope

1. **Hash-cache logic in `kit/hooks/pre-push.sh` Check 2** — after the adversarial review passes (line ~204), compute SHA-256 of `$PR_TITLE$PR_BODY` and write it to `$(git rev-parse --git-dir)/pr-hygiene-hash`. Before invoking the adversarial review (line ~183), re-fetch the PR title and body (reuse the existing `gh pr view` fetch already done for the SHA-enumeration fast-path), compute the hash, compare against the stored hash, and skip the LLM call if they match.

2. **Bats tests** exercising the cache hit (skip LLM), cache miss (re-fire LLM), and first-push (no cache file) paths.

3. **Doc update** to `kit/docs/guide/hooks.md` — add the hash-cache short-circuit to the Check 2 description (the "PR text hygiene" row in the check table and the § 3 prose block).

4. **Close the `kit/TODOS.md` entry** that tracks this issue.

## Out of scope

- Devshop-side squash-hygiene caching (D4 — fires once per merge, no savings).
- Explicit cache-clear command or hook (D3 — natural invalidation on mismatch).
- Caching the `dirtyPushReason` or other pre-push adversarial reviews.
- Changes to `adversarial-review.sh` itself.

## Files to create/modify

| File | Action | What changes |
|---|---|---|
| `kit/hooks/pre-push.sh` | Modify | ~10 lines: hash-cache read before the adversarial call, hash-cache write after a successful review. Reuse the `PR_TITLE` already fetched by adversarial-review.sh — but the pre-push script itself needs the title+body to compute the hash BEFORE calling adversarial-review.sh. Fetch `PR_TITLE` and `PR_BODY` from `gh pr view` in Check 2 (before the adversarial call), use those for both the SHA-enumeration fast-path AND the hash-cache check. The adversarial engine re-fetches internally (it doesn't accept piped-in data) — that's a double-fetch, but `gh pr view` is cached by GitHub's HTTP layer and costs <100ms; acceptable. |
| `kit/tests/util-pre-push.bats` | Modify | Add ~4 test cases for hash-cache behavior. |
| `kit/docs/guide/hooks.md` | Modify | Add hash-cache short-circuit mention to the PR text hygiene description. |
| `kit/TODOS.md` | Modify | Delete the `prTextHygiene pre-push hook re-evaluates on every push` entry. |

## Data flow (modified Check 2)

Current flow (lines 117–206 of `pre-push.sh`):

```
PR exists? → trivial-prefix short-circuit? → SHA-enumeration fast-path (fetches PR_BODY)?
  → adversarial-review.sh prTextHygieneReason (fetches PR_TITLE + PR_BODY internally)
```

New flow:

```
PR exists? → trivial-prefix short-circuit? → fetch PR_TITLE + PR_BODY from gh
  → SHA-enumeration fast-path (uses already-fetched PR_BODY)?
  → hash-cache check: compute hash, compare to stored → match? skip LLM
  → adversarial-review.sh prTextHygieneReason (re-fetches internally, ~100ms)
  → on PASS: write hash to cache file
```

The fetch of `PR_TITLE` and `PR_BODY` is lifted to just after the trivial-prefix short-circuit so both the SHA-enumeration fast-path and the hash-cache check can use it. This replaces the current `gh pr view "$PR" --json body --jq '.body'` call at line 161 with a broader `gh pr view "$PR" --json title,body` that captures both fields.

## Implementation sketch

Insert point 1 — Fetch PR text (replaces current body-only fetch at line 161):

```bash
# Fetch PR title + body for SHA-enumeration fast-path AND hash-cache check.
PR_DATA=$(gh pr view "$PR" --json title,body 2>/dev/null || echo "{}")
PR_TITLE=$(echo "$PR_DATA" | jq -r '.title // "(no title)"')
PR_BODY=$(echo "$PR_DATA" | jq -r '.body // ""')
```

Insert point 2 — Hash-cache check (after SHA-enumeration fast-path, before adversarial call):

```bash
# Hash-cache: skip LLM if PR text unchanged since last successful review.
HASH_FILE="$(git rev-parse --git-dir)/pr-hygiene-hash"
CURRENT_HASH=$(printf '%s%s' "$PR_TITLE" "$PR_BODY" | sha256sum | cut -d' ' -f1)
if [ -f "$HASH_FILE" ] && [ "$(cat "$HASH_FILE")" = "$CURRENT_HASH" ]; then
  # PR text unchanged since last successful review — skip LLM call.
  true  # fall through to exit 0 (or next check)
elif ...existing adversarial review block...; then
  ...existing failure handling...
fi
```

Insert point 3 — Write hash on success (after adversarial review passes):

```bash
# Cache successful review hash for future short-circuit.
printf '%s' "$CURRENT_HASH" > "$HASH_FILE"
```

## Tests

All tests in `kit/tests/util-pre-push.bats`, following existing conventions (setup with `setup_branch_with_commits`, `gh_stub_with_pr_body`, `mock_adversarial_review`).

### T1: First push — no cache file, adversarial fires, hash written on PASS

Setup: non-trivial commit, PR body without all SHAs, no existing hash file.
Expect: adversarial review fires (PASS mock), push succeeds, hash file exists in `$(git rev-parse --git-dir)/pr-hygiene-hash`.

### T2: Second push — unchanged PR text, cache hit, adversarial skipped

Setup: same as T1 but pre-write the matching hash file before the push.
Expect: push succeeds without adversarial review firing (mock set to FAIL — if it fired, push would fail).

### T3: PR text changed — cache miss, adversarial fires

Setup: hash file contains a stale hash (from different PR text), PR body has new content.
Expect: adversarial review fires (FAIL mock), push blocked with hygiene gate message.

### T4: First push — adversarial FAIL, hash NOT written

Setup: non-trivial commit, adversarial review fails.
Expect: push blocked, no hash file created.

## Task order

| # | Task | Depends on | Files |
|---|---|---|---|
| 1 | Add hash-cache logic to `pre-push.sh` | — | `kit/hooks/pre-push.sh` |
| 2 | Bats tests for hash-cache behavior | Task 1 | `kit/tests/util-pre-push.bats` |
| 3 | Doc update + TODOS closure | Task 1 | `kit/docs/guide/hooks.md`, `kit/TODOS.md` |

Tasks 2 and 3 depend on Task 1 (the code change) but are independent of each other — they can be implemented in the same commit if the change is small enough, or in separate atomic commits.

## Gotchas

1. **Double `gh pr view` fetch.** The pre-push script fetches PR title+body for the hash-cache check, and then `adversarial-review.sh` fetches the same data again internally. This is intentional — `adversarial-review.sh` is a shared engine that doesn't accept pre-fetched data, and changing its interface would be a larger refactor for ~100ms of savings. GitHub's HTTP caching makes the second fetch near-instant.

2. **`jq` dependency.** The hash-cache logic uses `jq` to parse `gh pr view` JSON output. This is already a dependency — the SHA-enumeration fast-path (and `adversarial-review.sh` itself) already use `jq`. No new dependency.

3. **`sha256sum` availability.** `sha256sum` is part of GNU coreutils, available on all Linux systems (including the devcontainer). macOS ships `shasum -a 256` instead — but the devshop runs exclusively in devcontainers (Linux), and project-side pre-push hooks also run in the devcontainer. No portability concern.

4. **Hash file in linked worktrees.** `git rev-parse --git-dir` in a linked worktree returns `<main>/.git/worktrees/<name>/`, not `<main>/.git/`. The hash file lands in the worktree-specific git dir, which is correct — different worktrees may have different PRs with different text. Automatically cleaned up when the worktree is removed (`git worktree remove` deletes the entire `<main>/.git/worktrees/<name>/` directory).

5. **The `PR_BODY` fetch for SHA-enumeration fast-path moves.** Currently, `PR_BODY` is fetched conditionally inside the `if [ "$ANY_COMMIT" = "true" ] && [ "$ALL_TRIVIAL" = "false" ]` block (line 161). The refactor lifts the fetch to just after that condition check, and adds `PR_TITLE` to the same call. The SHA-enumeration fast-path code that uses `PR_BODY` is unchanged in logic — only the fetch location moves. The `gh_stub_with_pr_body` test helper already stubs both `gh pr list` and `gh pr view` responses, so existing tests continue to work.

6. **Empty PR body edge case.** `printf '%s%s' "$PR_TITLE" ""` produces just the title string. The hash is still deterministic. An empty body that gets filled on the next push will produce a different hash, correctly invalidating the cache.
