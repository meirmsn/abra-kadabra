#!/bin/bash
# Adversarial review of bypass reasons.
# Shared engine for all commit guard checks. Each caller passes a check type;
# this script gathers context, spawns a Sonnet agent to judge the reason,
# and returns PASS (exit 0) or FAIL (exit 1).
#
# Callers: devshop-commit-guard.sh, check-clean-tree.sh, check-hook-bypass.sh,
#          .husky/pre-push (prDescStaleReason, dirtyPushReason)
#
# Usage: adversarial-review.sh <check-type> <reason> [context...]
#   check-type: docsVerified | docSyncReason | dirtyTreeReason | hookBypass
#               | manifestReviewed | testCoverage | prDescStaleReason | dirtyPushReason
#               | dismissalLog   (pre-ship /ak-pre-ship — reviews gate dismissal rationales)
#   reason: the bypass reason provided via git -c, OR for dismissalLog the body of the
#           `## Dismissals` section of the gate's review.md entry
#   context: additional context (piped or as arguments)
#     dismissalLog: $1 = gate name, $2 = path to review.md
#
# Env overrides:
#   DEVSHOP_SKIP_ADVERSARIAL=1         — bypass review entirely (dev-loop escape hatch;
#                                        never set in CI or release)
#   PRESHIP_ADVERSARIAL_TIMEOUT=<sec>  — per-call timeout for pre-ship dismissalLog
#                                        reviews (default 120s; other check-types 90s)
#
# Convention-inlining: per check-type (and gate-name for dismissalLog), this
# script appends relevant sections of `kit/docs/guide/conventions.md` to the
# reviewer's context block via the CONVENTIONS_TO_INCLUDE map below. The
# reviewer judges convention adherence in addition to the bypass-reason
# semantics. Add new mappings to expand convention enforcement coverage.
#
# Exit 0 = accepted, exit 1 = rejected (reason on stdout)
set -euo pipefail

CHECK_TYPE="${1:-unknown}"
REASON="${2:-no reason given}"
shift 2 || true

# Capture GATE_NAME early so the convention-inlining block (after the case
# statement) can use it for dismissalLog routing. Only meaningful for
# dismissalLog; harmless empty for other check types.
GATE_NAME="${1:-}"

# Gather context based on check type
CONTEXT=""
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

