### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/template-compose-isolation.bats:103-115`
**What**: The new bats tests pin SIGTERM/SIGINT traps + `spawn("supabase", ["stop"])` + `stop_grace_period: 30s`, but do not pin the 25s force-exit timer in `cmd-relay.mjs` (`setTimeout(..., 25_000)` → `process.exit(1)`). The 25s budget is the explicit coupling between the relay's internal deadline and compose's `stop_grace_period: 30s` ("leave 5s slack" per code + doc comments). If someone bumps grace to 20s without touching the relay, or removes the safeguard timeout entirely, no test catches the drift — the failure surfaces as docker SIGKILL'ing mid-teardown under load, which is exactly the symptom this guard prevents.
**Why**: Silent regression in the documented 25↔30 coupling. The shape-of-test that fits is the same grep-pin pattern already in this file.
**Fix**: One-liner in the existing SIGTERM/SIGINT bats test (or a sibling test):

```bash
run grep -q '25_000' "$f"
assert_success
```

Optional companion that asserts the coupling more directly:

```bash
@test "compose-isolation: cmd-relay 25s budget leaves slack under compose's 30s grace_period" {
  run grep -q 'setTimeout.*25_000' "$DC/supabase-runner/cmd-relay.mjs"
  assert_success
  run grep -E '^    stop_grace_period: 30s$' "$DC/compose.yml"
  assert_success
}
```

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/template-compose-isolation.bats:103-115`
**What**: The `shuttingDown` re-entrancy guard in `cmd-relay.mjs` (the early-return on second-signal entry) is untested. Without it, a SIGTERM-then-SIGINT (or vice versa) double-spawns `supabase stop`, racing two teardowns of the same sibling stack.
**Why**: Rare path, but the guard exists for a reason and is cheap to pin. Removal of `if (shuttingDown) return;` would go uncaught by the suite.
**Fix**: Add to the existing SIGTERM/SIGINT bats test:

```bash
run grep -q 'if (shuttingDown) return' "$f"
assert_success
```

---

**Section B (test quality)**: no findings. Tests are structural `grep -q` pins against template files — appropriate shape for a devshop bats spec covering template invariants. The file header comment ("Pure file-content checks; no real container needed") names the shape-only-without-user-visible-output rationale. No `.only` / `.skip`, no Playwright / WebKit / `routeWebSocket`, no LLM-boundary wrappers, no realtime subscriptions — the specialized Section B checks don't apply to this diff.

**Section C (bypass trailers)**: zero `Tests-Coverage-Bypass:` trailers in the range. Nothing to audit.
