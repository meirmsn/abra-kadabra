#!/usr/bin/env bash
# What: Pre-ship gate that asserts the slow-job CI is active and structurally
#       intact. Catches (a) re-commented slow-job stub, (b) wrong if: predicate,
#       (c) stripped edge-runtime retry, (d) missing empty-state hashFiles
#       guards, (e) hashFiles guard accidentally added to the ambient-signal
#       supabase-start step, (f) missing changes: wiring, (g) missing branch
#       protection, (h) specs exist but the slow-job doesn't invoke them.
# Why:  Slow-job ships ACTIVE from the template (since template-ci-overhaul,
#       2026-05-19). The previous deferred-uncomment model didn't survive
#       contact with the build loop — three consecutive home-os PRs shipped
#       past-threshold without flipping the stub. The active model puts the
#       structural invariant in CI from PR #1. This gate is the regression
#       guard against silent reversions (commented again, hashFiles guard
#       dropped, etc.). See kit/docs/guide/conventions.md § Slow-Job Lifecycle.
# Does NOT: actually run the slow job, validate test content, or repair the
#       workflow file. Read-only check; operator applies fixes.
#
# Usage: slow-job-lifecycle-check.sh [PROJECT_ROOT]
#        Exits 0 with stdout "pass" / "n/a (...)" or "findings (N)" + bullets.
#        Exits 1 only on internal error.

set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CI_YML="$PROJECT_ROOT/.github/workflows/ci.yml"

if [ ! -f "$CI_YML" ]; then
  echo "n/a (no .github/workflows/ci.yml)"
  exit 0
fi

# Spec presence — used by Check 5 (the "active job runs zero tests"
# regression-guard variant). An integration test is any *.integration.test.ts
# under packages/ or apps/. An E2E spec is any *.spec.ts under any apps/*/e2e/.
HAS_INTEGRATION="$(find "$PROJECT_ROOT/packages" "$PROJECT_ROOT/apps" -name '*.integration.test.ts' -type f 2>/dev/null | head -1 || true)"
HAS_E2E="$(find "$PROJECT_ROOT/apps" -path '*/e2e/*.spec.ts' -type f 2>/dev/null | head -1 || true)"

findings=()

# --- Check 1: slow: job active (uncommented) ---
# Active form: leading "  slow:" (2sp + slow:). Commented form (legacy):
# "  # slow:". Slow-job ships active from day one — commented form is a
# regression.
SLOW_COMMENTED=0
SLOW_LIVE=0
if grep -qE '^[[:space:]]+#[[:space:]]*slow:' "$CI_YML"; then
  SLOW_COMMENTED=1
fi
if grep -qE '^[[:space:]]+slow:' "$CI_YML"; then
  SLOW_LIVE=1
fi

if [ "$SLOW_LIVE" = "0" ] && [ "$SLOW_COMMENTED" = "1" ]; then
  findings+=("slow-job is commented out in .github/workflows/ci.yml — slow-job ships active from day one (template-ci-overhaul, 2026-05-19); see kit/docs/guide/conventions.md § Slow-Job Lifecycle")
elif [ "$SLOW_LIVE" = "0" ] && [ "$SLOW_COMMENTED" = "0" ]; then
  findings+=("slow-job not present in .github/workflows/ci.yml — restore from /devshop/template/.github/workflows/ci.yml (the template ships the canonical active shape)")
fi

