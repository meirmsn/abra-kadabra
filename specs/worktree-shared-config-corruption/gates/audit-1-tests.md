# Tests Review — Audit 1

Range: `ab91438e73102dba6389b8489d4ca76149e23ccb..d14a7deb1f7c38e6e443b2f0a3bad3add54ac0e0`
Feature: `worktree-shared-config-corruption`

Scope note: the bulk of the diff is vendored third-party bats library files under
`kit/tests/lib/bats-*/**` (upstream code) — exempt from coverage/header/quality
flags per the orchestrator instruction. The reviewable test surface is:
`kit/scripts/vendor-bats-libs.sh` (new) + `kit/tests/util-vendor-bats-libs.bats`
(new, paired), and the modified `kit/tests/structural-invariants.bats` +
`kit/tests/util-ak-merge-devshop.bats`.

## Section A — Coverage of new behavior

`vendor-bats-libs.sh` is the only new `kit/scripts/**.sh`. It has a paired
`util-vendor-bats-libs.bats` (12 assertions, references the script 4×). The
devshop bats-coverage gate enumerates only `kit/scripts/**.sh`, so the vendored
`bin/bats` / `libexec/*` runtime scripts under `kit/tests/lib/` are never
enumerated — no false-positive coverage flag. The two modified bats files cover
their respective rewrites (submodule→plain-files runtime check; submodule-deinit
removal regression guard). No missing pairs.

## Section B — Test quality

Devshop bats domain — no API wrappers, RLS, realtime subscriptions, edge
functions, or LLM/edge boundaries are in range, so those rubric items are n/a.
Assertions in the new + modified tests are concrete (executable-bit checks,
file/dir presence, 40-hex-char SHA regex, manifest↔pin-table cross-check,
ordering comparisons, and a negative regression guard for the removed deinit
command). No weak `toBeDefined`/`toBeTruthy`-equivalent assertions. No
`.only` / `.skip` introduced (verified across the range). One low finding below.

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/util-vendor-bats-libs.bats:1-12`
**What**: The paired test is structural-only — it asserts the _current on-disk
state_ (runtime subset present, trim dirs absent, manifest shape, no `.git`
residue) but never exercises `vendor-bats-libs.sh`'s actual behavior: the
destructive `rm -rf "$dest"` before re-clone, the per-lib clone+checkout, the
`runtime_subset` "missing path" error exit (lines 90-93), or the "no subset
declared" error exit (lines 72-75).
**Why**: A regression in the script's copy/trim logic (e.g. a typo in
`runtime_subset` dropping `libexec`, or the missing-path guard ceasing to fire)
would not be caught by this test — only by an operator re-running the script and
noticing the self-verify suite fail. The error-exit branches are untested.
**Fix**: Acceptable as-is for ship — the test header explicitly scopes this
("cheap STRUCTURAL assertions only — no network re-clone") and names the full
bats suite (run by the script's own self-verify step, line 104-105) as the loud
catch for runtime-set completeness. The destructive `rm -rf` is bounded to
`$LIB_DIR/<lib>` and only runs on an explicit operator invocation. If cheap
coverage of the pure-logic guards is later wanted, the `runtime_subset()`
function and the two `ERROR:`-exit branches could be exercised by sourcing the
script with a stubbed `git`/`mktemp` — but this is a nice-to-have, not a gap that
should block.

## Section C — Bypass trailer audit

One `Tests-Coverage-Bypass:` trailer harvested (commit `3fb00d6`,
"build(tests): add vendor-bats-libs.sh re-vendor path + paired test").

- **VERIFIED** — The bypass states the paired test
  (`kit/tests/util-vendor-bats-libs.bats`, 12 assertions) IS written and
  committed in the same commit, but the devshop coverage gate hardcodes
  `DEVSHOP=/devshop` and scans the canonical `/devshop/kit/tests`, where the
  worktree's new test does not yet exist (the known worktree-blind
  `$DEVSHOP`-rooted gate gotcha). Confirmed against the diff: the paired test
  file is present in-range and all 12 assertions pass when run against the
  worktree tree. The bypass was load-bearing (gate is genuinely worktree-blind)
  and remains valid — the file resolves on merge to main. No escalation.

---

high=0 medium=0 low=1
