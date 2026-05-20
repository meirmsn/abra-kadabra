# Review — supabase-stop-on-devcontainer-close

## Audit 1: manual (2026-05-20)

<!-- audited-at: d394e3404df39240ad40a94303ed684605bb6fdc -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=1 low=2

### Docs findings

### [domain: docs] [section: B] [severity: medium]
**File**: kit/docs/guide/ops.md:177 (and the mirrored block at kit/docs/guide/local-supabase-compose-isolation.md:113)
**What**: The new "Stop variants — when you need to wipe state" code blocks cite the supabase-runner container as `<project>-supabase-runner-1` (e.g. `docker exec -it <project>-supabase-runner-1 supabase stop --no-backup`). The canonical container-name pattern documented everywhere else in this very file (and in `local-supabase-compose-isolation.md § Debugging tree`) is `<project>_devcontainer-supabase-runner-1` — note the `_devcontainer` middle segment + the underscore-then-dash separator shape that docker compose v2 produces from `--project-name <project>_devcontainer`. Five existing prose+code citations in `local-supabase-compose-isolation.md` (lines 220, 260, 271, 274, 289) all use the `<project>_devcontainer-supabase-runner-1` shape; the two new code blocks added by this commit drop the `_devcontainer` segment entirely.
**Why**: Load-bearing wipe-state recovery instructions that won't work as written. An operator copy-pasting `docker exec -it <project>-supabase-runner-1 supabase stop --no-backup` (substituting their project's slug for `<project>`) gets `Error: No such container: <slug>-supabase-runner-1` — the new instructions are the only documented path for the `--no-backup` / `--all` variants and they fail at the first step. Same shape on the mirrored block in `local-supabase-compose-isolation.md § Container lifecycle`. The auto-stop hook the commit ships is the load-bearing happy path; these wipe-state variants are the load-bearing escape hatch — both need to land or the escape hatch is broken until someone notices.
**Fix**: Replace `<project>-supabase-runner-1` with `<project>_devcontainer-supabase-runner-1` in both new code blocks (ops.md § Stop variants + local-supabase-compose-isolation.md § Container lifecycle's wipe-state block). Match the shape already used by the five canonical citations in the Debugging tree section so naming stays consistent across the doc set.

No Docs-Coverage-Bypass trailers in range.

### Tests findings

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/template-compose-isolation.bats:103-115`
**What**: The new bats tests pin SIGTERM/SIGINT traps + `spawn("supabase", ["stop"])` + `stop_grace_period: 30s`, but do not pin the 25s force-exit timer in `cmd-relay.mjs` (`setTimeout(..., 25_000)` → `process.exit(1)`). The 25s budget is the explicit coupling between the relay's internal deadline and compose's `stop_grace_period: 30s` ("leave 5s slack" per code + doc comments). If someone bumps grace to 20s without touching the relay, or removes the safeguard timeout entirely, no test catches the drift — the failure surfaces as docker SIGKILL'ing mid-teardown under load, which is exactly the symptom this guard prevents.
**Why**: Silent regression in the documented 25↔30 coupling. The shape-of-test that fits is the same grep-pin pattern already in this file.
**Fix**: One-liner in the existing SIGTERM/SIGINT bats test (or a sibling test):

```bash
run grep -q '25_000' "$f"
assert_success
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

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-20)

<!-- audited-at: 86536e3b3f4dc7d08c6ff27bda37e5dfc1e46c30 -->
<!-- range: d394e3404df39240ad40a94303ed684605bb6fdc..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none)

Audit 1's medium docs finding closed: both `kit/docs/guide/ops.md` and `kit/docs/guide/local-supabase-compose-isolation.md` now use `<project>_devcontainer-supabase-runner-1` in the Stop variants code blocks. Repo-wide grep for the stale `<project>-supabase-runner-1` (without `_devcontainer`) pattern returns zero hits.

### Tests findings

- (none)

Audit 1's two low tests findings closed by commit `86536e3`:
- 25s timer pin — `run grep -q '25_000' "$f"` added to the SIGTERM/SIGINT test.
- Re-entrancy guard pin — `run grep -q 'if (shuttingDown) return' "$f"` added to the same test.

### Bypass trailer audit

- (none)
