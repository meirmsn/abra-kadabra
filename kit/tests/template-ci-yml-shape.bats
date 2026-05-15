#!/usr/bin/env bats
# Structural assertions for the template's CI workflow file (the default
# .github/workflows/ci.yml that ships with every project scaffolded via
# /ak-new-project). Pins the literal commented-out shape of the slow-job
# skip-on-docs-only filter (the `changes:` setup-job stub + slow-job's
# `needs:`/`if:` wiring).
#
# Pure file-content checks; no real GitHub Actions runner needed.
#
# Background: slow-job-skip-on-docs-only feature (specs/slow-job-skip-on-
# docs-only/spec.md, decisions D1 + D2). The `changes:` job classifies the
# PR diff and exposes `runtime: 'true'/'false'` as a job output; the
# slow-job's `needs: [fast, changes]` + `if: needs.changes.outputs.runtime
# == 'true'` consumes it to skip the 8-10 min slow-job on docs-only diffs.
# Both stubs ride the same uncomment ritual on purpose — uncommenting
# `slow:` without `changes:` produces a dangling `needs:` reference.
#
# Convention reference (operator-facing):
#   kit/docs/guide/conventions.md § Slow-Job Lifecycle § Skip-on-docs-only filter
# Pre-ship gate that asserts the filter is wired once a project uncomments
# the slow-job:
#   kit/scripts/preship/slow-job-lifecycle-check.sh § Check 6

setup() {
  load helpers/setup
  DEVSHOP="/devshop"
  CI_YML="$DEVSHOP/template/.github/workflows/ci.yml"
}

# =============================================================================
# `changes:` job stub — present + canonical shape
# =============================================================================

@test "template ci.yml exists" {
  [ -f "$CI_YML" ]
}

@test "changes: job stub present (commented form)" {
  run grep -E '^[[:space:]]+#[[:space:]]+changes:[[:space:]]*$' "$CI_YML"
  assert_success
}

@test "changes: stub uses actions/checkout@v4" {
  # Within the commented block, the checkout action is pinned to v4
  # (matches the fast-job's pin; same constraint).
  run grep -E '^[[:space:]]+#[[:space:]]+- uses: actions/checkout@v4' "$CI_YML"
  assert_success
}

@test "changes: stub sets fetch-depth: 0 on checkout" {
  # Required for `git diff base.sha...HEAD` (default depth-1 clone errors
  # with 'fatal: Invalid revision range' because the base SHA isn't local).
  # Match an indented commented `fetch-depth: 0` line — the comment leader
  # before "fetch-depth" can carry varying whitespace.
  run grep -E '^[[:space:]]+#[[:space:]]+fetch-depth: 0' "$CI_YML"
  assert_success
}

@test "changes: stub declares outputs.runtime referencing the classify step" {
  # The job-level `outputs:` block must declare `runtime:` referencing the
  # classify step's output. Match `runtime: ${{ steps.<id>.outputs.runtime }}`
  # in the commented block.
  run grep -E '^[[:space:]]+#[[:space:]]+runtime: \$\{\{ steps\.[a-zA-Z0-9_-]+\.outputs\.runtime \}\}' "$CI_YML"
  assert_success
}

@test "changes: classify step writes runtime= to \$GITHUB_OUTPUT" {
  # Canonical pattern: `echo "runtime=$VAR" >> "$GITHUB_OUTPUT"`. The literal
  # `>> "$GITHUB_OUTPUT"` appears inside the commented heredoc-style run
  # block. Match either runtime=true or runtime=$runtime.
  run grep -E 'runtime=.*>> "\$GITHUB_OUTPUT"' "$CI_YML"
  assert_success
}

@test "changes: diff-base uses three-dot merge-base form (base.sha...HEAD)" {
  # Three-dot diff = merge-base diff (the changes the PR introduces).
  # Two-dot would diff against base's current tip and pick up unrelated
  # commits (gotcha codified in spec § Gotchas). Catches the refactor that
  # silently drops the `...`.
  run grep -E 'git diff --name-only "\$\{\{ github\.event\.pull_request\.base\.sha \}\}\.\.\.HEAD"' "$CI_YML"
  assert_success
}

