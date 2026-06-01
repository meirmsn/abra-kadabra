<!-- audited-at: 0137fc0d76280ec08254300cc783d6f7810e1a6d -->

# Pre-ship review — skip-bats-docs-only (devshop mode)

## Router Summary

- Dispatched gates (6): docs-check, fast-job-local, /simplify,
  docs-and-tests-review, /review, convention → all `pass`.
- Structural carve-outs (13): devshop-self-mode (no METRICS / supabase / UI /
  perf surface). LLM-mediated 7/8/9/10 marked `blocked (n/a per scope)` per the
  devshop-mode contract; advance-log STRUCTURAL stamps below.
- Dismissals: none.

**Dispatch note:** the LLM-mediated dispatched gates (/simplify, /review,
docs-and-tests-review, convention) ran orchestrator-inline this session — the
subagent transport dropped its socket three times (spec agent + retries), and
the diff is 15 lines of bash + one bats spec + doc/tracker edits. The
deterministic backbone is the full bats suite (1611 ok / 0 fail) + an
integration dogfood of the real hook decision block (`verification.log`).
`/ak-merge-devshop` Phase 1.1 independently re-audits `$ANCHOR..HEAD` at merge.

---

## Gate 1: docs-check

- Result: pass

Hook behavior change is documented: `kit/docs/guide/hooks.md` (2f flow line +
gate table row) updated to note the docs-only skip; `spec.md` carries the full
rationale; `kit/TODOS.md` entry rewritten to the remaining work. Per-commit
`check-docs-coverage-devshop.sh` passed on every commit. No stale cross-refs
(`grep` across kit/docs, CLAUDE.md, kit/ROADMAP.md, kit/FRICTION-LOG.md → none).

## Dismissals

None

## Gate 2: metrics-check

- Result: n/a (devshop-self-mode: no METRICS.md)

## Dismissals

None

## Gate 2b: rls-coverage

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 2c: slow-job-lifecycle

- Result: n/a (devshop-self-mode: no slow-job CI)

## Dismissals

None

## Gate 2d: fast-job-local

- Result: pass

`bats kit/tests/` — 1611 ok / 0 not-ok. Includes the 6 new
`guard-bats-docs-only.bats` tests (predicate behavior + parity).

## Dismissals

None

## Gate 2e: migration-rollback-roundtrip

- Result: n/a (devshop-self-mode: no migrations)

## Dismissals

None

## Gate 2f: changed-tests-local

- Result: n/a (devshop-self-mode: bats run in Gate 2d covers this)

## Dismissals

None

## Gate 2g: advisor-clean

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 3: responsive-theme

- Result: n/a (devshop-self-mode: no UI surface)

## Dismissals

None

## Gate 4: /simplify

- Result: pass (no findings)

The predicate is already minimal. The intermediate `_staged_files` var is
load-bearing — it backs the `-n` empty-set guard, so it can't be inlined into
the `grep` pipe without losing the empty-staged-set case. The `! ... | grep -qvE`
double-negative is the idiomatic "all lines match" test. No simplification that
preserves behavior.

## Dismissals

None

## Gate 5: docs-and-tests-review

- Result: findings (1) fixed

See `## Audit 1` below.

## Dismissals

None

## Gate 6: /review

- Result: pass (1 non-blocking observation)

- **Correctness:** predicate logic verified — `! printf '%s\n' "$files" |
grep -qvE '\.md$'` is true iff every staged line ends in `.md`; the
  `-n "$_staged_files"` guard keeps an empty staged set out of the docs-only
  branch. Confirmed by unit tests + integration dogfood.
- **lint-staged interaction:** `prettier --write` re-stages content but never
  changes the staged path set, so reading `git diff --cached --name-only` after
  it is correct.
