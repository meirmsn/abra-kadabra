#!/usr/bin/env bats
# Structural assertions for the template's CI workflow file (the default
# .github/workflows/ci.yml that ships with every project scaffolded via
# /ak-new-project). Pins the literal active shape of the slow-job +
# changes: jobs.
#
# Pure file-content checks; no real GitHub Actions runner needed.
#
# Background: slow-job activation feature shipped 2026-05-19 via the
# template-ci-overhaul branch. The `changes:` job classifies the PR diff
# and exposes `runtime: 'true'/'false'` as a job output; the slow-job's
# `needs: [fast, changes]` + `if: needs.changes.outputs.runtime == 'true'`
# consumes it to skip the 8-10 min slow-job on docs-only diffs.
# Both jobs ship ACTIVE (uncommented) from day one — brand-new projects
# with zero migrations / zero e2e specs short-circuit via per-step
# `if: hashFiles(...) != ''` guards, so the slow-job runs in ~30s on an
# empty project and gates real content the moment it lands.
#
# Convention reference (operator-facing):
#   kit/docs/guide/conventions.md § Slow-Job Lifecycle
# Pre-ship gate that asserts the active stub hasn't been hollowed out:
#   kit/scripts/preship/slow-job-lifecycle-check.sh

setup() {
  load helpers/setup
  DEVSHOP="$(git rev-parse --show-toplevel)"
  CI_YML="$DEVSHOP/template/.github/workflows/ci.yml"
}

# Extract a named job's body (lines between `  <name>:` and the next 2-sp
# job-level key, or EOF) into stdout. Used to job-scope assertions that
# otherwise match a pattern present in multiple jobs (e.g. fast-job + changes-
# job both use actions/checkout@v4 — a bare grep can pass on the wrong match).
job_body() {
  local job_name="$1"
  awk -v name="$job_name" '
    $0 ~ "^  " name ":[[:space:]]*$" { in_job=1; next }
    in_job && /^  [a-zA-Z_-]+:[[:space:]]*$/ { exit }
    in_job { print }
  ' "$CI_YML"
}

# =============================================================================
# `changes:` job — present, active (uncommented), canonical shape
# =============================================================================

@test "template ci.yml exists" {
  [ -f "$CI_YML" ]
}

@test "changes: job is active (uncommented form)" {
  # Uncommented form: 2sp + `changes:` at the start of the line, no `#`.
  run grep -E '^[[:space:]]+changes:[[:space:]]*$' "$CI_YML"
  assert_success
}

@test "changes: job uses actions/checkout@v4" {
  # Pinned to v4 (matches fast-job; same constraint). Job-scoped so a
  # malformed changes-job that drops checkout entirely can't pass via the
  # fast-job's checkout matching the bare grep. Inline extract because a
  # `bash -c` subshell wouldn't see the `job_body` shell function defined
  # in setup().
  local body
  body=$(job_body changes)
  echo "$body" | grep -qE '^[[:space:]]+- uses: actions/checkout@v4'
}

@test "changes: sets fetch-depth: 0 on checkout" {
  # Required for `git diff base.sha...HEAD` (default depth-1 clone errors
  # with 'fatal: Invalid revision range' because the base SHA isn't local).
  # Job-scoped so the fast-job's fetch-depth: 0 doesn't satisfy this on
  # behalf of a changes-job that lost it.
  local body
  body=$(job_body changes)
  echo "$body" | grep -qE '^[[:space:]]+fetch-depth: 0'
}

@test "changes: declares outputs.runtime referencing the classify step" {
  # The job-level `outputs:` block must declare `runtime:` referencing the
  # classify step's output. Match `runtime: ${{ steps.<id>.outputs.runtime }}`.
  run grep -E '^[[:space:]]+runtime: \$\{\{ steps\.[a-zA-Z0-9_-]+\.outputs\.runtime \}\}' "$CI_YML"
  assert_success
}

@test "changes: classify step writes runtime= to \$GITHUB_OUTPUT" {
  # Canonical pattern: `echo "runtime=$VAR" >> "$GITHUB_OUTPUT"`. The literal
  # `>> "$GITHUB_OUTPUT"` appears inside the run block.
  run grep -E 'runtime=.*>> "\$GITHUB_OUTPUT"' "$CI_YML"
  assert_success
}

@test "changes: diff-base uses three-dot merge-base form (base.sha...HEAD)" {
  # Three-dot diff = merge-base diff (the changes the PR introduces).
  # Two-dot would diff against base's current tip and pick up unrelated
  # commits. Catches the refactor that silently drops the `...`.
  run grep -E 'git diff --name-only "\$\{\{ github\.event\.pull_request\.base\.sha \}\}\.\.\.HEAD"' "$CI_YML"
  assert_success
}

