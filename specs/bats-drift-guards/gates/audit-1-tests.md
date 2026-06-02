# Tests Review — bats-drift-guards

Range: `f2c1e34..4d174f24`
Feature dir: `specs/bats-drift-guards`
Test surface: bats (devshop-self-mode; no vitest/Playwright in range).

## Section A — Coverage of new behavior

Two new structural-invariant guards land in `kit/tests/structural-invariants.bats`.
Both are **self-testing** — the behavior they introduce is pinned by a live
proof inside the same diff, not just by file pairing.

- **Wiring skill-autodetect** (modified `@test "wiring: every non-exempt kit
script is wired into a hook or pre-commit"`, lines 217–305). The new branch
  treats a kit script as "wired (skill-invoked)" if its basename appears as a
  whole FILENAME token in any `.claude/skills/**/SKILL.md`. The diff prunes
  `reconcile-task-commits.sh` and `virtiofs-rebase.sh` from `infra_scripts` — the
  prune IS the live proof: both are removed from the manual allow-list, so the
  test stays green ONLY if the autodetect grep actually catches them. Verified:
  both appear in SKILL.md files (`reconcile-task-commits.sh` → build/ +
  implement/; `virtiofs-rebase.sh` → merge-devshop/), and `vendor-bats-libs.sh`
  is correctly absent from every SKILL.md (kept in `infra_scripts`). The guard
  asserts via `false` (line 303) on any unwired script — it does not no-op. Full
  suite ran green in-worktree (62/62).

- **Grep-drift `@test "grep-drift: every '# pins:' annotation still resolves in
its target file"`** (lines 996–1056). It genuinely asserts: on a drifted/empty
  literal it accumulates into `$drifted` and calls `false` (line 1055). Confirmed
  by extracting the core logic and exercising it on fixtures: valid pin → PASS;
  literal removed from target → FAIL (regression caught); placeholder
  `<repo-relative-path>` form → skipped/PASS; no-separator annotation → FAIL
  malformed. It does NOT silently pass.

Both new behaviors are pinned by an assertion that genuinely fails on regression.
No missing coverage.

## Section B — Test quality

### Hardening from commit 1ffa2e3 — verified holds

- **Empty-literal flag (grep-drift).** The load-bearing case: `# pins: foo.md :: `
  (trailing separator, nothing after). `grep -qF "" file` matches any non-empty
  file, which would silently defeat the guard. Verified on a fixture: the
  empty-literal annotation is caught as `MALFORMED`, NOT a silent pass. The
  `[ -z "$literal" ]` check (line 1042) holds.

- **Whole-FILENAME-token boundary (wiring autodetect).** Verified the new ERE
  boundary `[^A-Za-z0-9._-]` rejects `url.sh` matching inside
  `extract-prod-url.sh` (no-match), where the old `grep -wF` produces a false
  MATCH (confirmed both behaviors side-by-side on a fixture). Real filenames
  (`extract-prod-url.sh`) still match. The regex-metachar escape via `sed`
  (line 289) covers the `.` in `.sh`.

### Seed `# pins:` annotations — all 3 pin real, stable literals

1. `.claude/skills/devshop/build/SKILL.md :: /ak-check-docs-and-tests`
   (in `util-build-phase58-audit-parser.bats`) — resolves (10 occurrences in the
   target). Stable orchestrator name; the asserting test greps the same literal
   in the same target, so the pin guards the orchestrator-rename drift direction.
2. `template/.devcontainer/firewall-extra-domains :: One bare hostname per line`
   (in `firewall-extras-overlay.bats`) — resolves (1 occurrence). Pin path
   matches the test's `$TEMPLATE_OVERLAY` target exactly. Stable format-doc
   header literal.
3. `kit/manifest.txt :: .devcontainer/firewall-extra-domains [scaffold-once]`
   (in `firewall-extras-overlay.bats`) — resolves (1 occurrence). Pin path
   matches `$MANIFEST`. Stable manifest declaration including the `[scaffold-once]`
   tag — exactly the literal a reword would silently drift.

All three target a literal the adjacent test actually greps; none pin prose or a
volatile string.

### Under-assertion gap — honestly scoped out, not silently unaddressed

The guard's own header comment (lines 999–1001), `conventions.md § Kit Testing`
(line 813), `spec.md` (D5, lines 58–60, 87), and the BUILD-LOG entry all state
explicitly that the guard catches **assertion-drift only** (asserted literal
removed → red) and does NOT catch **under-assertion** (a test pinning too little).
The convention names `/ak-tests-review` as the audit-time backstop for assertion
adequacy. This is honest labeling per the root-cause-over-bandaid rule, not a
silent omission.

No weak assertions, no skipped/`.only` tests, no shape-only gaps. (No
API wrappers, RLS tables, realtime subscriptions, or LLM/edge boundaries in
range — those rubrics are n/a for this devshop-self bats diff.)

## Section C — Bypass trailer audit

No `Tests-Coverage-Bypass:` trailers in the range. Zero rows (legitimate per the
forward-compatible harvest).

## Verdict

Tests look solid — no findings. Both guards assert and fail on regression
(verified on fixtures), the prune is a genuine live proof of the autodetect, the
3 seed pins target real stable literals in their declared files, both 1ffa2e3
hardenings (empty-literal flag, whole-FILENAME-token boundary) hold, and the
under-assertion limit is honestly documented in four places.
