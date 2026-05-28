<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: local-env-pillar -->
<!-- date: 2026-05-27 -->

# Spec: local-env-pillar

**Sources:**

- `kit/ROADMAP.md` § Local environment as the single verification surface — primary scope (3 tracks: A health check, B roster enforcement, C migration rollback FK convention)
- `kit/TODOS.md` line 139 § Codify regression coverage for `/ak-build` Phase 3→4 LLM-mediated-`n/a` awk halt grep — Track B closes this
- `.claude/skills/devshop/build/SKILL.md` § Phase 3.0 preflight + § 3.3 concatenation — wiring targets for Tracks A and B
- `.claude/skills/ak-pre-ship/SKILL.md` § Capture hero screenshots — SKIP.md hardening target
- `kit/scripts/preship/supabase-bootstrap.sh` — existing preflight helper shape (Track A mirrors this pattern)
- `kit/scripts/preship/path-classifier.sh` — existing script pattern for Track B
- `specs/cheap-test-gates-local/spec.md` — style/structure reference (most recent devshop spec)
- `kit/docs/guide/migrations.md` — Track C target doc

**One-liner:** Three deterministic scripts that close the class of silent gate skip exposed by home-os PR #36: local-env health check before browse/QA/screenshot operations, gate roster enforcement at Phase 3 boundaries, and migration rollback FK convention.

---

## Product update

### Headline (user-facing)

Local environment health checks now run automatically before every browse, QA, and screenshot operation — broken environments halt the pipeline instead of silently skipping gates.

### Detail (team-facing)

Three coordinated fixes: (A) `local-env-health.sh` preflight script verifying dev server, Supabase, memory, and zombie processes with auto-recovery; (B) `roster-check.sh` + `check-llm-mediated-na.sh` deterministic scripts replacing prose-level gate enforcement in Phase 3; (C) migration rollback FK convention documented in `kit/docs/guide/migrations.md`. Closes the home-os PR #36 failure class where OOM + zombie processes caused silent gate skips and 5 CI fix cycles.

---

## Decisions (resolved at spec time)