# Subsequent checks only meaningful when slow: is active.
if [ "$SLOW_LIVE" = "1" ]; then

  # --- Check 2: slow-job if: predicate carries both pull_request + runtime gates ---
  # Scoped to the slow-job specifically: find the if: line that references
  # `needs.changes.outputs.runtime` (only the slow-job has that), then assert
  # it also carries `github.event_name == 'pull_request'`. A broader grep
  # would match the `changes:` job's if: line and let a broken slow-job if:
  # slip through.
  SLOW_IF_LINE="$(grep -E "if:.*needs\.changes\.outputs\.runtime" "$CI_YML" | head -1 || true)"
  if [ -n "$SLOW_IF_LINE" ] && ! echo "$SLOW_IF_LINE" | grep -qE "github\.event_name[[:space:]]*==[[:space:]]*['\"]pull_request['\"]"; then
    findings+=("slow-job 'if:' predicate is missing the \`github.event_name == 'pull_request'\` gate — without it the slow-job fires on direct push-to-main, burning CI minutes on the trunk-canary path. Expected: \`if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'\`. See conventions.md § Slow-Job Lifecycle")
  fi

  # --- Check 3: edge-runtime health-check retry pattern wired ---
  # Look for the canonical signature: the "Edge runtime probe" polling string.
  # A project that stripped the retry will fail on transient cold-start 502s.
  if ! grep -q 'Edge runtime probe' "$CI_YML"; then
    findings+=("slow-job missing edge-runtime health-check retry pattern (lalista PR 26) — transient cold-start 502s will fail the run; restore the retry loop from /devshop/template/.github/workflows/ci.yml")
  fi

  # --- Check 4: empty-state hashFiles guards present (content-scoped) ---
  # Brand-new projects with no migrations / no e2e specs must short-circuit
  # the heavy steps via `if: hashFiles(<glob>) != ''`. Without these guards
  # the slow-job fails at the first heavy step on a content-less project.
  #
  # Scoped to content-MISSING: only raise the finding when the corresponding
  # content is absent — that's exactly when the unguarded step would crash.
  # Legacy projects that adopted slow-job pre-overhaul (lalista, home-os)
  # typically have content and work fine without the guards; flagging them
  # would be noise. The new template ships the guards as part of the
  # canonical shape so brand-new scaffolds pass on day one.
  if [ -z "$HAS_E2E" ] && ! grep -qE "if: hashFiles\('apps/web/e2e/\*\*/\*\.spec\.ts'\) != ''" "$CI_YML"; then
    findings+=("slow-job missing empty-state guard on Playwright steps — expected \`if: hashFiles('apps/web/e2e/**/*.spec.ts') != ''\` on Install Playwright / Build / Start+Run / Upload-traces. This project has no e2e specs yet, so the unguarded Playwright steps would crash the slow-job. Adopt the canonical shape from /devshop/template/.github/workflows/ci.yml. See conventions.md § Slow-Job Lifecycle § Per-step empty-state guards")
  fi
  HAS_MIGRATIONS="$(find "$PROJECT_ROOT/supabase/migrations" -maxdepth 1 -name '*.sql' -type f 2>/dev/null | head -1 || true)"
  if [ -z "$HAS_MIGRATIONS" ] && ! grep -qE "if: hashFiles\('supabase/migrations/\*\.sql'\) != ''" "$CI_YML"; then
    findings+=("slow-job missing empty-state guard on migration steps — expected \`if: hashFiles('supabase/migrations/*.sql') != ''\` on 'Schema type-drift check' + 'Migration rollback round-trip'. This project has no migrations yet, so the unguarded steps would crash on the missing-file check. Adopt the canonical shape from /devshop/template/.github/workflows/ci.yml. See conventions.md § Slow-Job Lifecycle § Per-step empty-state guards")
  fi

  # --- Check 4b: Start local Supabase has NO hashFiles guard (ambient signal) ---
  # The Start local Supabase step is intentionally unguarded — it's the
  # heartbeat that proves CI plumbing is wired even on empty projects. If a
  # future tidy-up PR adds a hashFiles guard to this step, brand-new projects
  # lose the ambient signal and slow-job activation regresses to operator-flip.
  START_LINE="$(grep -nE '^[[:space:]]+- name: Start local Supabase' "$CI_YML" | head -1 | cut -d: -f1 || true)"
  if [ -n "$START_LINE" ]; then
    NEXT_LINE=$((START_LINE + 1))
    if sed -n "${NEXT_LINE}p" "$CI_YML" | grep -qE 'if:[[:space:]]+hashFiles'; then
      findings+=("'Start local Supabase' step has a hashFiles guard — this step is the unconditional ambient health signal; gating it defeats the day-one-active design. Remove the if: line; see conventions.md § Slow-Job Lifecycle § Per-step empty-state guards")
    fi
  fi

  # --- Check 5: slow-job invokes the test glob that matches repo-resident files ---
  if [ -n "$HAS_INTEGRATION" ] && ! grep -qE '(test:integration|VITEST_INTEGRATION)' "$CI_YML"; then
    findings+=("repo has *.integration.test.ts files but slow-job doesn't invoke them (no 'test:integration' or 'VITEST_INTEGRATION=1') — active job will run zero integration tests")
  fi
  if [ -n "$HAS_E2E" ] && ! grep -qiE 'playwright' "$CI_YML"; then
    findings+=("repo has apps/*/e2e/*.spec.ts files but slow-job doesn't invoke playwright — active job will run zero E2E specs")
  fi

  # --- Check 6: skip-on-docs-only filter wired ---
  # The convention: a `changes:` setup-job classifies the diff and exposes
  # `runtime: 'true'/'false'` as a job output; the `slow:` job's `needs:`
  # includes `changes` and its `if:` references `needs.changes.outputs.runtime
  # == 'true'`. Both jobs ship active in the template; checks below catch a
  # silent reversion.
  CHANGES_LIVE=0
  if grep -qE '^[[:space:]]+changes:[[:space:]]*$' "$CI_YML"; then
    CHANGES_LIVE=1
  fi
  CHANGES_HAS_RUNTIME_OUTPUT=0
  if [ "$CHANGES_LIVE" = "1" ] && grep -qE '^[[:space:]]+runtime:[[:space:]]+\$\{\{[[:space:]]*steps\.[a-zA-Z0-9_-]+\.outputs\.runtime[[:space:]]*\}\}' "$CI_YML"; then
    CHANGES_HAS_RUNTIME_OUTPUT=1
  fi
  SLOW_NEEDS_CHANGES=0
  # Match either `needs: [fast, changes]` (list form, comma-separated) or a YAML
  # block list (`needs:\n  - fast\n  - changes`). `grep` doesn't span lines, so
  # check the inline-list form first; the block-list form fires the second branch.
  if grep -qE '^[[:space:]]+needs:[[:space:]]*\[[^]]*\bchanges\b[^]]*\]' "$CI_YML"; then
    SLOW_NEEDS_CHANGES=1
  elif awk '/^[[:space:]]+needs:[[:space:]]*$/{block=1; next} block && /^[[:space:]]+- /{if ($0 ~ /\bchanges\b/) found=1} block && /^[^[:space:]-]/{block=0} END{exit !found}' "$CI_YML"; then
    SLOW_NEEDS_CHANGES=1
  fi
  SLOW_IF_REFERENCES_RUNTIME=0
  if grep -qE 'needs\.changes\.outputs\.runtime' "$CI_YML"; then
    SLOW_IF_REFERENCES_RUNTIME=1
  fi

  if [ "$CHANGES_LIVE" = "0" ]; then
    findings+=("slow-job missing skip-on-docs-only filter — no active 'changes:' setup job in .github/workflows/ci.yml. Docs-only PRs will burn the 8-10 min slow-job; see kit/docs/guide/conventions.md § Slow-Job Lifecycle § Skip-on-docs-only filter for the canonical shape (changes: job + slow-job's needs/if wiring)")
  else
    if [ "$CHANGES_HAS_RUNTIME_OUTPUT" = "0" ]; then
      findings+=("'changes:' job present but missing 'runtime' output (expected 'runtime: \${{ steps.<id>.outputs.runtime }}'); slow-job's if-predicate will resolve to empty — see kit/docs/guide/conventions.md § Slow-Job Lifecycle § Skip-on-docs-only filter")
    fi
    if [ "$SLOW_NEEDS_CHANGES" = "0" ]; then
      findings+=("slow-job's 'needs:' does not include 'changes' — the changes: job runs but the slow-job doesn't depend on it; gating won't fire. Expected 'needs: [fast, changes]' (or block-list form). See kit/docs/guide/conventions.md § Slow-Job Lifecycle § Skip-on-docs-only filter")
    fi
    if [ "$SLOW_IF_REFERENCES_RUNTIME" = "0" ]; then
      findings+=("slow-job's 'if:' does not reference 'needs.changes.outputs.runtime' — the runtime gate is not wired and the slow-job will run on every PR regardless of diff. Expected 'if: github.event_name == \"pull_request\" && needs.changes.outputs.runtime == \"true\"'. See kit/docs/guide/conventions.md § Slow-Job Lifecycle § Skip-on-docs-only filter")
    fi
  fi
