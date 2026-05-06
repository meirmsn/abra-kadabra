#!/bin/bash
# Adversarial review of bypass reasons.
# Shared engine for all commit guard checks. Each caller passes a check type;
# this script gathers context, spawns a Sonnet agent to judge the reason,
# and returns PASS (exit 0) or FAIL (exit 1).
#
# Callers: devshop-commit-guard.sh, check-clean-tree.sh, check-hook-bypass.sh,
#          .husky/pre-push (prDescStaleReason, dirtyPushReason),
#          /ak-build Phase 5.8 (testReviewSkipReason — post-pre-ship coverage halt override)
#
# Usage: adversarial-review.sh <check-type> <reason> [context...]
#   check-type: docsReviewed | dirtyTreeReason | hookBypass
#               | manifestReviewed | testCoverage | prDescStaleReason | dirtyPushReason
#               | testCoverageProject | exemptAddition  (project-repo gates)
#               | testReviewSkipReason  (/ak-build Phase 5.8 halt override)
#               | dismissalLog   (pre-ship /ak-pre-ship — reviews gate dismissal rationales)
#
# `docsReviewed` is the unified docs-coverage check for both repos: it branches
# internally on $GIT_ROOT (/devshop reads devshop docs; /workspace reads project
# docs). Same prompt rules apply to both surfaces; only the inlined doc set
# differs. (Replaced the former separate `docsFreshnessProject` check-type
# 2026-05-01 — see kit/notes/roadmap/adversarial-review-doc-inlining.md.)
#   reason: the bypass reason provided via git -c, OR for dismissalLog the body of the
#           `## Dismissals` section of the gate's review.md entry
#   context: additional context (piped or as arguments)
#     dismissalLog: $1 = gate name, $2 = path to review.md
#
# Env overrides:
#   DEVSHOP_SKIP_ADVERSARIAL=1            — bypass review entirely (dev-loop escape hatch;
#                                           never set in CI or release)
#   DEVSHOP_ADVERSARIAL_MODEL_OVERRIDE=X  — force a specific model (haiku|sonnet) for
#                                           all check-types in this invocation. Use
#                                           when an operator wants to upgrade a
#                                           normally-Haiku check for a high-stakes
#                                           commit. Default routing is per check-type
#                                           (see get_model_for_check_type below).
#   PRESHIP_ADVERSARIAL_TIMEOUT=<sec>     — per-call timeout for pre-ship dismissalLog
#                                           reviews (default 120s; other check-types 180s)
#
# Per-check-type model routing (Haiku 4.5 for deterministic rule-application,
# Sonnet 4.6 for judgment-heavy or high-blast-radius checks):
#   Haiku:  dirtyTreeReason, dirtyPushReason, manifestReviewed
#   Sonnet: docsReviewed, prDescStaleReason, testCoverage, testReviewSkipReason, dismissalLog, hookBypass, exemptAddition
# Rationale: docs feed future sessions (errors compound), PR descriptions are the
# canonical reviewer-facing record, hookBypass can leak secrets via gitleaks bypass,
# testCoverage requires code-semantics judgment, dismissalLog weighs spec scope.
# Dirty-tree / manifest checks are pure rule-application (does the reason name
# specific files? does the manifest decision reasoning hold?).
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

# Repo-mode detection (devshop vs project) — used by docsReviewed to pick the
# right inlined catalog and by get_conventions_to_inline to pick the right
# convention sections. Same heuristic as commit-guard.sh: a real `kit/` dir at
# the repo root means devshop-self mode (works for both /devshop and bats
# sandboxes). Otherwise treat as project repo.
if [ "$GIT_ROOT" = "/devshop" ] || { [ -n "$GIT_ROOT" ] && [ -d "$GIT_ROOT/kit" ] && [ ! -L "$GIT_ROOT/kit" ]; }; then
  REPO_MODE=devshop
else
  REPO_MODE=project
fi