case "$CHECK_TYPE" in
  docsVerified)
    DIFF=$(git diff --cached --stat 2>/dev/null || true)
    DIFF_FULL=$(git diff --cached 2>/dev/null | head -300 || true)
    GUIDE_HEADERS=$(for f in "$GIT_ROOT"/kit/docs/guide/*.md; do echo "--- $(basename "$f") ---"; grep -n '^##' "$f" 2>/dev/null | head -20; done || true)
    README_MD=$(cat "$GIT_ROOT/kit/docs/OVERVIEW.md" 2>/dev/null || true)
    CLAUDE_MD=$(cat "$GIT_ROOT/CLAUDE.md" 2>/dev/null | head -100 || true)
    FAQ_HEADERS=$(grep -n '^##' "$GIT_ROOT/kit/docs/FAQ.md" 2>/dev/null | head -30 || true)
    MODEL_MD=$(cat "$GIT_ROOT/kit/docs/MODEL.md" 2>/dev/null || true)
    PROJECT_CLAUDE=$(cat "/workspace/CLAUDE.md" 2>/dev/null | head -100 || true)
    PROJECT_README=$(cat "$GIT_ROOT/README.md" 2>/dev/null | head -60 || true)
    CONTEXT="Staged diff summary:
$DIFF

Staged diff (first 300 lines):
$DIFF_FULL

=== CLAUDE.md (devshop) (first 100 lines) ===
$CLAUDE_MD

=== kit/docs/MODEL.md ===
$MODEL_MD

=== kit/docs/OVERVIEW.md ===
$README_MD

=== kit/docs/guide/ section headers ===
$GUIDE_HEADERS

=== kit/docs/FAQ.md section headers ===
$FAQ_HEADERS

=== CLAUDE.md (project) (first 100 lines) ===
$PROJECT_CLAUDE

=== README.md (first 60 lines) ===
$PROJECT_README

The reviewer MUST have checked ALL of these docs — not just the ones that already mention the changed code. New functionality needs to be documented for the first time."
    ;;
  docSyncReason)
    DIFF=$(git diff --cached -- CLAUDE.md kit/docs/OVERVIEW.md kit/docs/guide/ 2>/dev/null | head -300 || true)
    README_MD=$(cat "$GIT_ROOT/kit/docs/OVERVIEW.md" 2>/dev/null || true)
    CLAUDE_MD=$(cat "$GIT_ROOT/CLAUDE.md" 2>/dev/null || true)
    GUIDE_HEADERS=$(for f in "$GIT_ROOT"/kit/docs/guide/*.md; do echo "--- $(basename "$f") ---"; grep -n '^##' "$f" 2>/dev/null | head -20; done || true)
    CONTEXT="Doc changes (first 300 lines):
$DIFF

=== CLAUDE.md (devshop) ===
$CLAUDE_MD

=== kit/docs/OVERVIEW.md ===
$README_MD

=== kit/docs/guide/ section headers ===
$GUIDE_HEADERS"
    ;;
  dirtyTreeReason)
    DIRTY=$(git status --porcelain 2>/dev/null | grep -E '^\?\?|^ [MD]' | head -20 || true)
    BRANCH=$(git branch --show-current 2>/dev/null || true)
    STASHED=$(git stash list 2>/dev/null | grep -Fi "on $BRANCH:" | head -5 || true)
    CONTEXT="Untracked/unstaged files:
$DIRTY

Stashed changes on current branch ($BRANCH):
${STASHED:-(none)}"
    ;;
  hookBypass)
    STAGED=$(git diff --cached --stat 2>/dev/null || true)
    CONTEXT="The developer wants to commit with --no-verify, skipping ALL pre-commit hooks:
- lint-staged (ESLint + Prettier)
- typecheck (TypeScript)
- gitleaks (secret scanning)
- devshop commit guard (mixed commits, docs drift)

Staged files:
$STAGED"
    ;;
  manifestReviewed)
    CONTEXT="Template file additions/removals vs manifest.txt.
The developer proposes how to handle manifest updates.

Reason: $REASON"
    ;;
  testCoverage)
    # Context is passed as $REASON (contains diff + test content)
    # No additional context gathering needed — release.sh provides everything
    CONTEXT="$REASON"
    ;;
  prDescStaleReason)
    # Called by .husky/pre-push. Gathers PR title/body vs commits on branch.
    BRANCH=$(git branch --show-current 2>/dev/null || true)
    PR_NUM=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number // empty' 2>/dev/null || true)

    if [ -z "$PR_NUM" ]; then
      # Shouldn't happen — pre-push checks for PR existence before invoking — but fail safe.
      CONTEXT="No open PR for branch $BRANCH. This check should not have been invoked."
    else
      PR_DATA=$(gh pr view "$PR_NUM" --json title,body 2>/dev/null || echo "{}")
      PR_TITLE=$(echo "$PR_DATA" | jq -r '.title // "(no title)"')
      PR_BODY=$(echo "$PR_DATA" | jq -r '.body // ""' | head -25)
      # All commits in the branch relative to main — this is what reviewers see in the PR.
      COMMITS=$(git log --oneline origin/main..HEAD 2>/dev/null | head -30 || true)
      COMMIT_COUNT=$(echo "$COMMITS" | grep -c . 2>/dev/null || echo 0)
      CONTEXT="PR #$PR_NUM on branch $BRANCH (${COMMIT_COUNT} commits ahead of main).

Current PR title:
$PR_TITLE

Current PR body (first 25 lines):
$PR_BODY

All commits on this branch (origin/main..HEAD, first 30):
$COMMITS"
    fi
    ;;
  dirtyPushReason)
    # Called by .husky/pre-push. Gathers dirty tree + stash snapshot.
    DIRTY=$(git status --porcelain 2>/dev/null | head -20 || true)
    BRANCH=$(git branch --show-current 2>/dev/null || true)
    STASH_LIST=$(git stash list 2>/dev/null | head -5 || true)
    STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    CONTEXT="Pushing branch $BRANCH with non-clean local state.

Dirty files (git status --porcelain, first 20):
${DIRTY:-(none)}

Stash entries (${STASH_COUNT} total, first 5):
${STASH_LIST:-(none)}"
    ;;
  dismissalLog)
    # Called by /ak-pre-ship's router shim. REASON is the `## Dismissals` section
    # body (the rationales the gate gave for not acting on findings). Extra args:
    #   $1 = gate name (e.g. "qa", "design-review") — already captured into GATE_NAME above
    #   $2 = path to the gate's review.md (for full section context)
    [ -z "$GATE_NAME" ] && GATE_NAME="unknown-gate"
    GATE_REPORT_PATH="${2:-}"

    # Extract this gate's section from review.md for fuller context
    GATE_SECTION=""
    if [ -n "$GATE_REPORT_PATH" ] && [ -f "$GATE_REPORT_PATH" ]; then
      GATE_SECTION=$(awk -v gn="$GATE_NAME" '
        $0 ~ ("^## Gate .*" gn) && !in_s { in_s=1; print; next }
        in_s && /^## Gate / { exit }
        in_s && /^## Router Summary/ { exit }
        in_s { print }
      ' "$GATE_REPORT_PATH" | head -150)
    fi

    # Spec § In scope (what's on the menu for this PR) — helps reviewer judge
    # "dismissed as out-of-scope" claims against the actual scope declaration.
    FEATURE_DIR=$(dirname "$GATE_REPORT_PATH" 2>/dev/null || true)
    SPEC_IN_SCOPE=""
    SPEC_CORE_STORY=""
    if [ -n "$FEATURE_DIR" ] && [ -f "$FEATURE_DIR/spec.md" ]; then
      SPEC_IN_SCOPE=$(awk '/^## In scope/{f=1;next} f && /^## /{exit} f' \
        "$FEATURE_DIR/spec.md" 2>/dev/null | head -80)
      SPEC_CORE_STORY=$(awk '/^## Core user story/{f=1;next} f && /^## /{exit} f' \
        "$FEATURE_DIR/spec.md" 2>/dev/null | head -30)
    fi

    CONTEXT="Gate under review: $GATE_NAME

The gate surfaced findings and dismissed some with rationale rather than fixing them
or escalating to findings (N) pending. Judge whether those dismissals are credible.

=== Dismissals section body (the reason being audited) ===
$REASON

=== Full gate section from review.md ===
${GATE_SECTION:-(not available — no review.md path passed)}

=== Spec § Core user story (MUST NOT be dismissed) ===
${SPEC_CORE_STORY:-(not declared — spec lacks Core user story section)}

=== Spec § In scope (what's committed for this PR) ===
${SPEC_IN_SCOPE:-(not available)}"
    ;;
esac

# --- Convention inlining (CONVENTIONS_TO_INCLUDE map) ---
# Append relevant sections of `kit/docs/guide/conventions.md` to CONTEXT so the
# reviewer can judge convention adherence (not just bypass-reason semantics).
# Mapping is (CHECK_TYPE [+ GATE_NAME for dismissalLog]) → pipe-separated list
# of `## <heading>` names from conventions.md.
#
# Extend this map when a new convention warrants commit-time enforcement. The
# `## ` heading must match conventions.md exactly (spaces, capitalization).
extract_convention_section() {
  local file="$1"
  local heading="$2"
  awk -v h="$heading" '
    $0 == ("## " h) { in_s=1; print; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$file"
}

# Returns pipe-separated list of section names to inline, or empty if none.
get_conventions_to_inline() {
  local check_type="$1"
  local gate_name="${2:-}"
  case "$check_type" in
    testCoverage)
      echo "Non-Negotiables"
      ;;
    docsVerified)
      echo "Backlog Routing Guide"
      ;;
    dismissalLog)
      case "$gate_name" in
        qa)                 echo "Non-Negotiables" ;;
        test-review)        echo "Wrapper API design" ;;
        design-review)      echo "DESIGN.md as Contract|Screenshot Routing" ;;
        cso|rls-coverage)   echo "Supabase Hardening Defaults" ;;
        slow-job-lifecycle) echo "Slow-Job Lifecycle" ;;
        review)             echo "Backlog Routing Guide" ;;
        metrics-check)      echo "Metrics Lifecycle" ;;
        *)                  echo "" ;;
      esac
      ;;
    *)
      echo ""
      ;;
  esac
}

CONVENTIONS_FILE="$GIT_ROOT/kit/docs/guide/conventions.md"
SECTIONS_TO_INCLUDE=$(get_conventions_to_inline "$CHECK_TYPE" "$GATE_NAME")
if [ -n "$SECTIONS_TO_INCLUDE" ] && [ -f "$CONVENTIONS_FILE" ]; then
  INLINED_CONVENTIONS=""
  IFS='|' read -ra SECTIONS_ARR <<< "$SECTIONS_TO_INCLUDE"
  for section in "${SECTIONS_ARR[@]}"; do
    body=$(extract_convention_section "$CONVENTIONS_FILE" "$section")
    if [ -n "$body" ]; then
      INLINED_CONVENTIONS+="
$body
"
    fi
  done
  if [ -n "$INLINED_CONVENTIONS" ]; then
    CONTEXT="$CONTEXT

=== Relevant conventions (kit/docs/guide/conventions.md) ===
The diff / dismissal must be consistent with the rules below. A change that
violates an explicit rule should fail unless the bypass reason explicitly
justifies the deviation against the rule's stated rationale.
$INLINED_CONVENTIONS"
  fi
fi

# --- Devshop-wide adversarial review bypass (tight iteration loops) ---
# Active-human-review escape hatch for pre-ship dismissalLog calls that cascade
# across many gates. NEVER set in CI or release — this is a dev-loop convenience.
if [ "${DEVSHOP_SKIP_ADVERSARIAL:-0}" = "1" ]; then
  echo "✓ Adversarial review bypassed via DEVSHOP_SKIP_ADVERSARIAL=1"
  exit 0
fi

# --- Pre-ship vs commit-guard timeout budgeting ---
# Commit-guard calls one adversarial review per commit; 90s is comfortable.
# Pre-ship can fire up to 11 reviews (one per gate with dismissals); bump the
# per-call timeout so individual gates with dense context don't time out.
COMMIT_TIMEOUT=90
PRESHIP_TIMEOUT="${PRESHIP_ADVERSARIAL_TIMEOUT:-120}"
if [ "$CHECK_TYPE" = "dismissalLog" ]; then
  TIMEOUT=$PRESHIP_TIMEOUT
else
  TIMEOUT=$COMMIT_TIMEOUT
fi

# --- Human review fallback (when API is unavailable) ---
# devshop.humanReviewed is blocked by PreToolUse hook for Claude —
# only reachable when human runs git commit directly in terminal.
HUMAN_REVIEW=$(git config --get devshop.humanReviewed 2>/dev/null || true)
if [ -n "$HUMAN_REVIEW" ]; then
  echo "✓ Human-reviewed: $HUMAN_REVIEW"
  exit 0
fi

# Spawn adversarial review
PROMPT="You are a commit guard auditor. Your default position is to REJECT bypass reasons. Be strict.

A developer is committing code and provided a reason to skip a commit guard check.

Check type: $CHECK_TYPE
Reason given: $REASON

Context:
$CONTEXT

Evaluate:
1. Is the stated reason factually accurate given the context?
2. Does skipping this check create a real risk (stale docs, forgotten files, missed changes, leaked secrets)?
3. Is the reason specific enough? Generic reasons like 'docs are fine' or 'will fix later' are NOT acceptable.
4. For doc checks: does the reason name specific sections reviewed? Do those sections actually match the changes?
5. For testCoverage checks: judge whether existing tests are sufficient to catch regressions in any functional changes since the last release. Look for: new code paths without corresponding test cases, changed exit codes or output formats not verified by assertions, new flags or options not exercised. PASS when any of: (a) changes are purely cosmetic (comments, formatting, variable renames); (b) no functional changes at all (docs-only release — README, CLAUDE.md, kit/docs/, kit/notes/); (c) config-only changes (devcontainer env vars, gitignore entries, image versions) already validated by wiring tests in structural-invariants.bats — name the specific wiring test you verified exists; (d) existing tests already exercise the changed behavior — name the specific test.
6. For doc checks: if the diff introduces a NEW capability (new script category, new workflow, new convention, new tool), verify documentation exists at the right level:
   - guide/ section required: what it is, how it works, how to extend it (e.g., conventions.md for testing strategy, hooks.md for new guards)
   - OVERVIEW.md if it changes the workspace layout, event flow, or file map
   - MODEL.md if it adds a new structural component to the kit (rare)
   - CLAUDE.md if it changes how Claude should behave or what workflows to follow
   Layout mentions alone (a line in a tree diagram) are NOT sufficient for new capabilities — strategy/usage docs are also required.
7. For hookBypass: is this a known legitimate scenario (migration commits with git rm --cached, binary files that break lint-staged, intermediate refactor state with type errors)? Does skipping gitleaks create a real risk for these files?
8. For prDescStaleReason: does the PR title/body accurately describe ALL commits on the branch (origin/main..HEAD)? If the commits add a new capability, the PR description should name it. Generic reasons ('WIP', 'will update later', 'fine for now') are NOT acceptable. A PASS requires either (a) the PR description genuinely matches the commits — the reviewer is wrong — or (b) a specific structural reason the description lags temporarily (e.g., 'batching rebases — will squash-update after final review' with a concrete next step).
9. For dirtyPushReason: does the reason name WHICH files are intentionally dirty and WHY? Generic reasons ('whatever', 'local only', 'does not matter') are NOT acceptable. PASS requires specificity: 'untracked *.log debug files from local testing, not project code' or 'stashed branch X changes to push unrelated branch Y — will resume after'. Forgotten WIP (files the developer doesn't recognize) should FAIL.
10. For dismissalLog: the Reason is the body of a gate's '## Dismissals' section — the rationales given for NOT acting on specific findings. Judge each dismissal bullet individually. REJECT the whole bypass if ANY bullet exhibits:
    - Generic rationale: 'not critical', 'minor', 'can wait', 'won't fix for now' without specifics
    - Contradicts the spec's § Core user story: dismissing a bug that affects a verb in the core story is categorically NOT acceptable (the core story names the product's load-bearing flow — dismissals must not touch it)
    - Claims 'out of scope for this PR' when the spec's § In scope explicitly covers that behavior
    - Missing rationale field entirely (a bullet that just names a finding without explaining the dismissal)
    - Punts to 'TODOS' or 'follow-up' without a specific tag, issue number, or existing entry to point at
    - Claims 'user-acceptable' or 'product decision' without attributing to a specific approved spec line or design doc
    PASS only when every rationale is: specific (names what was considered and why deferred), consistent with the PR scope (doesn't cross the core user story, doesn't dismiss committed scope), and actionable (a later reviewer could find the rationale plausible given the evidence).
11. **Convention adherence** (when '=== Relevant conventions ===' appears in the context): the diff/dismissal must follow the inlined conventions. A change that violates an explicit rule (e.g. a new wrapper without onError when § Wrapper API design requires it; a dismissal that punts on an RLS-coverage finding when § Supabase Hardening Defaults marks it non-negotiable; a slow-job stripped of the edge-runtime retry when § Slow-Job Lifecycle's checklist requires it) must FAIL unless the reason explicitly engages the rule's stated rationale. Generic 'this convention doesn't apply here' WITHOUT naming why is NOT acceptable.

Respond with EXACTLY one line:
PASS - only if the reason is genuinely legitimate and specific
FAIL: <what is wrong with the reason or what was missed>"

# Write prompt to temp file to avoid argument length limits
PROMPT_FILE=$(mktemp)
echo "$PROMPT" > "$PROMPT_FILE"

REVIEW=""
BACKOFF_DELAYS=(15 60)
ATTEMPT=0
MAX_ATTEMPTS=$(( ${#BACKOFF_DELAYS[@]} + 1 ))

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  REVIEW=$(timeout "$TIMEOUT" claude -p --model sonnet < "$PROMPT_FILE" 2>/dev/null) && break
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
    DELAY=${BACKOFF_DELAYS[$((ATTEMPT - 1))]}
    echo "⚠ Adversarial review attempt $ATTEMPT failed. Retrying in ${DELAY}s..."
    sleep "$DELAY"
  fi
done

if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
  rm -f "$PROMPT_FILE"
  echo "⚠ Adversarial review API unavailable after $MAX_ATTEMPTS attempts. Manual review required."
  echo ""
  echo "  Check type: $CHECK_TYPE"
  echo "  Bypass reason: $REASON"
  echo ""
  echo "  Context:"
  echo "$CONTEXT" | head -30 | sed 's/^/    /'
  echo ""
  echo "  To approve as human reviewer, run directly in the terminal:"
  echo "    ! git -c devshop.humanReviewed=\"approve: <your assessment>\" commit ..."
  exit 1
fi
rm -f "$PROMPT_FILE"

if echo "$REVIEW" | grep -qi "^FAIL"; then
  echo "$REVIEW"
  exit 1
fi

exit 0
