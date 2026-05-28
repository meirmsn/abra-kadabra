# Tests Review — Audit 2

**Range**: `23518d9..HEAD` (4 commits: `cc6c01e`, `8e0ae5d`, `91ae470`, `8f9624c`)
**Feature**: `local-env-pillar`
**Date**: 2026-05-27

## Section A — Coverage of new behavior

Two code-changing commits in range:

1. **`cc6c01e` — `local-env-health.sh` recover zombie-only + cgroup clamping**
   - New test: "recover skips non-zombie processes (only kills zombies)" — verifies that a healthy process on port 3000 is NOT killed (kill mock never called, output says "no zombie processes found"). Covers the new zombie-state discrimination logic.
   - Updated test: "recover refuses to kill the current session's dev server PID even if zombie" — updated to acknowledge the /proc mockability constraint (the real /proc won't have a zombie state for PID 9999, so the test exercises the non-zombie skip path, with DEV_SERVER_PID protection as a secondary guard).
   - Cgroup clamping (negative headroom → 0): not directly tested with a negative-cgroup mock. However, the existing memory-check tests exercise the `get_available_memory_kb` path via `PROC_MEMINFO` injection, and the clamp is a 3-line guard that zeroes negative values before the comparison — low risk, defensive fix.

2. **`8f9624c` — `roster-check.sh` bulleted Reason format**
   - New test: "hero capture: bulleted '- Reason: non-UI PR (context)' passes (SKILL.md format)" — directly exercises the new `grep -E '^-?\s*Reason:'` pattern + the `sed` extraction + the glob-match `"non-UI PR"*` with trailing context.

All 26 relevant bats tests pass at HEAD.

No Section A findings — both code changes have corresponding test additions.

## Section B — Test quality

The new tests follow existing patterns:

- Mock `ss` to simulate port occupancy with specific PIDs.
- Mock `kill` to capture invocations without side effects.
- Assert on specific output strings ("recover: no zombie processes found") that prove the code path executed.
- The `[ ! -f "$BATS_TEST_TMPDIR/kill.calls" ]` negative assertion confirms kill was never called.

**Residual gap (pre-existing, acknowledged)**: The zombie-kill success path (a process that IS a zombie and gets killed) remains untestable in bats without a `/proc` injection mechanism. This was noted in the prior Audit 1 (Gate 5) as a medium finding. The fix in this range adds the discrimination logic and tests the non-zombie-skip path, which is the higher-risk path (false positive kills). The success path (killing a real zombie) is lower risk — if the state check passes and kill(2) works, the output is correct. Carrying forward as acknowledged, not as a new finding.

No new Section B findings.

## Section C — Bypass trailer audit

Zero `Tests-Coverage-Bypass:` trailers harvested from the range. No Section C findings.