@test "changes: classify does NOT enable shopt -s globstar (as a bash directive)" {
  # globstar only affects pathname expansion, not `case` semantics — it was
  # cargo-culted into the original step and gave a false sense that `**/*.md`
  # would match nested paths. Inside `case`, `*` already matches `/`, so plain
  # `*.md` works for both root + nested. Lalista PR #63 (2026-05-12) regression.
  # Match a directive-shaped line (leading whitespace + `shopt`).
  run grep -E '^[[:space:]]+shopt -s globstar[[:space:]]*$' "$CI_YML"
  assert_failure
}

@test "changes: empty-diff defaults to runtime=true (safer default)" {
  # The empty-diff edge case → runtime=true so the slow-job runs rather
  # than silently skips.
  run grep -E 'runtime=true' "$CI_YML"
  assert_success
}

# =============================================================================
# D2 ignore list — every glob present in canonical order
# =============================================================================

@test "ignore list: *.md present (covers root + nested in bash case)" {
  # Plain `*.md` — NOT `**/*.md`. `case` patterns aren't globs: `*` already
  # matches `/`, so `*.md` covers `CLAUDE.md` AND `apps/web/README.md`.
  # `**/*.md` in `case` collapses to `*/*.md` and silently misses root-level
  # files — see Lalista PR #63 (2026-05-12). Match the bare `*.md)` case-arm.
  run grep -E '^[[:space:]]+\*\.md\)' "$CI_YML"
  assert_success
}

@test "ignore list: **/*.md must NOT appear (regression guard)" {
  # Belt-and-braces: forbid the buggy pattern so a future "tidy-up" PR can't
  # re-introduce `**/*.md` thinking it's a stricter form.
  run grep -E '\*\*/\*\.md\)' "$CI_YML"
  assert_failure
}

@test "ignore list: specs/** present" {
  run grep -E 'specs/\*\*\)' "$CI_YML"
  assert_success
}

@test "ignore list: PLAN.md present" {
  run grep -E '^[[:space:]]+PLAN\.md\)' "$CI_YML"
  assert_success
}

@test "ignore list: BUILD-LOG.md present" {
  run grep -E '^[[:space:]]+BUILD-LOG\.md\)' "$CI_YML"
  assert_success
}

@test "ignore list: TODOS.md present" {
  run grep -E '^[[:space:]]+TODOS\.md\)' "$CI_YML"
  assert_success
}

@test "ignore list: .gstack/** present" {
  run grep -E '\.gstack/\*\*\)' "$CI_YML"
  assert_success
}

@test "ignore list: .devshop/** present" {
  run grep -E '\.devshop/\*\*\)' "$CI_YML"
  assert_success
}

@test "ignore list: canonical order (*.md → specs/** → PLAN.md → BUILD-LOG.md → TODOS.md → .gstack/** → .devshop/**)" {
  # Pin the canonical order so a future refactor that reshuffles the list
  # still preserves the documented reading order.
  local md specs plan buildlog todos gstack devshop
  md=$(grep -nE '^\s+\*\.md\)' "$CI_YML" | head -1 | cut -d: -f1)
  specs=$(grep -nE '^\s+specs/\*\*\)' "$CI_YML" | head -1 | cut -d: -f1)
  plan=$(grep -nE '^\s+PLAN\.md\)' "$CI_YML" | head -1 | cut -d: -f1)
  buildlog=$(grep -nE '^\s+BUILD-LOG\.md\)' "$CI_YML" | head -1 | cut -d: -f1)
  todos=$(grep -nE '^\s+TODOS\.md\)' "$CI_YML" | head -1 | cut -d: -f1)
  gstack=$(grep -nE '^\s+\.gstack/\*\*\)' "$CI_YML" | head -1 | cut -d: -f1)
  devshop=$(grep -nE '^\s+\.devshop/\*\*\)' "$CI_YML" | head -1 | cut -d: -f1)
  [ -n "$md" ] && [ -n "$specs" ] && [ -n "$plan" ] && [ -n "$buildlog" ] && [ -n "$todos" ] && [ -n "$gstack" ] && [ -n "$devshop" ]
  [ "$md" -lt "$specs" ]
  [ "$specs" -lt "$plan" ]
  [ "$plan" -lt "$buildlog" ]
  [ "$buildlog" -lt "$todos" ]
  [ "$todos" -lt "$gstack" ]
  [ "$gstack" -lt "$devshop" ]
}

# =============================================================================
# Slow-job — active (uncommented), `needs:` and `if:` wired to changes:
# =============================================================================

@test "slow: job is active (uncommented form)" {
  run grep -E '^[[:space:]]+slow:[[:space:]]*$' "$CI_YML"
  assert_success
}

