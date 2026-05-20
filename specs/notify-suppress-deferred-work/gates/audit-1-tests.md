# Tests review — audit 1

Range: `origin/main..HEAD` (3 commits: `fd271f3`, `3fbde1f`, `6e48f12`)

## Coverage map (Section A)

| Source change                                                                                                                      | Test surface                                                                                     | Verdict                                                                                                                                                                                                                    |
| ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kit/scripts/notify/claude-done` (fd271f3 — suppression logic, 36 new lines)                                                       | `kit/tests/util-notify-claude.bats` (+8 cases under "Deferred-work suppression")                 | Paired — covers ScheduleWakeup / run_in_background Bash / CronCreate suppress paths, plain-text fall-through, foreground-bash no-suppress, last-turn-only semantics, prior-pending cancel, missing-transcript fall-through |
| `kit/scripts/commit-hooks/check-docs-coverage-devshop.sh` (3fbde1f — new `kit/scripts/notify/*` case branch + catch-all narrowing) | `kit/tests/guard-docs-coverage-devshop.bats` (+3 cases under "Surface: kit/scripts/notify/\*\*") | Paired — BLOCK without `notifications.md`, PASS with `notifications.md`, BLOCK with only generic `workflow.md` (proves narrow-surface mapping wins over catch-all)                                                         |
| `kit/TODOS.md` (6e48f12 — TODO entry only)                                                                                         | n/a — docs-only change, no test surface required                                                 | OK                                                                                                                                                                                                                         |

Both source changes have matching `.bats` coverage exercising the new behavior — not just file-pairing.

## Findings

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/util-notify-claude.bats:134-142`
**What**: The suppression rubric in `claude-done` (line 35) accepts both `Bash` AND `Agent` tools with `run_in_background: true`, but only `Bash` is tested. `Agent` with `run_in_background:true` is a documented suppression path (per the script comment and the commit message) with zero coverage.
**Why**: A future refactor that narrows the jq predicate (e.g. accidentally drops `.name == "Agent"` from the `or` chain) would silently regress Agent-background suppression with no test signal. Operators dispatching long-running subagents in the background would start getting stale "Task finished" pings.
**Fix**: Add one bats case mirroring the `run_in_background Bash` case but with `"name":"Agent"` in the tool_use payload — assert `[ ! -f "$CLAUDE_NOTIFY_PID_FILE" ]`.

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/util-notify-claude.bats:216-225`
**What**: The script's `[ -r "$transcript" ]` guard (line 29 of claude-done) has a missing branch: `transcript_path` present in JSON but the file is unreadable / missing. The "missing transcript_path falls through to schedule" test only covers the JSON-key-absent case (`<<<'{}'`), not the "key present, file unreadable" case.
**Why**: The two paths are functionally similar today (both fall through to schedule), but they go through different early-exit logic. A future change that, e.g., starts logging an error or short-circuiting on unreadable transcripts could regress one path silently. Minor gap; the load-bearing happy/sad paths are covered.
**Fix**: Add a one-liner case: `run bash "$DONE_SCRIPT" <<<'{"transcript_path":"/does/not/exist.jsonl"}'` → `assert_success` + `[ -f "$CLAUDE_NOTIFY_PID_FILE" ]`.

## Section B — Test quality

No findings. Assertions are concrete (file-presence, exit status, `grep -q` on captured stub args). Tests exercise the real bash script with stubbed `curl` and real `jq` — no mocked internals, no shape-only assertions. The "last assistant turn only" test (line 180) covers the multi-turn boundary condition correctly. The "suppression cancels prior pending ping" test (line 197) covers the cross-hook interaction (Request → Done) with a real PID dead/zombie assertion via `_dead_or_zombie`. Cancellation tests use a long `CLAUDE_NOTIFY_DELAY=5` so the assertion isn't a race. Bypass-comment escape hatch doesn't apply (no shape-only assertions present).

`guard-docs-coverage-devshop.bats`: the three new cases prove ordering-correctness (narrow `kit/scripts/notify/*` case branch fires before the catch-all `kit/scripts/*.sh|kit/scripts/sync/*`) by staging a `workflow.md` doc and asserting BLOCK with `guide/notifications.md` in the output — strong narrow-surface coverage.

No skipped tests, no `.only`, no `.skip` patterns introduced by the diff (verified via `grep -nE '^\+.*\b(test|describe|it)\.(skip|only)\b'`).

## Section C — Bypass trailer audit

Range scanned for `Tests-Coverage-Bypass:` trailers via `git log --format='%H%n%B%n---' origin/main..HEAD | grep -i 'tests-coverage-bypass'` — zero hits. The bypass-trailer mechanic is PR-C migration-pending per the skill's forward-compatibility note; zero rows in this audit is legitimate.

(A `Docs-Coverage-Bypass:` trailer exists on `fd271f3` but that's the docs orchestrator's concern, not tests.)

## Summary

Tests look solid. Two low-severity branch-coverage gaps noted (Agent-background suppression, unreadable-transcript fall-through) — neither is load-bearing or shippable-blocker; both are one-liner additions if the operator wants belt-and-braces coverage of every branch in the new suppression block.

`high=0 medium=0 low=2`
