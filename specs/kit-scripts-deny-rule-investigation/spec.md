# kit/scripts/** deny rule — investigation findings

## Problem

`settings.json` has four deny patterns for kit/scripts/:

```
Edit(kit/scripts/**)           — relative
Write(kit/scripts/**)          — relative
Edit(/devshop/kit/scripts/**)  — absolute
Write(/devshop/kit/scripts/**) — absolute
```

Enforcement is inconsistent: during the `feat/phase3-blocked-halt` session (2026-05-20), the agent edited `kit/scripts/adversarial-review.sh` four times with no friction, then every subsequent Edit attempt to the same file was denied.

## Root cause

**Worktree paths escape both relative and absolute deny patterns.**

When the agent works in a git worktree at `/devshop/.worktrees/<topic>/`, file paths are:

- `/devshop/.worktrees/<topic>/kit/scripts/adversarial-review.sh` (full path)
- Or `kit/scripts/adversarial-review.sh` (relative from worktree cwd)

Pattern matching results (confirmed via fnmatch simulation):

| Path form | `kit/scripts/**` (relative, resolved from cwd=/devshop) | `/devshop/kit/scripts/**` (absolute) |
|---|---|---|
| `/devshop/kit/scripts/adversarial-review.sh` (canonical) | MATCH | MATCH |
| `/devshop/.worktrees/<topic>/kit/scripts/adversarial-review.sh` (worktree absolute) | NO MATCH | NO MATCH |
| `kit/scripts/adversarial-review.sh` (relative from worktree cwd) | MATCH (resolves against worktree cwd) | N/A |

**The mid-session flip**: early Edit calls used the full worktree absolute path (no deny match — succeeds). Later calls switched to relative paths from the agent's mental model (matches the relative deny pattern — blocked). The agent doesn't control which path form Claude Code normalizes to internally, causing the inconsistency.

## Related issue

TODOS.md documents a separate but related Claude Code limitation: absolute-path deny rules don't fire when cwd doesn't match the target's `additionalDirectories` root (e.g., from cwd=/workspace, `/devshop/...` absolute denies don't fire). Filesystem locks (Layer 2) mitigate this. Filed as blocked-upstream.

## Decision: Option (B) — narrow to canonical-path-only deny

**Remove the relative patterns. Keep the absolute patterns.**

Rationale:
1. The relative `kit/scripts/**` patterns cause the mid-session inconsistency — they match unpredictably depending on whether the Edit tool receives a relative vs absolute path
2. The absolute `/devshop/kit/scripts/**` patterns protect the canonical copy deterministically (works when cwd=/devshop, which is the devshop session cwd)
3. Worktree copies should be editable — they're development copies, and feature work regularly modifies scripts like `adversarial-review.sh`, `commit-guard.sh`
4. Filesystem locks (Layer 2) are the real protection for the canonical copy — root:root ownership prevents node from writing regardless of deny rules
5. Commit guards and pre-commit hooks fire identically in worktrees, so no weakening of the guard gauntlet
6. The inconsistent behavior (sometimes blocked, sometimes not) is worse for security posture than consistently allowing worktree edits — it trains the agent to try workarounds instead of using the `/tmp + sudo install` recipe on the first denial

**What this means in practice:**
- Canonical `/devshop/kit/scripts/**` — denied (Layer 1 deny + Layer 2 filesystem lock)
- Worktree `.worktrees/<topic>/kit/scripts/**` — allowed (intentional, development copies)
- The `/tmp + sudo install` recipe is only needed for the canonical copy

## Changes

1. **settings.json** — remove `Edit(kit/scripts/**)` + `Write(kit/scripts/**)` (relative patterns, lines 79-80)
2. **security.md § Security-Critical Files** — add worktree-awareness note
3. **security.md § Guard Script Editing** — document worktree-aware posture
4. **CLAUDE.md § Known Footguns § Permission-denied paths** — add `kit/scripts/**` to enumerated list with worktree caveat
5. **ROADMAP.md** — close the entry (delete)
6. **TODOS.md line 315** — add cross-reference to this fix

## Task order

1. Write spec (this file)
2. Prepare settings.json change for operator
3. Update security.md
4. Update CLAUDE.md Known Footguns
5. Close ROADMAP entry
6. Commit