@test "slow: needs: is [fast, changes]" {
  run grep -E '^[[:space:]]+needs: \[fast, changes\]' "$CI_YML"
  assert_success
}

@test "slow: if: includes needs.changes.outputs.runtime == 'true'" {
  # Full canonical predicate: pull_request gate AND runtime gate.
  run grep -E "^[[:space:]]+if: github\.event_name == 'pull_request' && needs\.changes\.outputs\.runtime == 'true'" "$CI_YML"
  assert_success
}

@test "slow: references pull_request event (gating preserved)" {
  # The PR-only gate stays in place; the runtime gate is appended to it
  # (not a replacement).
  run grep -E "^[[:space:]]+if: github\.event_name == 'pull_request'" "$CI_YML"
  assert_success
}

# =============================================================================
# Empty-state guards — slow-job ships active from day one, so the heavy
# steps must short-circuit on brand-new projects with no migrations / no
# e2e specs. The `Start local Supabase` step is intentionally unguarded
# (ambient health signal). Source: template-ci-overhaul branch, 2026-05-19.
# =============================================================================

@test "empty-state guard: Playwright install gated on apps/web/e2e specs" {
  # The `Install Playwright browsers` step short-circuits when no e2e
  # specs exist (saves ~3 min on the first PR of a brand-new project).
  run grep -E "if: hashFiles\('apps/web/e2e/\*\*/\*\.spec\.ts'\) != ''" "$CI_YML"
  assert_success
}

@test "empty-state guard: type-drift + rollback gated on supabase/migrations" {
  # `ci-type-drift.sh` and `ci-rollback-explain.sh` both need a non-empty
  # supabase/migrations/ directory; brand-new projects don't have one.
  run grep -E "if: hashFiles\('supabase/migrations/\*\.sql'\) != ''" "$CI_YML"
  assert_success
}