@test "changes: classify does NOT enable shopt -s globstar (as a bash directive)" {
  # globstar only affects pathname expansion, not `case` semantics — it was
  # cargo-culted into the original step and gave a false sense that `**/*.md`
  # would match nested paths. Inside `case`, `*` already matches `/`, so plain
  # `*.md` works for both root + nested. Lalista PR #63 (2026-05-12) was the
  # regression that surfaced the trap.
  #
  # The match is anchored to a directive-shaped line (yaml `#` + whitespace +
  # `shopt`) so the comment in the template that NAMES the trap doesn't
  # itself trigger a false positive — those lines have an extra `#` (yaml
  # comment + bash comment) so they look like `# # `shopt -s globstar`…`.
  run grep -E '^[[:space:]]+#[[:space:]]+shopt -s globstar[[:space:]]*$' "$CI_YML"
  assert_failure
}

@test "changes: empty-diff defaults to runtime=true (safer default)" {
  # The empty-diff edge case → runtime=true so the slow-job runs rather
  # than silently skips (gotcha codified in spec § Gotchas).
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
  # files — see Lalista PR #63 (2026-05-12). Match must be the bare `*.md)`
  # case-arm, not a stray substring inside `apps/**/*.md` elsewhere.
  run grep -E '^[[:space:]]+#[[:space:]]+\*\.md\)' "$CI_YML"
  assert_success
}

@test "ignore list: **/*.md must NOT appear (regression guard)" {
  # Belt-and-braces: forbid the buggy pattern so a future "tidy-up" PR can't
  # re-introduce `**/*.md` thinking it's a stricter form. See PR #63 / the
  # negative-assertion above on `shopt -s globstar` for the full story.
  run grep -E '\*\*/\*\.md\)' "$CI_YML"
  assert_failure
}

@test "ignore list: specs/** present" {
  run grep -E 'specs/\*\*\)' "$CI_YML"
  assert_success
}

@test "ignore list: PLAN.md present" {
  run grep -E '^[[:space:]]+#[[:space:]]+PLAN\.md\)' "$CI_YML"
  assert_success
}

@test "ignore list: BUILD-LOG.md present" {
  run grep -E '^[[:space:]]+#[[:space:]]+BUILD-LOG\.md\)' "$CI_YML"
  assert_success
}

@test "ignore list: TODOS.md present" {
  run grep -E '^[[:space:]]+#[[:space:]]+TODOS\.md\)' "$CI_YML"
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
  # still preserves the documented reading order. Capture the line numbers
  # of each pattern's case-arm and assert ascending.
  local md specs plan buildlog todos gstack devshop
  md=$(grep -nE '^\s+#\s+\*\.md\)' "$CI_YML" | head -1 | cut -d: -f1)
  specs=$(grep -nE '^\s+#\s+specs/\*\*\)' "$CI_YML" | head -1 | cut -d: -f1)
  plan=$(grep -nE '^\s+#\s+PLAN\.md\)' "$CI_YML" | head -1 | cut -d: -f1)
  buildlog=$(grep -nE '^\s+#\s+BUILD-LOG\.md\)' "$CI_YML" | head -1 | cut -d: -f1)
  todos=$(grep -nE '^\s+#\s+TODOS\.md\)' "$CI_YML" | head -1 | cut -d: -f1)
  gstack=$(grep -nE '^\s+#\s+\.gstack/\*\*\)' "$CI_YML" | head -1 | cut -d: -f1)
  devshop=$(grep -nE '^\s+#\s+\.devshop/\*\*\)' "$CI_YML" | head -1 | cut -d: -f1)
  [ -n "$md" ] && [ -n "$specs" ] && [ -n "$plan" ] && [ -n "$buildlog" ] && [ -n "$todos" ] && [ -n "$gstack" ] && [ -n "$devshop" ]
  [ "$md" -lt "$specs" ]
  [ "$specs" -lt "$plan" ]
  [ "$plan" -lt "$buildlog" ]
  [ "$buildlog" -lt "$todos" ]
  [ "$todos" -lt "$gstack" ]
  [ "$gstack" -lt "$devshop" ]
}

# =============================================================================
# Slow-job stub — `needs:` and `if:` wired to changes:
# =============================================================================

@test "slow: stub still commented (template default)" {
  run grep -E '^[[:space:]]+#[[:space:]]+slow:[[:space:]]*$' "$CI_YML"
  assert_success
}

@test "slow: stub's needs: is [fast, changes] (commented)" {
  run grep -E '^[[:space:]]+#[[:space:]]+needs: \[fast, changes\]' "$CI_YML"
  assert_success
}

@test "slow: stub's if: includes needs.changes.outputs.runtime == 'true'" {
  # Full canonical predicate: pull_request gate AND runtime gate.
  run grep -E "^[[:space:]]+#[[:space:]]+if: github\.event_name == 'pull_request' && needs\.changes\.outputs\.runtime == 'true'" "$CI_YML"
  assert_success
}