fi

# --- Check 7 (soft): branch protection on main includes 'slow' ---
# Uses the public `repos/{owner}/{repo}/branches/main` endpoint (works with
# standard read-scope PAT) rather than `repos/.../branches/main/protection`
# which requires admin. The branch endpoint embeds protection settings under
# `.protection.required_status_checks.contexts[]` — same data, lower scope.
#
# Endpoint choice is load-bearing: a previous version used the protection
# endpoint and got HTTP 403 for non-admin tokens; the error response was
# JSON with a `.message` field, my old logic saw it as non-empty and jq
# returned empty for `.contexts[]`, falsely flagging 'slow' as missing on
# correctly-configured projects (caught against meirmsn/lalista on
# 2026-04-27 — protection was correct, gate falsely reported a gap).
#
# `cd "$PROJECT_ROOT"` is load-bearing: gh resolves the repo from cwd, not
# from a path arg, so without the cd this check would target whatever repo
# the operator launched the gate from instead of the project being audited.
if [ "$SLOW_LIVE" = "1" ] && command -v gh >/dev/null 2>&1; then
  OWNER_REPO="$(cd "$PROJECT_ROOT" && gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
  if [ -n "$OWNER_REPO" ]; then
    BRANCH_JSON="$(cd "$PROJECT_ROOT" && gh api "repos/$OWNER_REPO/branches/main" 2>/dev/null || true)"
    if [ -n "$BRANCH_JSON" ] && echo "$BRANCH_JSON" | jq -e '.protection.required_status_checks' >/dev/null 2>&1; then
      # Look in both `.contexts[]` (older format, list of strings) and
      # `.checks[].context` (newer format, list of {context, app_id}) so the
      # check works regardless of which format the project's protection uses.
      if ! echo "$BRANCH_JSON" | jq -r '
        (.protection.required_status_checks.contexts // []) +
        (.protection.required_status_checks.checks // [] | map(.context))
        | .[]?
      ' 2>/dev/null | grep -qx 'slow'; then
        findings+=("branch protection on main does NOT include 'slow' as a required status check — PRs can merge red on the slow path; add via 'gh api repos/$OWNER_REPO/branches/main/protection' or the GitHub UI")
      fi
    fi
    # If gh api failed (no auth) OR returned a response without
    # `.protection.required_status_checks` (no protection configured yet, or
    # error response with `.message` only), don't add a finding — gracefully
    # degrade.
  fi
fi

if [ ${#findings[@]} -eq 0 ]; then
  echo "pass"
  exit 0
fi

echo "findings (${#findings[@]})"
for f in "${findings[@]}"; do
  echo "  - $f"
done
exit 0