case "$CHECK_TYPE" in
  docsReviewed)
    # Unified docs-coverage check for both repos. Branches on $GIT_ROOT to load
    # the right doc set. Same prompt rules apply to both surfaces — only the
    # inlined catalog differs. The reviewer judges: (a) per-doc enumeration of
    # the inlined catalog, (b) cross-file coherence when reference docs are
    # staged, (c) new-capability docs at the right level, (d) rename/delete
    # drift sweep, (e) addition drift sweep.
    DIFF=$(git diff --cached --stat 2>/dev/null || true)
    DIFF_FULL=$(git diff --cached 2>/dev/null | head -300 || true)
    # Surface renames + deletions explicitly so the reviewer can grep the doc
    # set for stale references to the old names. -M enables rename detection;
    # diff-filter=DR yields Deleted + Renamed entries with the old path on
    # the LHS. Each line is "<status>\t<old-path>[\t<new-path>]".
    RENAMED_DELETED=$(git diff --cached --name-status --diff-filter=DR -M 2>/dev/null || true)
    RENAMED_DELETED_NOTE="${RENAMED_DELETED:-(none — no files renamed, moved, or deleted in this commit)}"

    case "$REPO_MODE" in
      devshop)
        # Devshop-side catalog. Top-level orientation docs FULL (CLAUDE.md,
        # OVERVIEW.md with § Concept, README.md); guide/ + FAQ.md flat-catalog
        # headers. Selective full-body expansion for guide/* via the
        # GUIDES_TO_INCLUDE map below (keyed on staged paths).
        CLAUDE_MD=$(cat "$GIT_ROOT/CLAUDE.md" 2>/dev/null || true)
        OVERVIEW_MD=$(cat "$GIT_ROOT/kit/docs/OVERVIEW.md" 2>/dev/null || true)
        README_MD=$(cat "$GIT_ROOT/README.md" 2>/dev/null || true)
        GUIDE_HEADERS=$(for f in "$GIT_ROOT"/kit/docs/guide/*.md; do echo "--- $(basename "$f") ---"; grep -n '^##' "$f" 2>/dev/null | head -20; done || true)
        FAQ_HEADERS=$(grep -n '^##' "$GIT_ROOT/kit/docs/FAQ.md" 2>/dev/null | head -30 || true)
        REFERENCE_DOCS_STAGED=$(git diff --cached --name-only 2>/dev/null | grep -E '^(CLAUDE\.md$|kit/docs/(OVERVIEW|FAQ)\.md$|kit/docs/guide/)' || true)
        REFERENCE_DOCS_STAGED_NOTE="${REFERENCE_DOCS_STAGED:-(none — only non-reference devshop files staged; cross-file coherence rule does not apply)}"
        CONTEXT="Repo: devshop (/devshop)

Staged diff summary:
$DIFF

Staged diff (first 300 lines):
$DIFF_FULL

Renamed/moved/deleted in this commit (status<TAB>old-path[<TAB>new-path]):
$RENAMED_DELETED_NOTE

Reference docs staged in this commit:
$REFERENCE_DOCS_STAGED_NOTE

=== CLAUDE.md (devshop, FULL) ===
$CLAUDE_MD

=== kit/docs/OVERVIEW.md (FULL — incl. § Concept) ===
$OVERVIEW_MD

=== README.md (FULL) ===
$README_MD

=== kit/docs/guide/ section headers ===
$GUIDE_HEADERS

=== kit/docs/FAQ.md section headers ===
$FAQ_HEADERS

The reviewer MUST have checked ALL of these docs — not just the ones that already mention the changed code. New functionality needs to be documented for the first time. When reference docs ARE staged (see 'Reference docs staged' above), the reviewer must additionally attest cross-file coherence — staged doc changes must leave the doc set internally consistent."
        ;;
      project)
        # Project-side catalog. Top-level orientation docs FULL (CLAUDE.md,
        # METRICS.md, OVERVIEW.md, ARCHITECTURE.md); per-package READMEs FULL
        # (apps/<x>/, packages/<x>/, supabase/functions/). OVERVIEW.md and
        # ARCHITECTURE.md are opt-in — the trigger only fires when present at
        # HEAD; if absent, the inline shows "(not present)".
        CLAUDE_MD=$(cat "$GIT_ROOT/CLAUDE.md" 2>/dev/null || true)
        METRICS_MD=$(cat "$GIT_ROOT/METRICS.md" 2>/dev/null || true)
        OVERVIEW_MD=$(cat "$GIT_ROOT/OVERVIEW.md" 2>/dev/null || true)
        ARCHITECTURE_MD=$(cat "$GIT_ROOT/ARCHITECTURE.md" 2>/dev/null || true)
        PER_PACKAGE_READMES=""
        while IFS= read -r readme; do
          [ -z "$readme" ] && continue
          rel="${readme#$GIT_ROOT/}"
          body=$(cat "$readme" 2>/dev/null || true)
          PER_PACKAGE_READMES+="
=== $rel (FULL) ===
$body
"
        done < <(find "$GIT_ROOT/apps" "$GIT_ROOT/packages" "$GIT_ROOT/supabase/functions" \
          -maxdepth 3 -name README.md -type f 2>/dev/null | sort)
        REFERENCE_DOCS_STAGED=$(git diff --cached --name-only 2>/dev/null | grep -E '^(CLAUDE|METRICS|OVERVIEW|ARCHITECTURE)\.md$|^(apps|packages|supabase/functions)/[^/]+/README\.md$|^supabase/functions/README\.md$' || true)
        REFERENCE_DOCS_STAGED_NOTE="${REFERENCE_DOCS_STAGED:-(none — only non-reference project files staged; cross-file coherence rule does not apply)}"
        CONTEXT="Repo: project (/workspace)

$REASON

Staged diff summary:
$DIFF

Staged diff (first 300 lines):
$DIFF_FULL

Renamed/moved/deleted in this commit (status<TAB>old-path[<TAB>new-path]):
$RENAMED_DELETED_NOTE

Reference docs staged in this commit:
$REFERENCE_DOCS_STAGED_NOTE

=== CLAUDE.md (project, FULL) ===
${CLAUDE_MD:-(missing — fail open since the file the hook expects to be updated does not exist; flag this in your review)}

=== METRICS.md (FULL) ===
${METRICS_MD:-(missing — fail open similarly)}

=== OVERVIEW.md (FULL) ===
${OVERVIEW_MD:-(not present — opt-in doc; trigger does not fire if absent)}

=== ARCHITECTURE.md (FULL) ===
${ARCHITECTURE_MD:-(not present — opt-in doc; trigger does not fire if absent)}
${PER_PACKAGE_READMES:-
=== Per-package READMEs ===
(none present at HEAD under apps/, packages/, or supabase/functions/ — opt-in; triggers do not fire when absent)
}

CLAUDE.md § Where Things Happen names load-bearing surfaces — dismissals that touch them face a higher bar. The reviewer MUST have checked ALL inlined docs — not just the ones that already mention the changed code. New surfaces need to be documented for the first time. When reference docs ARE staged (see 'Reference docs staged' above), the reviewer must additionally attest cross-file coherence."
        ;;
    esac
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
  testCoverageProject)
    # Project-repo test-presence bypass review. REASON contains the developer's
    # justification AND the hook's own block summary + staged diff (built by
    # check-test-coverage-project.sh, since that hook has the cleanest view of
    # which paths were blocked and why).
    CONTEXT="$REASON"
    ;;
  exemptAddition)
    # Project-repo exempt-file addition review. REASON contains the staged
    # additions to .devshop-test-coverage-exempt / .devshop-docs-freshness-exempt
    # and the list of cited paths verified to exist on disk (built by
    # check-exempt-additions.sh). The reviewer judges per-entry specificity of
    # the inline `# reason` after each path. The pre-flight in the caller has
    # already proven that any cited file paths exist — the reviewer's job is
    # specificity, not file-existence.
    CONTEXT="$REASON"
    ;;
  testReviewSkipReason)
    # Called by /ak-build Phase 5.8 when the user has set
    # `git config devshop.testReviewSkipReason "..."` to override a halt on
    # high-severity findings from the post-pre-ship docs + tests re-audit.
    # The reviewer judges whether the override is load-bearing against the
    # actual findings — not against a generic "tests look fine" claim.
    #
    # Post-PR-B: findings live in specs/<feature>/review.md as appended
    # `## Audit N` sections (collapsed two-file model — no separate
    # test-review-followup.md). The latest `## Audit N` section is the
    # one whose halt is being overridden; harvest it from there.
    BRANCH=$(git branch --show-current 2>/dev/null || true)
    FEATURE=$(echo "$BRANCH" | sed 's|^feature/||;s|^feat/||;s|^fix/||')
    REVIEW="specs/$FEATURE/review.md"
    if [ -f "$REVIEW" ]; then
      # First confirm there's at least one `## Audit N` header — if not, the
      # awk slice below would silently yield the whole file, which would
      # mask the missing-audit case.
      AUDIT_COUNT=$(grep -cE '^## Audit [0-9]+' "$REVIEW" 2>/dev/null || echo 0)
      if [ "$AUDIT_COUNT" -gt 0 ]; then
        # Slice from the last `## Audit N` header to EOF — that's the latest
        # audit section (the one being overridden).
        LATEST_AUDIT=$(awk '/^## Audit [0-9]+/{buf=""} {buf = buf $0 ORS} END{print buf}' "$REVIEW")
        FOLLOWUP_BODY="$LATEST_AUDIT"
        AUDITED_AT=$(printf '%s\n' "$LATEST_AUDIT" \
          | grep -oE 'audited-at: [0-9a-f]{7,40}' | head -1 \
          | awk '{print $2}')
        # Audit N summary line is `findings: high=N medium=N low=N` (space-separated, no commas).
        SUMMARY=$(printf '%s\n' "$LATEST_AUDIT" \
          | grep -oE 'findings: high=[0-9]+ medium=[0-9]+ low=[0-9]+' \
          | tail -1)
      else
        FOLLOWUP_BODY="(review.md exists at $REVIEW but contains no '## Audit N'"
        FOLLOWUP_BODY+=" section — the override is being applied without an audit"
        FOLLOWUP_BODY+=" record; reviewer should treat this as suspicious)"
        AUDITED_AT="(unknown)"
        SUMMARY="(unknown)"
      fi
    else
      FOLLOWUP_BODY="(review.md not found at $REVIEW — the override is being"
      FOLLOWUP_BODY+=" applied without a report on disk; reviewer should treat"
      FOLLOWUP_BODY+=" this as suspicious)"
      AUDITED_AT="(unknown)"
      SUMMARY="(unknown)"
    fi
    HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "(unknown)")
    CONTEXT="The user is overriding /ak-build Phase 5.8's halt on high-severity
findings from the post-pre-ship docs + tests re-audit.

Phase 5.8 invokes /ak-check-docs-and-tests (fresh-eyes audit; runs both
/ak-docs-review and /ak-tests-review) over the commit range that landed
AFTER /ak-pre-ship Gate 5 — the polish iterations that bypass the
pre-ship audit. High-severity findings = either a new behavior shipped
without an assertion that pins it, OR a polish diff that invalidated
load-bearing docs (CLAUDE.md / Gotchas / a README) without updating
them. The override claims those findings are OK to ship anyway.

Branch: $BRANCH
HEAD SHA: $HEAD_SHA
Audit was run against: $AUDITED_AT
Audit summary: $SUMMARY

Latest audit section (specs/$FEATURE/review.md § Audit N):
$FOLLOWUP_BODY"
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
    testCoverageProject)
      echo "Test Presence|Non-Negotiables"
      ;;
    testReviewSkipReason)
      # Same convention surface as testCoverage — the override claims
      # high-severity findings are OK to ship; the reviewer judges that
      # claim against the same Non-Negotiables that gate the rest of the
      # test-coverage discipline.
      echo "Non-Negotiables|Test Assertion Depth"
      ;;
    exemptAddition)
      # Reuse the same convention sections as the gates being exempted —
      # the reviewer should judge new exempt entries against the same rules
      # the gates themselves enforce.
      echo "Test Presence|Project Docs Freshness|Project Docs Hierarchy"
      ;;
    docsReviewed)
      # Devshop-side gets devshop conventions; project-side (same check-type,
      # different repo) gets the project docs-freshness conventions instead.
      case "${REPO_MODE:-devshop}" in
        project) echo "Project Docs Freshness|Project Docs Hierarchy" ;;
        *)       echo "Backlog Routing Guide" ;;
      esac
      ;;
    dismissalLog)
      case "$gate_name" in
        qa)                 echo "Non-Negotiables" ;;
        docs-and-tests-review) echo "Wrapper API design" ;;
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

# --- Guide doc inlining (GUIDES_TO_INCLUDE map) ---
# Selectively inline guide-doc bodies into CONTEXT when the staged diff touches
# code areas whose reference doc is a guide. Mirrors CONVENTIONS_TO_INCLUDE
# above, but keyed on diff-paths (not check-type) so it generalizes to any new
# structural unit. The default header-only treatment of guide/* in the
# docsReviewed CONTEXT block lets the reviewer see chapter titles but not
# chapter bodies — historically this caused structural-enumeration drift
# (bypass tables, flowcharts, gate lists) to be missed because the diff didn't
# touch the table itself, only created a new unit the table should have grown
# a row for.
#
# Only fires for docsReviewed (the only check that judges doc adequacy).
# Format: pipe-separated <abs-path>:<heading-or-FULL> entries.
get_guides_to_inline() {
  local staged_paths="$1"
  local out=""

  # hooks.md (FULL) — bypass tables, flowchart, gate lists, dismissal log,
  # practical recipes. Triggers on anything hooks.md enumerates: commit-hook
  # scripts, husky hooks, pre-ship gates, Claude-side hooks in settings.json.
  if echo "$staged_paths" | grep -qE '^(kit/scripts/commit-hooks/|kit/hooks/|kit/scripts/preship/|template/\.husky/|\.claude/settings\.json$)'; then
    out+="${out:+|}$GIT_ROOT/kit/docs/guide/hooks.md:FULL"
  fi

  # architecture.md § File lifecycle — manifest enumerations + scaffold-bucket
  # taxonomy. Triggers on template/ changes, manifest edits, init-devshop, sync.
  if echo "$staged_paths" | grep -qE '^(template/|kit/manifest\.txt$|kit/scripts/init-devshop\.sh$|kit/scripts/sync/)'; then
    out+="${out:+|}$GIT_ROOT/kit/docs/guide/architecture.md:File lifecycle"
  fi

  # security.md (FULL) — devcontainer, firewall, locked-file enumeration.
  if echo "$staged_paths" | grep -qE '^(\.devcontainer/|template/\.devcontainer/|kit/scripts/init-firewall\.sh$)'; then
    out+="${out:+|}$GIT_ROOT/kit/docs/guide/security.md:FULL"
  fi

  echo "$out"
}

if [ "$CHECK_TYPE" = "docsReviewed" ]; then
  STAGED_PATHS=$(git diff --cached --name-only 2>/dev/null || true)
  GUIDES_LIST=$(get_guides_to_inline "$STAGED_PATHS")
  if [ -n "$GUIDES_LIST" ]; then
    INLINED_GUIDES=""
    IFS='|' read -ra GUIDES_ARR <<< "$GUIDES_LIST"
    for entry in "${GUIDES_ARR[@]}"; do
      gfile="${entry%%:*}"
      marker="${entry#*:}"
      [ -f "$gfile" ] || continue
      if [ "$marker" = "FULL" ]; then
        body=$(cat "$gfile")
        label="$(basename "$gfile")"
      else
        body=$(extract_convention_section "$gfile" "$marker")
        label="$(basename "$gfile") § $marker"
      fi
      if [ -n "$body" ]; then
        INLINED_GUIDES+="
=== $label ===
$body
"
      fi
    done
    if [ -n "$INLINED_GUIDES" ]; then
      CONTEXT="$CONTEXT

=== Relevant guide doc bodies (selectively inlined based on staged diff) ===
The headers-only previews above for kit/docs/guide/* may hide structured
enumerations (tables, flowcharts, file-maps, gate lists). The bodies below are
the chapters whose subject area the staged diff touches — scan them for any
enumeration that should grow a new entry alongside the structural unit being
added or removed.
$INLINED_GUIDES"
    fi
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
# Commit-guard calls one adversarial review per commit; 180s gives headroom for
# dense docsReviewed prompts (full guide-doc bodies inlined post-PR #25 made the
# prior 90s budget too tight under sonnet load).
# Pre-ship can fire up to 11 reviews (one per gate with dismissals); bump the
# per-call timeout so individual gates with dense context don't time out.
COMMIT_TIMEOUT=180
PRESHIP_TIMEOUT="${PRESHIP_ADVERSARIAL_TIMEOUT:-120}"
if [ "$CHECK_TYPE" = "dismissalLog" ]; then
  TIMEOUT=$PRESHIP_TIMEOUT
else
  TIMEOUT=$COMMIT_TIMEOUT
fi

# --- Per-check-type model selection ---
# Haiku for deterministic rule-application checks (cheap, fast, sufficient).
# Sonnet for judgment-heavy checks where false-passes are expensive or
# irreversible. DEVSHOP_ADVERSARIAL_MODEL_OVERRIDE forces a specific model
# for all check-types in this invocation — operator backdoor for high-stakes
# commits where they want to upgrade a normally-Haiku check.
get_model_for_check_type() {
  if [ -n "${DEVSHOP_ADVERSARIAL_MODEL_OVERRIDE:-}" ]; then
    echo "$DEVSHOP_ADVERSARIAL_MODEL_OVERRIDE"
    return
  fi
  case "$1" in
    docsReviewed|prDescStaleReason|testCoverage|testCoverageProject|testReviewSkipReason|dismissalLog|hookBypass|exemptAddition)
      echo "sonnet"
      ;;
    dirtyTreeReason|dirtyPushReason|manifestReviewed)
      echo "haiku"
      ;;
    *)
      # Safe default: unknown check-types get Sonnet (better strict than lax).
      echo "sonnet"
      ;;
  esac
}
MODEL=$(get_model_for_check_type "$CHECK_TYPE")

# --- Human review fallback (when API is unavailable) ---
# devshop.humanReviewed is blocked by PreToolUse hook for Claude —
# only reachable when human runs git commit directly in terminal.
HUMAN_REVIEW=$(git config --get devshop.humanReviewed 2>/dev/null || true)
if [ -n "$HUMAN_REVIEW" ]; then
  echo "✓ Human-reviewed: $HUMAN_REVIEW"
  exit 0
fi

# Spawn adversarial review
PROMPT="You are a commit guard auditor. Default position: REJECT bypass reasons.

Check type: $CHECK_TYPE
Reason given: $REASON

Context:
$CONTEXT

The reason must be specific, factually accurate per the context, and address actual risk (stale docs, forgotten files, missed changes, leaked secrets). Generic placeholders ('docs are fine', 'will fix later', 'low risk', 'WIP', 'minor change') FAIL.

Per-check-type rules:

1. For docsReviewed (unified doc-coverage check; the inlined catalog above shows the docs loaded for the staged repo — /devshop or /workspace): the reason MUST satisfy ALL of:
   (a) **Per-doc enumeration + named edits**: for every reference doc shown in the inlined catalog, the reason states either NOT-AFFECTED or AFFECTED. For each AFFECTED doc, the reason names (i) the section the edit lives in, AND (ii) a distinctive phrase from the edit (a new bullet, a row-cell, a changed sentence) that will appear in the staged diff. The reviewer MUST verify each named phrase by searching the staged diff for it (grep semantic). A claim of 'updated to add X' where X is not visible in the staged diff FAILS. 'Checked all docs' or per-doc rows without a named phrase FAILS.
   (b) **New-capability docs at the right level**: when the diff adds a new capability/surface, verify docs exist at the right level — devshop: a guide/* section (what/how/extend); OVERVIEW.md (incl. § Concept) for workspace-layout / event-flow / structural changes; CLAUDE.md when Claude's behavior changes. Project: CLAUDE.md § Where Things Happen (load-bearing — higher bar); the relevant per-package README; OVERVIEW.md / ARCHITECTURE.md when present (opt-in — only fire when the file exists at HEAD). Tree-diagram mentions alone are NOT sufficient — strategy/usage prose required.
   (c) **Cross-file coherence** (when reference docs are staged — see 'Reference docs staged'): staged doc changes must leave the doc set internally consistent. Contradictory claims across files (one doc says N gates, another says M; one names a script the other doesn't enumerate) MUST be flagged. Trivially satisfied when no reference docs are staged.
   (d) **Rename/move/delete drift sweep** (when 'Renamed/moved/deleted in this commit' lists entries): for each old-path entry, the inlined catalog must no longer reference the OLD name unless the reason cites the surviving reference and explains why it's intentional. Drift surfaces: file paths, section headings (## Foo → ## Bar), CI job names, skills, gate names, roadmap entries. Trivially satisfied when empty.
   (e) **Addition drift sweep** (when the staged diff adds new STRUCTURAL UNITS — scripts, hooks, skills, conventions, pre-ship gates, slash commands, GitHub Actions jobs, env-prefixed secret-store names, new pages/routes/API wrappers, new analytics events, new packages/apps/edge functions): for each added unit, scan the inlined doc bodies for any STRUCTURED ENUMERATION of that kind of unit (table, flowchart, list, taxonomy). A matching enumeration MUST contain a corresponding new entry in the staged diff. Generic prose mentioning the new unit doesn't satisfy a missing enumeration entry. When a guide doc appears headers-only (not under '=== Relevant guide doc bodies ==='), the reason MUST cite which enumeration was checked and quote the relevant row. Trivially satisfied when no new structural units are added.
   The reviewer must check the docs the reason CLAIMS to have updated against the staged diff — rule (a) is the verification anchor; every named phrase must match. Carve-out: kit/notes/**, kit/docs/CHANGELOG.md, and project-equivalent historical archives may mention deleted/renamed/old items — they're the rationale archive, not active docs.
2. For testCoverage: judge whether existing tests are sufficient to catch regressions in any functional changes since the last release. Look for: new code paths without test cases, changed exit codes / output formats not verified, new flags / options not exercised. PASS when any of: (a) changes are purely cosmetic (comments, formatting, variable renames); (b) no functional changes (docs-only release); (c) config-only changes already validated by wiring tests in structural-invariants.bats — name the specific wiring test; (d) existing tests already exercise the changed behavior — name the specific test.
3. For hookBypass: is this a known legitimate scenario (migration commits with git rm --cached, binary files that break lint-staged, intermediate refactor state with type errors)? Does skipping gitleaks create a real risk for these files?
4. For prDescStaleReason: does the PR title/body accurately describe ALL commits on the branch (origin/main..HEAD)? If the commits add a new capability, the PR description should name it. PASS requires either (a) the PR description genuinely matches the commits — the reviewer is wrong — or (b) a specific structural reason the description lags temporarily (e.g., 'batching rebases — will squash-update after final review' with a concrete next step).
5. For dirtyPushReason: does the reason name WHICH files are intentionally dirty and WHY? PASS requires specificity: 'untracked *.log debug files from local testing, not project code' or 'stashed branch X changes to push unrelated branch Y — will resume after'. Forgotten WIP (files the developer doesn't recognize) should FAIL.
6. For dismissalLog: the Reason is the body of a gate's '## Dismissals' section — the rationales given for NOT acting on specific findings. Judge each dismissal bullet individually. REJECT the whole bypass if ANY bullet exhibits:
    - Generic rationale: 'not critical', 'minor', 'can wait', 'won't fix for now' without specifics
    - Contradicts the spec's § Core user story: dismissing a bug that affects a verb in the core story is categorically NOT acceptable (the core story names the product's load-bearing flow — dismissals must not touch it)
    - Claims 'out of scope for this PR' when the spec's § In scope explicitly covers that behavior
    - Missing rationale field entirely (a bullet that just names a finding without explaining the dismissal)
    - Punts to 'TODOS' or 'follow-up' without a specific tag, issue number, or existing entry to point at
    - Claims 'user-acceptable' or 'product decision' without attributing to a specific approved spec line or design doc
    PASS only when every rationale is: specific (names what was considered and why deferred), consistent with the PR scope (doesn't cross the core user story, doesn't dismiss committed scope), and actionable (a later reviewer could find the rationale plausible given the evidence).
7. **Convention adherence** (when '=== Relevant conventions ===' appears in the context): the diff/dismissal must follow the inlined conventions. A change that violates an explicit rule (e.g. a new wrapper without onError when § Wrapper API design requires it; a dismissal that punts on an RLS-coverage finding when § Supabase Hardening Defaults marks it non-negotiable; a slow-job stripped of the edge-runtime retry when § Slow-Job Lifecycle's checklist requires it) must FAIL unless the reason explicitly engages the rule's stated rationale. Generic 'this convention doesn't apply here' WITHOUT naming why is NOT acceptable.
8. For testCoverageProject (project-repo pre-commit, ADD-without-test or orphan-after-DELETE was blocked): the reason MUST name the SPECIFIC blocked path(s) and explain WHY a test does not apply (e.g. 'page.tsx is the route entry — covered by e2e/list.spec.ts driving sign-in → add → bought', or 'utils/format.ts is a pure 3-line type re-export over packages/core/src/types — covered transitively by addItem.test.ts asserting the shape'). PASS requires a named test or named exempt-list rationale that a future reviewer could verify in 30 seconds.
9. For testReviewSkipReason (/ak-build Phase 5.8 halt override): the Reason justifies shipping the PR despite high-severity findings from the post-pre-ship test-coverage re-audit. PASS requires ALL of:
    (a) **Per-finding engagement**: the reason names each high-severity finding from the followup report (file:line + the gap the audit identified) AND explains specifically why shipping without that test is acceptable. Generic 'audit is overzealous' / 'tests are fine' / 'will fix in follow-up' WITHOUT a per-finding rationale FAILS.
    (b) **No core-flow dismissal**: a high finding that touches the project's primary user verb (sign-in / add / list / bought / equivalent) is categorically NOT acceptable. Core-flow gaps must be closed with new test commits, not waved away.
    (c) **Plausible follow-up commitment** (when 'will fix later' appears): the reason names a specific TODOS.md entry, ROADMAP entry, or follow-up issue — not a vague intent. 'Tracked at TODOS.md § <name>' with a verifiable entry PASSES; 'will add tests in next PR' without a tracker entry FAILS.
    (d) **No security-boundary skips**: findings touching auth, RLS, password policy, or other security-relevant assertions cannot be deferred — the existing tests still pass but no longer pin the right behavior, and shipping the gap is a real regression risk.
    Default: REJECT. The Phase 5.8 audit already weighed signal vs noise; high-severity findings reflect real gaps in coverage of behavior that landed after the pre-ship snapshot. The override exists for genuinely-justified ship-now cases, not for skipping the audit.
10. For exemptAddition (project-repo pre-commit, lines added to .devshop-test-coverage-exempt or .devshop-docs-freshness-exempt): the Reason is the staged additions PLUS the list of cited paths verified to exist on disk. Each entry has the format \`path  # inline reason\`. Judge each entry's inline reason individually. REJECT the WHOLE bypass if ANY entry exhibits:
    - Missing inline reason (a path with no \`#\` comment after it)
    - Generic rationale: 'TODO test', 'skip for now', 'covered elsewhere', 'low risk', 'will fix', 'see other tests' without specifics
    - Cites a covering spec/test by description but not by path (e.g. 'covered by the auth flow test' — name the file, not the concept)
    - Claims 'page entry' / 'route' / 'config' for a path that's not actually one of those (judge against the path's location: pages live under apps/*/app/**/page.tsx; routes under app/**/route.ts; configs match *.config.ts; etc.)
    - For test-coverage exemptions: name the covering spec/test path (which the pre-flight has already verified exists) OR explain why this path is intrinsically untestable (pure re-export, type-only, dev-only stub). Reasons of the form 'covered by <path>' where <path> is not in the verified-cited-paths list MUST FAIL — absence from that list means the path was never even cited.
    - For docs-freshness exemptions: explain WHY the surface doesn't need a CLAUDE.md / METRICS.md entry (e.g. 'internal liveness probe', 'feature-flag-gated dev-only screen never shown to users') — not simply assert that it doesn't.
    PASS only when every entry has a specific reason that a future reviewer could verify in 30 seconds against the inlined conventions.

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
  REVIEW=$(timeout "$TIMEOUT" claude -p --model "$MODEL" < "$PROMPT_FILE" 2>/dev/null) && break
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