@test "slow: stub still references pull_request event (gating preserved)" {
  # The PR-only gate stays in place; the runtime gate is appended to it
  # (not a replacement).
  run grep -E "^[[:space:]]+#[[:space:]]+if: github\.event_name == 'pull_request'" "$CI_YML"
  assert_success
}

# =============================================================================
# Uncomment-both ritual — comment block above stubs explains the trap
# =============================================================================

@test "comment block: cross-references conventions.md § Skip-on-docs-only filter" {
  # The comment block above the stubs explains the uncomment-both ritual
  # and points at the canonical doc home (D5). The "Skip-on-docs-only" /
  # "filter" tokens may straddle a comment-line wrap — match independently.
  run grep -E 'conventions\.md § Slow-Job Lifecycle § Skip-on-docs-only' "$CI_YML"
  assert_success
  run grep -E '^[[:space:]]+#[[:space:]]+filter\b' "$CI_YML"
  assert_success
}

@test "comment block: warns about dangling needs: reference if changes: stays commented" {
  # Specific warning that ` slow:` without ` changes:` produces a dangling
  # `needs:` at YAML-load time — keeps the trap visible at edit time.
  run grep -iE 'dangling.*needs|needs.*dangling' "$CI_YML"
  assert_success
}

# =============================================================================
# Baked-in fixes — the 5 home-os PR #15 / lalista PR #26 fixes propagated into
# the commented slow-job stub so projects scaffolded post-2026-05-14 inherit
# them ambiently. The whole premise of the propagate-home-os-pr15-patterns
# branch is "uncomment ritual is 'strip every leading # ', not 'fill in the
# blanks'" — so a future tidy-up PR must not silently drop these lines from
# the stub. See:
#   kit/docs/guide/ops.md § CI/CD § "Template slow-job stub carries the
#                                    canonical shape, fully baked"
# Each assertion mirrors the existing "must NOT appear" regression-guard
# pattern (e.g. `**/*.md`) so the test surfaces clearly when a line is lost.
# =============================================================================

@test "baked-in fix: playwright install --with-deps chromium webkit (mobile project needs both)" {
  # devices['iPhone N'] defaults to WebKit; chromium-only installs fail every
  # [mobile] spec at browser launch. Match either the commented stub install
  # step or any other invocation of the canonical pair in the file.
  run grep -E 'playwright install --with-deps chromium webkit' "$CI_YML"
  assert_success
}

@test "baked-in fix: step-level \${{ env.* }} mapping (job-level env: would shadow GITHUB_ENV writes)" {
  # The slow-job's test steps source the real Supabase values via
  # supabase-status export written to \$GITHUB_ENV, then map them into the
  # process env at step-level. Job-level env: would PIN the GH-Variables
  # value and shadow $GITHUB_ENV writes; the supabase-status export emits
  # unprefixed names that SUPABASE_*-prefixed reads can't see otherwise.
  # Pin presence of at least one step-level env-mapping for ANON_KEY (the
  # canonical example in the stub).
  run grep -E '\$\{\{ env\.ANON_KEY \}\}' "$CI_YML"
  assert_success
}

@test "baked-in fix: sed -E quote-strip before >> \$GITHUB_ENV (supabase status -o env wraps values in literal quotes)" {
  # supabase status -o env wraps every value in "..." literals; without
  # stripping, GITHUB_ENV stores the quotes verbatim and every consumer
  # parses it as an invalid URL. Use grep -F for the literal sed pattern
  # to avoid regex-escape juggling.
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
  # /functions/v1/ and restart once on 502/timeout. Match either the probe
  # path or the restart warning string.
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
  # investigation. Positive pin AND a regression guard on the buggy shape.
  run grep -E '^[[:space:]]+branches:[[:space:]]+\[main\]' "$CI_YML"
  assert_success
}

@test "baked-in fix: branches-ignore: [main] must NOT appear as an active YAML directive (regression guard)" {
  # Forbid the buggy shape — comments referencing it in prose ("NOT
  # branches-ignore: [main]") are fine because they're prefixed with `#`,
  # but a directive-shaped line (no `#` after leading whitespace) is the
  # regression. Belt-and-braces sibling to the `**/*.md` negative-assert
  # on the ignore-list pattern.
  run grep -E '^[[:space:]]+branches-ignore:[[:space:]]+\[main\]' "$CI_YML"
  assert_failure
}