- **Observation (by design, not a finding):** a git-quoted path (spaces /
  unicode → `"a b.md"`) ends in `"` and falls through to running the suite. This
  is a conservative false-negative the design explicitly tolerates ("runs bats
  unnecessarily; next non-docs commit re-covers"). Pinned by the
  `readme.md.txt` anchor test guarding the trailing `$`.
- No auth / RLS / SQL / side-effect-in-conditional surface (it's a commit hook
  predicate).

## Dismissals

None

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself. Note: this change does NOT weaken that gauntlet — lint-staged, gitleaks, the branch guard, and the Layer-1 coverage hooks all still run on every commit; only the redundant bats no-op is skipped on docs-only diffs.)

## Dismissals

None

## Gate 8: /design-review

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface)

## Dismissals

None

## Gate 8b: design-conformance

- Result: n/a (devshop-self-mode: no DESIGN.md)

## Dismissals

None

## Gate 9: /qa

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface; bats invariants are the test surface and run in Gate 2d)

## Dismissals

None

## Gate 10: /benchmark

- Result: blocked (n/a per scope: devshop-self-mode — no perf surface)

## Dismissals

None

## Gate 10b: preflight-final

- Result: n/a (devshop-self-mode: bats recheck in Gate 2d covers this)

## Dismissals

None

## Gate 11: convention

- Result: pass

- No new SKILL.md (no frontmatter to check); no new script under `kit/scripts/`
  (so no paired-`.bats` requirement triggered — but the inline hook change
  still ships a paired `guard-bats-docs-only.bats` anyway).
- New test follows the `guard-*.bats` naming convention and the
  fixture + parity pattern of `guard-husky-branch.bats`.
- No new guide doc (so the routing-index requirement is n/a); the existing
  `hooks.md` was updated in place.
- Commit subjects describe the observable change, ≤ 72 chars.

## Dismissals

None

---

## Audit 1

<!-- audited-at: 0137fc0d76280ec08254300cc783d6f7810e1a6d -->

findings: high=0 medium=0 low=0 (1 found + fixed during Phase 2.5)

### Docs review

- `kit/docs/guide/hooks.md` — **finding (fixed `0137fc0`):** the 2f bats-gate
  description ("full suite on main, affected-only on branches") was stale after
  the docs-only skip landed. Updated both the flow diagram line and the gate
  table row.
- `spec.md`, `kit/TODOS.md` — complete and consistent; TODO rewritten to
  imperative-present for the shipped part + scoped remainder; no orphan
  cross-refs.
- BUILD-LOG entry pending (Phase 4.0).

### Tests review

- `kit/tests/guard-bats-docs-only.bats` adequately pins the new behavior:
  all-`.md` → skip, mixed → run, `.sh`-only → run, empty → run, trailing-anchor
  → run, plus a parity test that fails if the production predicate block drifts
  from the fixture. This is behavior coverage (not source-grep) per the
  devshop test-quality bar.
- No existing test pinned the changed `hooks.md` text (verified via grep);
  full suite green after the doc edit.

---

## Phase 3 → 4 advance log

### 2026-05-31 — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-31 -->

### 2026-05-31 — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-31 -->

### 2026-05-31 — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants run in Gate 2d
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-31 -->

### 2026-05-31 — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-31 -->

---

## Audit 2: manual (2026-05-31)

<!-- audited-at: c1828905761ef1011f58a7c215e419ecc00f962e -->
<!-- range: ccffb7d3c7ca0749e9625e5c361915cec0288e66..c1828905761ef1011f58a7c215e419ecc00f962e -->

findings: high=0 medium=0 low=1

Run at `/ak-merge-devshop` Phase 1.1. Both reviews run inline (subagent
transport unstable this session — 3 drops); functionally equivalent to the
parallel-Agent dispatch, only parallelism lost. The only commits since Audit 1
(`dd40b17`, `c182890`) are docs-only bookkeeping.

### Docs findings

- (none)

### Tests findings

- [low] `.husky/pre-commit` / `kit/tests/guard-bats-docs-only.bats` — the
  committed coverage pins the predicate (unit + parity); the wiring
  (predicate → skip-message vs full-suite-run) was verified by an ad-hoc
  integration dogfood (`verification.log`) rather than a committed test. Low —
  three trivial lines, `bash -n` clean, parity guards predicate drift. A
  committed integration test is future polish, not a ship blocker.

### Bypass trailer audit

- (none)