Seven `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without re-asking.

### D1: Health check script location

**Decision:** `kit/scripts/preship/local-env-health.sh` with subcommands `check` and `recover`. Called from Phase 3.0 preflight.

**Rationale:** Mirrors `supabase-bootstrap.sh` shape (preflight helper script). No new wiring surface needed — plugs into the existing Phase 3.0 preflight flow which is already deterministic and enforced.

### D2: Health check scope

**Decision:** 4 checks: (1) dev server reachable on expected port, (2) Supabase healthy via `supabase-bootstrap.sh status`, (3) memory headroom >= 1GB free, (4) no zombie processes on common ports (3000, 3001, 54321).

**Rationale:** Roadmap's list verbatim. Memory threshold at 1GB (Turbopack's actual peak on a small project is ~800MB). Each check is <1s so total is <3s.

### D3: Roster check script location

**Decision:** `kit/scripts/preship/roster-check.sh` — takes preflight sink path + gates dir, computes expected roster from scope vars, returns exit 1 on missing gates. Also extracts the Phase 3→4 `n/a` awk check into `kit/scripts/preship/check-llm-mediated-na.sh` — closes `kit/TODOS.md` line 139.

**Rationale:** Script, not prose. Called at §3.3 boundary. Moving the awk to a script makes it a first-class testable surface with mawk-portable syntax, instead of orchestrator-prompt prose that can silently regress.

### D4: Auto-recovery behavior

**Decision:** Yes — `kill -9` zombies on ports 3000/3001/54321/54322 after identifying their PIDs + checking they're not the current session's dev server.

**Rationale:** Recovery is cheap and safe. If it fails, the script reports diagnostics and halts.

### D5: Cache/debounce

**Decision:** No — checks run in <3s total (4 cheap operations). Cache adds complexity for negligible savings at this speed.

**Rationale:** Roadmap suggested "skip if last check was <60s ago" but with <3s runtime the debounce is premature.

### D6: SKIP.md hardening

**Decision:** Phase 3.1b hero-capture code path requires `SKIP.md` to contain a machine-parseable `Reason:` line matching a known-valid skip class (`non-UI PR`, `Chromium unavailable`). Any other reason → the roster check rejects it as an unknown skip.

**Rationale:** Makes the SKIP.md escape hatch friction-ful: you can still write it, but the reason gets validated.

### D7: Migration rollback FK convention (Track C)

**Decision:** Ships as a doc addition to `kit/docs/guide/migrations.md` in the same feature branch.

**Rationale:** Straightforward, ~30 min, no decision surface. Patterns from the roadmap entry verbatim.

---

<!-- /ak-spec (Phase 1) expanded the file from here. The Product update +
     Decisions sections above are user-approved and verbatim. -->

## In scope

Concrete bullets, grouped by track. Each track is independent at the file
level but ships on one branch as a cohesive fix for the home-os PR #36
failure class.

**Track A — `local-env-health.sh` preflight script**

- New helper `kit/scripts/preship/local-env-health.sh` with two subcommands:
  `check` and `recover`.
- `check` verifies 4 conditions (D2): (1) dev server reachable on expected
  port, (2) Supabase healthy via `supabase-bootstrap.sh status`, (3) free
  memory >= 1GB, (4) no zombie processes on ports 3000/3001/54321/54322.
- Each check is deterministic — exit codes, not prose. Exit 0 = all clear,
  exit 1 = one or more checks failed (stdout itemizes which).
- `recover` kills zombie processes on monitored ports after confirming they
  are not the current session's dev server (D4). Reports what was killed.
  Exit 0 = recovery succeeded or nothing to recover; exit 1 = recovery
  attempted but a process could not be killed.
- Total runtime < 3s (D5). No cache/debounce (D5).
- Called from Phase 3.0 preflight in `SKILL.md`, alongside the existing
  `supabase-bootstrap.sh up` call. On failure, preflight halts with
  diagnostics.

**Track B — Gate roster enforcement scripts**

Two new scripts:

- `kit/scripts/preship/roster-check.sh` — takes a preflight sink path and
  a gates directory, computes the expected gate roster from the sink's scope
  variables (same derivation as the inline code at `SKILL.md § 3.3.1`),
  diffs against produced gate sinks, and exits 1 on missing gates. Also
  validates hero capture (PNGs or SKIP.md present). This replaces the
  inline prose-level check with a first-class testable script.
- `kit/scripts/preship/check-llm-mediated-na.sh` — extracts the Phase 3 → 4
  awk block (SKILL.md lines 1360-1365) into a standalone script with
  mawk-portable syntax. Takes a `review.md` path, exits 0 if no forbidden
  `n/a` found, exits 1 if any LLM-mediated gate emitted bare `n/a`.
  Closes `kit/TODOS.md` line 139.

Track B also hardens SKIP.md validation (D6):

- `roster-check.sh` validates that `SKIP.md` (when present instead of hero
  PNGs) contains a `Reason:` line matching a known-valid skip class:
  `non-UI PR` or `Chromium unavailable`. Unknown reasons cause the roster
  check to reject the hero capture as incomplete.

**Track C — Migration rollback FK convention**

- New section in `kit/docs/guide/migrations.md`: `## Cross-migration FK
  rollback patterns`. Documents the 4 patterns from the roadmap entry:
  1. Later migration's FK child → earlier migration's rollback must
     `DROP TABLE IF EXISTS <child>` before dropping the parent.
  2. Enum rename-recreate uses migration-number-suffixed temp names
     (`_015`, not `_new`).
  3. `DROP TABLE CASCADE` handles policies — no explicit `DROP POLICY`
     needed.
  4. Guard `ALTER TABLE ... ALTER COLUMN` on tables that may not exist
     after earlier rollbacks ran.

**Doc + tracker updates**

- Wire Track A and Track B scripts into `SKILL.md` Phase 3.0 and Phase 3.3.
- Close `kit/TODOS.md` line 139 (LLM-mediated n/a awk test).
- Close `kit/ROADMAP.md` § "Local environment as the single verification
  surface" (mark `[SHIPPED]`).
- Update `kit/docs/guide/conventions.md` with cross-reference from the
  existing Local Pre-Push Test Gates section to the new health check.

## Out of scope

- **Runtime env health during gate execution** — Track A checks at
  preflight time only, not between gates. Mid-gate OOM is a separate
  concern.
- **Auto-restart of dev server** — `recover` kills zombies but does not
  start `pnpm dev`. Dev server lifecycle is owned by Playwright's
  `webServer` config or the operator.
- **Extending the roster check to project-specific custom gates** —
  the roster derivation mirrors `SKILL.md`'s hardcoded scope predicates.
  Custom gates are a future concern.

## Files to create/modify

### Scripts

| File | Action | Purpose |
|------|--------|---------|
| `kit/scripts/preship/local-env-health.sh` | create | Track A: 4-check health preflight with `check` and `recover` subcommands |
| `kit/scripts/preship/roster-check.sh` | create | Track B: expected-vs-produced gate roster diff + hero capture validation + SKIP.md reason validation |
| `kit/scripts/preship/check-llm-mediated-na.sh` | create | Track B: extracted mawk-portable awk for forbidden `n/a` detection on LLM-mediated gates |

### Skills

| File | Action | Purpose |
|------|--------|---------|
| `.claude/skills/devshop/build/SKILL.md` | modify | Wire `local-env-health.sh` into Phase 3.0 preflight; wire `roster-check.sh` + `check-llm-mediated-na.sh` into Phase 3.3 boundary (replacing inline code) |

### Docs

| File | Action | Purpose |
|------|--------|---------|
| `kit/docs/guide/migrations.md` | modify | Track C: add `## Cross-migration FK rollback patterns` section |
| `kit/docs/guide/conventions.md` | modify | Cross-reference from Local Pre-Push Test Gates to Track A health check |

