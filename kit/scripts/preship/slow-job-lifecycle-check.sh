#!/usr/bin/env bash
# What: Pre-ship gate that asserts the slow-job CI is correctly enabled when
#       the project ships integration tests or Playwright E2E specs. Catches
#       (a) commented-out slow-job stub past the threshold, (b) wrong if:
#       predicate, (c) stripped edge-runtime retry pattern, (d) missing branch
#       protection, (e) uncommented slow-job that runs zero tests.
# Why:  Once a project crosses the Phase 1c (integration tests) or Phase 1g
#       (Playwright E2E) threshold, the slow-job stub in .github/workflows/ci.yml
#       must be uncommented + branch protection updated. Maintenance is
#       operator-memory only without this gate; the lalista-PR-26 edge-runtime
#       retry pattern in particular doesn't propagate to next projects unless
#       the convention enforces it. See kit/docs/guide/conventions.md §
#       Slow-Job Lifecycle.
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

# Threshold detection: does the repo ship integration tests or Playwright E2E?
# An integration test is any *.integration.test.ts under packages/ or apps/.
# An E2E spec is any *.spec.ts under apps/web/e2e/ (or any apps/*/e2e/ in
# multi-app projects).
HAS_INTEGRATION="$(find "$PROJECT_ROOT/packages" "$PROJECT_ROOT/apps" -name '*.integration.test.ts' -type f 2>/dev/null | head -1 || true)"
HAS_E2E="$(find "$PROJECT_ROOT/apps" -path '*/e2e/*.spec.ts' -type f 2>/dev/null | head -1 || true)"

if [ -z "$HAS_INTEGRATION" ] && [ -z "$HAS_E2E" ]; then
  echo "n/a (no integration tests or E2E specs — Phase 1c/1g threshold not crossed)"
  exit 0
fi

findings=()

# --- Check 1: slow: job uncommented ---
# Commented form (template default): leading "  # slow:" (2sp + # + space + slow:)
# Uncommented form: leading "  slow:" (2sp + slow:)
SLOW_COMMENTED=0
SLOW_LIVE=0
if grep -qE '^[[:space:]]+#[[:space:]]*slow:' "$CI_YML"; then
  SLOW_COMMENTED=1
fi
if grep -qE '^[[:space:]]+slow:' "$CI_YML"; then
  SLOW_LIVE=1
fi

if [ "$SLOW_LIVE" = "0" ] && [ "$SLOW_COMMENTED" = "1" ]; then
  findings+=("slow-job is commented out in .github/workflows/ci.yml — uncomment per kit/docs/guide/conventions.md § Slow-Job Lifecycle § Uncommenting checklist")
elif [ "$SLOW_LIVE" = "0" ] && [ "$SLOW_COMMENTED" = "0" ]; then
  findings+=("slow-job not present in .github/workflows/ci.yml — add the slow: job (template stub at /devshop/template/.github/workflows/ci.yml is the reference)")
fi

# Subsequent checks only meaningful when slow: appears live.
if [ "$SLOW_LIVE" = "1" ]; then

  # --- Check 2: if: predicate is pull_request-only ---
  if ! grep -qE "if:[[:space:]]+github\.event_name[[:space:]]*==[[:space:]]*['\"]pull_request['\"]" "$CI_YML"; then
    findings+=("slow-job 'if:' predicate doesn't match canonical \`github.event_name == 'pull_request'\` shape — feature-branch pushes will burn slow-job CI minutes; see conventions.md § Slow-Job Lifecycle")
  fi

  # --- Check 3: edge-runtime health-check retry pattern wired ---
  # Look for the canonical signature: the "Edge runtime probe" polling string
  # appears in both the template's commented stub (function name
  # `start_supabase`) and lalista's live shape (function name
  # `probe_edge_runtime`) — different names, same retry semantics. Match the
  # phrase, not the function. A project that uncommented but stripped the
  # retry will fail on transient cold-start 502s.
  if ! grep -q 'Edge runtime probe' "$CI_YML"; then
    findings+=("slow-job missing edge-runtime health-check retry pattern (lalista PR 26) — transient cold-start 502s will fail the run; restore the retry loop from /devshop/template/.github/workflows/ci.yml")
  fi

  # --- Check 5: slow-job invokes the test glob that matches repo-resident files ---
  if [ -n "$HAS_INTEGRATION" ] && ! grep -qE '(test:integration|VITEST_INTEGRATION)' "$CI_YML"; then
    findings+=("repo has *.integration.test.ts files but slow-job doesn't invoke them (no 'test:integration' or 'VITEST_INTEGRATION=1') — uncommented job will run zero integration tests")
  fi
  if [ -n "$HAS_E2E" ] && ! grep -qiE 'playwright' "$CI_YML"; then
    findings+=("repo has apps/*/e2e/*.spec.ts files but slow-job doesn't invoke playwright — uncommented job will run zero E2E specs")
  fi

  # --- Check 6: skip-on-docs-only filter wired (D3 of slow-job-skip-on-docs-only) ---
  # The convention is: a `changes:` setup-job classifies the diff and exposes
  # `runtime: 'true'/'false'` as a job output; the `slow:` job's `needs:` includes
  # `changes` and its `if:` references `needs.changes.outputs.runtime == 'true'`.
  # Once the slow-job is uncommented (SLOW_LIVE=1), all four sub-asserts must hold
  # — otherwise docs-only PRs burn the 8-10 min slow-job needlessly. Without this
  # check, the convention propagates to new projects via the template stub but
  # degrades to operator-memory once the slow-job is uncommented.
  #
  # We ONLY look for the live (uncommented) `changes:` job + wiring — the template
  # ships them all commented, and the existing Check 1 already enforces that the
  # slow-job is uncommented when SLOW_LIVE=1; the same uncomment-both ritual
  # applies to changes:.
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
    findings+=("slow-job missing skip-on-docs-only filter — no live 'changes:' setup job in .github/workflows/ci.yml. Docs-only PRs will burn the 8-10 min slow-job; see kit/docs/guide/conventions.md § Slow-Job Lifecycle § Skip-on-docs-only filter for the canonical shape (changes: job + slow-job's needs/if wiring)")
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

# --- Check 4 (soft): branch protection on main includes 'slow' ---
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
    # degrade. The operator will see it on the next gh-authed run against
    # a protected repo.
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