@test "empty-state guard: Start local Supabase has NO hashFiles gate (ambient signal)" {
  # The `Start local Supabase` step is intentionally unguarded — it's the
  # heartbeat that proves CI plumbing is wired even on empty projects. If
  # a future "tidy-up" PR adds a hashFiles guard to this step, brand-new
  # projects lose the ambient signal and slow-job activation regresses to
  # the deferred-uncomment model.
  #
  # Scope: scan from `- name: Start local Supabase` forward until the next
  # step boundary (next `- name:` at the same 6-sp indent, OR the next
  # job-level key at 2-sp indent, OR EOF). An earlier version of this
  # test read only the line immediately after `- name:`, which would
  # silently pass if a benign `env:` / comment / blank line was inserted
  # between `name:` and the eventual `if: hashFiles`. The whole-body scan
  # mirrors the gate's Check 4b shape.
  local name_lineno end_lineno step_body
  name_lineno=$(grep -nE '^[[:space:]]+- name: Start local Supabase' "$CI_YML" | head -1 | cut -d: -f1)
  [ -n "$name_lineno" ] || { echo "Could not find 'Start local Supabase' step"; return 1; }
  # Find the end of the step: first line at or after $name_lineno+1 that
  # starts a new step (`      - `) or a new job-level key (no leading
  # indent beyond 2 spaces + a YAML key). Fallback to EOF.
  end_lineno=$(awk -v start="$name_lineno" '
    BEGIN { found = 0 }
    NR <= start { next }
    /^      - / { print NR; found = 1; exit }       # next step
    /^  [a-zA-Z_-]+:/ { print NR; found = 1; exit }  # next job-level key
    END { if (!found) print NR + 1 }                 # EOF — empty-range guard
  ' "$CI_YML")
  step_body=$(sed -n "$((name_lineno + 1)),$((end_lineno - 1))p" "$CI_YML")
  # No `if: hashFiles(...)` anywhere in the step body.
  echo "$step_body" | grep -qE 'if:[[:space:]]+hashFiles' && {
    echo "Found hashFiles guard inside Start local Supabase step body:"
    echo "$step_body"
    return 1
  }
  return 0
}

# =============================================================================
# Comment block — design rationale anchored to conventions.md
# =============================================================================

@test "comment block: cross-references conventions.md § Slow-Job Lifecycle" {
  # The comment block above the jobs points at the canonical doc home so
  # operators editing the workflow can drill into the design rationale.
  run grep -E 'conventions\.md § Slow-Job Lifecycle' "$CI_YML"
  assert_success
}

# =============================================================================
# Baked-in fixes — the 5 home-os PR #15 / lalista PR #26 fixes that the
# slow-job stub carries forward. The whole premise of the slow-job canonical
# shape is "every block was earned by a CI failure" — so a future tidy-up PR
# must not silently drop these lines. See:
#   kit/docs/guide/ops.md § CI/CD § "Template slow-job stub carries the
#                                    canonical shape, fully baked"
# Each assertion mirrors the "must NOT appear" regression-guard pattern
# (e.g. `**/*.md`) so the test surfaces clearly when a line is lost.
# =============================================================================

@test "baked-in fix: playwright install --with-deps chromium webkit (mobile project needs both)" {
  # devices['iPhone N'] defaults to WebKit; chromium-only installs fail every
  # [mobile] spec at browser launch.
  run grep -E 'playwright install --with-deps chromium webkit' "$CI_YML"
  assert_success
}

@test "baked-in fix: step-level \${{ env.* }} mapping (job-level env: would shadow GITHUB_ENV writes)" {
  # The slow-job's test steps source the real Supabase values via
  # supabase-status export written to \$GITHUB_ENV, then map them into the
  # process env at step-level. Job-level env: would PIN the GH-Variables
  # value and shadow $GITHUB_ENV writes; the supabase-status export emits
  # unprefixed names that SUPABASE_*-prefixed reads can't see otherwise.
  # Pin presence of at least one step-level env-mapping for ANON_KEY.
  run grep -E '\$\{\{ env\.ANON_KEY \}\}' "$CI_YML"
  assert_success
}

@test "baked-in fix: sed -E quote-strip before >> \$GITHUB_ENV (supabase status -o env wraps values in literal quotes)" {
  # supabase status -o env wraps every value in "..." literals; without
  # stripping, GITHUB_ENV stores the quotes verbatim and every consumer
  # parses it as an invalid URL.
  run grep -F "sed -E 's/=\"(.*)\"\$/=\\1/'" "$CI_YML"
  assert_success
}

@test "baked-in fix: artifact upload path includes apps/web/test-results (playwright-report/ is empty under reporter: 'github')" {
  # Under reporter: 'github', the HTML report (playwright-report/) is empty
  # because the github reporter doesn't write to disk. Videos / traces /
  # error-context.md live in test-results/. The upload step must include it.
  run grep -E 'apps/web/test-results' "$CI_YML"
  assert_success
}

@test "baked-in fix: supabase_edge_runtime cold-start retry (probe + restart once)" {
  # supabase_edge_runtime_workspace container occasionally cold-starts to
  # 502 on GH-Actions runners. Codified from lalista PR #26 — probe
  # /functions/v1/ and restart once on 502/timeout.
  run grep -E 'supabase_edge_runtime.*restart|restarting once' "$CI_YML"
  assert_success
  run grep -E '/functions/v1/' "$CI_YML"
  assert_success
}

@test "baked-in fix: workflow-level push trigger uses branches: [main] (NOT branches-ignore: [main])" {
  # branches-ignore: [main] triggered a redundant fast run on every PR-branch
  # push because pull_request already fires for the same event. Corrected
  # shape keeps push as a post-merge canary on trunk only; pre-merge CI
  # rides pull_request exclusively. Source: home-os PR #15 dup-runs
  # investigation.
  run grep -E '^[[:space:]]+branches:[[:space:]]+\[main\]' "$CI_YML"
  assert_success
}

@test "baked-in fix: branches-ignore: [main] must NOT appear as an active YAML directive (regression guard)" {
  # Forbid the buggy shape — comments referencing it in prose ("NOT
  # branches-ignore: [main]") are fine because they're prefixed with `#`,
  # but a directive-shaped line (no `#` after leading whitespace) is the
  # regression.
  run grep -E '^[[:space:]]+branches-ignore:[[:space:]]+\[main\]' "$CI_YML"
  assert_failure
}

# =============================================================================
# Node version pin — Node 22 required (pnpm 11.x imports node:sqlite, a
# Node-22-only builtin). Source: home-os C1 finding, template-ci-overhaul
# branch, 2026-05-19.
# =============================================================================

@test "node-version pin: fast + slow jobs use Node 22" {
  # Match the active YAML directive `node-version: '22'` (no leading `#`).
  # Both fast + slow set this, so at least one match must appear.
  run grep -E "^[[:space:]]+node-version: '22'" "$CI_YML"
  assert_success
}

@test "node-version pin: Node 20 must NOT appear as an active directive (regression guard)" {
  # If a future tidy-up reverts to Node 20, pnpm 11.x's `node:sqlite` import
  # crashes setup-node's pnpm-cache restore step with ERR_UNKNOWN_BUILTIN_MODULE.
  # Documented prose mentioning "Node 20" is fine; an active directive is not.
  run grep -E "^[[:space:]]+node-version: '20'" "$CI_YML"
  assert_failure
}