### Trackers

| File | Action | Purpose |
|------|--------|---------|
| `kit/TODOS.md` | modify | Close line 139 (LLM-mediated n/a awk test) |
| `kit/ROADMAP.md` | modify | Mark "Local environment as the single verification surface" `[SHIPPED]` |

## Tests

All tests are bats, in `kit/tests/`.

| File | Action | What it covers |
|------|--------|----------------|
| `kit/tests/preship-local-env-health.bats` | create | Track A: (1) `check` exits 0 when all 4 conditions pass (mocked); (2) `check` exits 1 and itemizes failures when dev server unreachable; (3) `check` exits 1 on low memory (mocked `/proc/meminfo`); (4) `check` exits 1 on zombie processes (mocked `lsof`/`ss`); (5) `recover` kills identified zombies (mocked `kill`); (6) `recover` refuses to kill the current session's dev server PID; (7) Supabase status integration — calls `supabase-bootstrap.sh status` and maps responses |
| `kit/tests/preship-roster-check.bats` | create | Track B roster: (1) exits 0 when all expected sinks present; (2) exits 1 and lists missing gates on incomplete roster; (3) scope-conditional gates (UI-only gates absent on non-UI diff = ok); (4) hero capture: PNGs present = ok, SKIP.md with valid reason = ok, SKIP.md with unknown reason = fail, neither present = fail; (5) preflight sink parsing matches SKILL.md format |
| `kit/tests/util-check-llm-mediated-na.bats` | create | Track B awk extraction: (1) plain `n/a` on Gate 8 (design-review) — detected, exit 1 (mawk `\b` regression target); (2) `blocked (n/a per scope: ...)` on Gate 9 — NOT detected, exit 0 (scope-exempt shape); (3) non-LLM-mediated gate `n/a` (Gate 3) — NOT detected, exit 0 (carve-out preserved); (4) clean review.md with all gates `pass` — exit 0; (5) run with `mawk` explicitly to catch GNU-awk-only constructs |

## Dependencies

None. All three tracks use existing devshop infrastructure:

- `supabase-bootstrap.sh` (status subcommand) — already exists for Track A's Supabase health check.
- `kit/tests/helpers/setup` + `kit/tests/test_helper.bash` — existing bats harness.
- Standard utilities (`lsof` or `ss`, `awk`/`mawk`, `free`/`/proc/meminfo`, `kill`) — already available in the devcontainer.

No new npm packages, no new system tools.

## Task order

Seven tasks. Each is one atomic commit. Dependency-ordered so later tasks
build on earlier ones.

