## Gate 6: /review

- Result: findings (2) pending

### Finding 1 — `recover` kills ALL processes on monitored ports, not just zombies (MEDIUM)

**File:** `kit/scripts/preship/local-env-health.sh:198-239`

The `cmd_recover()` function iterates all PIDs on monitored ports (3000, 3001, 54321, 54322) and `kill -9`s every process it finds, except the one protected by `DEV_SERVER_PID`. The only guard is the dev-server PID check. This means:

- Healthy Supabase processes on ports 54321/54322 will be killed during recovery.
- A sibling project's dev server on port 3000 would be killed.
- The success message says "zombie processes killed successfully" (line 233) but the killed processes are not necessarily zombies — the zombie check only exists in `cmd_check()` (lines 170-175), not in `cmd_recover()`.

The spec (D4) says: "kill -9 zombies on ports 3000/3001/54321/54322 after identifying their PIDs + checking they're not the current session's dev server." The intent is to kill zombies specifically, but the implementation kills all processes on those ports.

Additionally, `DEV_SERVER_PID` is never set by the SKILL.md Phase 3.0 wiring (the `bash local-env-health.sh recover` call at line 860 doesn't pass this env var), so in practice the dev-server protection is inert unless the caller explicitly exports it.

**Severity:** MEDIUM — in the normal flow, `recover` only runs after `check` fails, and a failing `check` likely indicates genuinely unhealthy processes. But killing healthy Supabase containers on 54321/54322 would make the situation worse, not better. The misleading "zombie" message is a cosmetic/correctness concern.

### Finding 2 — Negative cgroup headroom produces misleading diagnostic message (LOW)

**File:** `kit/scripts/preship/local-env-health.sh:104-105, 156-159`

If cgroup `memory.current` exceeds `memory.max` (possible with memory overcommit or accounting lag), the arithmetic at line 105 produces a negative `cgroup_headroom_kb`. This flows through to the failure message at line 158-159: `"-600MB available, need 1024MB"`. The negative sign is confusing to the operator. The check itself works correctly (negative < threshold), so this is purely a message quality issue.

**Severity:** LOW — the check is correct, only the diagnostic message is misleading in an edge case that is unlikely in practice.

---

No findings in:
- `kit/scripts/preship/roster-check.sh` — scope-variable parsing matches SKILL.md format, expected-roster derivation mirrors the original inline code exactly, SKIP.md validation is correctly case-sensitive with known-valid allowlist, `set -euo pipefail` interacts safely with the `[ -n "$VAR" ] && ...` pattern.
- `kit/scripts/preship/check-llm-mediated-na.sh` — awk is confirmed mawk-portable (no `\b`), `($|[^a-z-])` anchoring correctly rejects `/qa-walk` and matches `/qa` at end-of-line, verified against mawk 1.3.4 explicitly.
- `.claude/skills/devshop/build/SKILL.md` changes — script calls pass correct arguments, retry-on-failure pattern is sound, inline code fully replaced (no leftover duplicates).
- `kit/docs/guide/migrations.md` — all 4 FK rollback patterns are technically correct: Pattern 1 (`IF EXISTS` guard on child table drop), Pattern 2 (migration-number suffix), Pattern 3 (`CASCADE` for policies), Pattern 4 (`DO $$ ... IF EXISTS` for conditional `ALTER TABLE`).

## Dismissals

None