### T1 — `local-env-health.sh` + bats tests (~1.5 hr)

**What:** Create `kit/scripts/preship/local-env-health.sh` with `check` and
`recover` subcommands implementing the 4 health checks (D2) and zombie
auto-recovery (D4). Create `kit/tests/preship-local-env-health.bats` with
the 7 test cases listed in the Tests section.

**Dependencies:** none (pure new files).

**Commit:** `feat(preship): add local-env-health.sh preflight helper`

### T2 — `roster-check.sh` + bats tests (~1.5 hr)

**What:** Create `kit/scripts/preship/roster-check.sh` with the expected-
roster derivation (mirroring SKILL.md § 3.3.1's inline bash), gate-sink
existence check, hero capture validation, and SKIP.md reason validation (D6).
Create `kit/tests/preship-roster-check.bats` with the 5 test case groups.

**Dependencies:** none (pure new files; reads preflight sink format but does
not depend on Track A script existing).

**Commit:** `feat(preship): add roster-check.sh for gate completeness enforcement`

### T3 — `check-llm-mediated-na.sh` + bats tests (~45 min)

**What:** Create `kit/scripts/preship/check-llm-mediated-na.sh` extracting
the awk block from SKILL.md lines 1360-1365 into a standalone script with
mawk-portable syntax (no `\b` word boundaries — use `[^a-z-]` or
end-of-line anchors instead). Create
`kit/tests/util-check-llm-mediated-na.bats` with the 5 test cases including
explicit `mawk` invocation.

**Dependencies:** none (pure new files).

**Commit:** `feat(preship): extract LLM-mediated n/a check to standalone script`

### T4 — Wire scripts into SKILL.md (~45 min)

**What:** Modify `.claude/skills/devshop/build/SKILL.md`:
- Phase 3.0 preflight: add `local-env-health.sh check` call after the
  existing `supabase-bootstrap.sh up` call. On failure, call
  `local-env-health.sh recover` and retry once. If still failing, halt
  preflight with diagnostics.
- Phase 3.3 boundary: replace the inline roster-check bash (§ 3.3.1 Steps
  1-3) with a call to `roster-check.sh`. Replace the inline awk block
  (Rung 3, lines 1360-1379) with a call to `check-llm-mediated-na.sh`.

**Dependencies:** T1, T2, T3 (all three scripts must exist).

**Commit:** `feat(ak-build): wire local-env-health + roster-check + llm-na-check into Phase 3`

### T5 — SKIP.md validation hardening (~30 min)

**What:** Extend `roster-check.sh` (created in T2) to validate that when
`SKIP.md` is present instead of hero PNGs, it contains a `Reason:` line
matching one of the known-valid classes: `non-UI PR`, `Chromium unavailable`.
Add test cases to `preship-roster-check.bats` covering:
- Valid `Reason: non-UI PR` → accepted.
- Valid `Reason: Chromium unavailable` → accepted.
- Invalid `Reason: ran out of time` → rejected.
- Missing `Reason:` line → rejected.

Note: T5 extends T2's script rather than creating a new file, but is a
separate commit because the SKIP.md validation is a distinct concern (D6)
from the roster completeness check. If T2 naturally includes the SKIP.md
validation during implementation, T5 collapses into T2.

**Dependencies:** T2 (extends roster-check.sh).

**Commit:** `feat(preship): validate SKIP.md reason classes in roster check`

### T6 — Migration rollback FK convention (Track C) (~30 min)

**What:** Add `## Cross-migration FK rollback patterns` section to
`kit/docs/guide/migrations.md` documenting the 4 patterns from the roadmap
(D7). Place it after the existing `## Postgres enum extension` section.

**Dependencies:** none (pure doc addition).

**Commit:** `docs(migrations): add cross-migration FK rollback patterns`

### T7 — Doc updates + tracker closure (~30 min)

**What:**
- `kit/docs/guide/conventions.md`: add cross-reference from the Local
  Pre-Push Test Gates section noting that `local-env-health.sh` now runs
  at Phase 3.0 preflight alongside the Supabase bootstrap.
- `kit/TODOS.md` line 139: delete the LLM-mediated n/a awk test entry
  (closed by T3).
- `kit/ROADMAP.md` § "Local environment as the single verification
  surface": mark `[SHIPPED]` with branch reference.

**Dependencies:** T1-T6 (all substance must exist before closing trackers).

**Commit:** `docs(local-env-pillar): close tracker entries + update conventions`

## Gotchas

1. **`local-env-health.sh` must detect ports without `lsof` on minimal
   containers.** The devcontainer may not have `lsof` installed. Use `ss -tlnp`
   (from `iproute2`, always present) as the primary mechanism, with `lsof` as
   a fallback. Test both paths.

2. **Memory check must work inside Docker containers.** `/proc/meminfo`
   inside a container reports the HOST's total memory, not the container's
   limit. Use `MemAvailable` from `/proc/meminfo` which reflects the kernel's
   estimate of available memory. On cgroup-limited containers, cross-check
   against `/sys/fs/cgroup/memory.max` (cgroup v2) or
   `/sys/fs/cgroup/memory/memory.limit_in_bytes` (cgroup v1) when present.
   The 1GB threshold (D2) should be compared against the lesser of
   `MemAvailable` and cgroup headroom.

3. **The awk extraction (T3) MUST use mawk-compatible syntax.** The original
   inline awk at SKILL.md lines 1360-1365 was already patched for mawk
   portability (commit `3ed6e8b` replaced `\b` with `[^a-z-]`). The extracted
   script must preserve this — run the bats test with `mawk` explicitly.
   The devcontainer ships both `gawk` and `mawk`; `awk` resolves to one of
   them unpredictably.

4. **`roster-check.sh` must parse preflight sink format exactly.** The scope
   variables in `preflight.md` use `- TOUCHES_UI=` format (with leading
   `- ` bullet). The grep patterns must match this shape, not bare
   `TOUCHES_UI=`. Fixture files in bats tests must reproduce the exact format
   from SKILL.md § 3.0.

5. **The SKIP.md reason validation is case-sensitive and whitespace-sensitive.**
   The `Reason:` line in SKIP.md is written by SKILL.md § 3.1b with specific
   text. Match against the exact known strings. A `grep -i` would be too
   loose — `"Non-UI pr"` should not match if the codebase always writes
   `"non-UI PR"`.

6. **Wiring into SKILL.md (T4) replaces inline code, not just adds calls.**
   The existing inline roster-check bash at § 3.3.1 (Steps 1-3) and the
   inline awk block at Rung 3 are the canonical implementations today. After
   T4, the canonical implementation lives in the scripts; SKILL.md invokes
   them. The inline code should be replaced with the invocation, not left
   alongside it.

7. **Track C (T6) is a doc-only task with no code changes.** The pre-commit
   `check-docs-coverage-devshop.sh` hook will fire on the commit. The
   `docsReviewed` bypass flag needs to name the specific section added to
   `migrations.md`.

## Acceptance

**Done when:**

- All 3 bats test files pass: `bats kit/tests/preship-local-env-health.bats kit/tests/preship-roster-check.bats kit/tests/util-check-llm-mediated-na.bats`
- `local-env-health.sh check` exits 0 on a healthy devcontainer (manual smoke test).
- `local-env-health.sh check` exits 1 when a zombie process is occupying port 3000 (manual smoke test with a background `nc -l 3000`).
- `roster-check.sh` exits 0 against a complete set of gate sinks (fixture or real from a prior `/ak-pre-ship` run).
- `roster-check.sh` exits 1 when a required gate sink is deleted.
- `check-llm-mediated-na.sh` exits 1 on a `review.md` with `- Result: n/a` on Gate 8, and exits 0 on the same file after changing to `- Result: blocked (n/a per scope: ...)`.
- `SKILL.md` Phase 3.0 calls `local-env-health.sh` and Phase 3.3 calls both `roster-check.sh` and `check-llm-mediated-na.sh`.
- `kit/docs/guide/migrations.md` contains the 4 FK rollback patterns.
- `kit/TODOS.md` line 139 entry is deleted.
- `kit/ROADMAP.md` entry is marked `[SHIPPED]`.
- Full existing bats suite still passes (`bats kit/tests/`).
