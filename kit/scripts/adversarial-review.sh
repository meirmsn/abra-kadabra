#!/bin/bash
# Adversarial review of bypass reasons.
# Shared engine for commit-time, pre-ship-time, and `/ak-build` Phase-5.8 bypass-
# reason judging. Each caller passes a check type; this script gathers context,
# spawns a Sonnet/Haiku agent to judge the reason, and returns PASS (exit 0) or
# FAIL (exit 1).
#
# After PR-C of the audit-time docs+tests migration (kit/ROADMAP.md § PR-C § F),
# this script no longer judges docs/tests coverage per-commit. Coverage
# judgment lives in audit-time `/ak-docs-review` and `/ak-tests-review`,
# orchestrated by `/ak-check-docs-and-tests`. The check-types removed here
# (docsReviewed, testCoverage, testCoverageProject, docsFreshnessProject) all
# fail with "unknown check type" so a stale caller surfaces immediately.
#
# Surviving check-types (each judges a bypass-reason — the reason itself is the
# auditable artifact, not coverage):
#   prTextHygieneReason   — title + description + body-shape hygiene across two
#                           surfaces (selected by DEVSHOP_HYGIENE_SURFACE env var):
#                             surface=pr     (default) — `.husky/pre-push` invokes
#                                            on project PRs; reads PR title/body via
#                                            `gh pr view`; judges all three dimensions.
#                             surface=squash — `/ak-merge-devshop` Phase 0.4.5 invokes
#                                            on devshop squash commits before they
#                                            land on main; reads proposed subject/body
#                                            from DEVSHOP_HYGIENE_MESSAGE_FILE; judges
#                                            (a) accuracy + (b) title readability, but
#                                            SKIPS (c) body structure (devshop squashes
#                                            use the bold-led-bullet + `## Squashed
#                                            commits` shape from ak-merge-devshop § 0.3,
#                                            not the project-PR H2 shape).
#                           Three independent dimensions: title/body describes ALL commits
#                           on the branch (accuracy); title obeys CLAUDE.md § Commit + PR
#                           Text Style (readability); body leads with `## Product update`
#                           followed by `## Engineering details` per spec authoring
#                           contract (PR-surface only).
#   dirtyTreeReason       — `.husky/pre-commit` clean-tree bypass
#   dirtyPushReason       — `.husky/pre-push` clean-tree bypass
#   manifestReviewed      — commit-guard.sh manifest-decision review
#   hookBypass            — `--no-verify` bypass review
#   exemptAddition        — added entries in .devshop-{test-coverage,docs-freshness}-exempt
#   testReviewSkipReason  — `/ak-build` Phase 5.8 halt-override review (audit-time scope,
#                           judges PER-FINDING engagement against the latest `## Audit N`
#                           section in specs/<feature>/review.md)
#   localTestSkipReason   — `changed-tests-local` gate bypass review (sub-fix 1 of
#                           cheap-test-gates-local; judges per-category engagement
#                           on a skip of changed E2E / changed integration / smoke set)
#   coreUserStoryNaReason — Gate 9 N/A rationale review (Sonnet); judges the body
#                           of `## Core user story: N/A — <reason>` in a spec at
#                           pre-ship time (invoked from preship/verify-story.sh,
#                           NOT from a commit-time bypass flag)
#   dismissalLog          — pre-ship gate-dismissal rationale review
#   advisorBypassReason   — DB-hardening advisor-clean Gate 2g bypass review (Sonnet);
#                           judges per-finding rigor of `git -c devshop.advisorBypassReason`
#                           against the 9 advisor lints from kit/docs/guide/security.md
#                           § DB hardening.
#   blockedGateOverride   — /ak-build Phase 3 → 4 halt override review (Sonnet);
#                           judges operator-supplied override reason when advancing
#                           past a `blocked` gate. Captured into
#                           specs/<feature>/review.md § Phase 3 → 4 advance log
#                           with an adversarial-review-stamp by the orchestrator.
#   batsSkipReason        — `.husky/pre-commit` (main, full suite) and
#                           `check-bats-devshop.sh` (branch, affected-only) bats
#                           failure bypass (Sonnet); judgment-heavy, high-blast-radius
#                           — skipping tests is always a judgment call. Reject generic
#                           reasons; require the operator to name the specific failing
#                           tests and explain why skipping is safe for THIS commit.
#   pushToMainApproved    — pre-push guard for feature-branch pushes targeting
#                           refs/heads/main in devshop mode (Sonnet); judges whether
#                           the push came through the /ak-merge-devshop ceremony.
#                           Only legitimate reason: /ak-merge-devshop Phase 3.
#
# Usage: adversarial-review.sh <check-type> <reason> [context...]
#   reason: the bypass reason provided via git -c, OR for dismissalLog the body of the
#           `## Dismissals` section of the gate's review.md entry
#   context: additional context (piped or as arguments)
#     dismissalLog:        $1 = gate name, $2 = path to review.md
#     blockedGateOverride: $1 = gate name (e.g. "Gate 8: /design-review"),
#                          $2 = follow-up tracker pointer (path:section or URL),
#                          $3 = path to review.md (for spec scope + advance-log context)
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
#   Sonnet: prTextHygieneReason, testReviewSkipReason, localTestSkipReason, coreUserStoryNaReason, dismissalLog, hookBypass, exemptAddition, advisorBypassReason, blockedGateOverride, pushToMainApproved, batsSkipReason
# Rationale: PR descriptions are the canonical reviewer-facing record; hookBypass
# can leak secrets via gitleaks bypass; testReviewSkipReason judges audit-time
# halt overrides; dismissalLog weighs spec scope. Dirty-tree / manifest checks
# are pure rule-application.
#
# Convention-inlining: for surviving check-types this script appends relevant
# sections of `kit/docs/guide/conventions.md` to the reviewer's context block via
# the CONVENTIONS_TO_INCLUDE map below. After PR-C, the only coverage-related
# entries are `exemptAddition` (still judges entries to the two project-side
# exempt files) and `testReviewSkipReason` (audit-time halt override).
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

# Repo-mode detection (devshop vs project) — used by get_conventions_to_inline
# to pick the right convention sections. Same heuristic as commit-guard.sh: a
# real `kit/` dir at the repo root means devshop-self mode (works for both
# /devshop and bats sandboxes). Otherwise treat as project repo.
if [ "$GIT_ROOT" = "/devshop" ] || { [ -n "$GIT_ROOT" ] && [ -d "$GIT_ROOT/kit" ] && [ ! -L "$GIT_ROOT/kit" ]; }; then
  REPO_MODE=devshop
else
  REPO_MODE=project
fi

case "$CHECK_TYPE" in
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
- devshop commit guard (mixed-commit + Layer 1 docs/tests coverage)

Staged files:
$STAGED"
    ;;
  manifestReviewed)
    CONTEXT="Template file additions/removals vs manifest.txt.
The developer proposes how to handle manifest updates.

Reason: $REASON"
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
    # Findings live in specs/<feature>/review.md as appended `## Audit N`
    # sections (single-file model — no separate test-review-followup.md).
    # The latest `## Audit N` section is the one whose halt is being
    # overridden; harvest it from there.
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
  localTestSkipReason)
    # Called by kit/scripts/preship/changed-tests-local.sh when the user has set
    # `git config devshop.localTestSkipReason "..."` to short-circuit the gate.
    # The reviewer judges whether the skip is load-bearing against the actual
    # diff scope — not against a generic "tests look fine" claim.
    BRANCH=$(git branch --show-current 2>/dev/null || true)
    HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "(unknown)")
    # Surface the diff so the reviewer can judge the categories being skipped.
    # `origin/main` is the canonical base for the gate; fall back to HEAD~1 if
    # origin isn't reachable (test fixtures, fresh clones).
    DIFF_PATHS=""
    if DIFF_PATHS=$(git diff --name-only --diff-filter=AM origin/main...HEAD 2>/dev/null); then
      :
    else
      DIFF_PATHS=$(git diff --name-only --diff-filter=AM HEAD~1..HEAD 2>/dev/null || true)
    fi
    DIFF_PATHS="${DIFF_PATHS:-(no diff or origin/main unreachable)}"
    CONTEXT="The user is bypassing the changed-tests-local pre-ship gate (#2d).

The gate runs the cheap halves of integration + E2E test execution locally:
  Step 1: parse-check (playwright test --list)
  Step 2: changed E2E specs (apps/*/e2e/*.spec.ts in the diff)
  Step 3: changed integration tests (*.integration.test.ts in the diff)
  Step 4: smoke set (apps/web/e2e/*-qa-walk.spec.ts ∪ apps/web/e2e/qa-walk.spec.ts)

Bypass means none of these run; the bypass reason claims that's OK.

Branch: $BRANCH
HEAD SHA: $HEAD_SHA

Diff paths (origin/main...HEAD, added/modified):
$DIFF_PATHS

The reviewer judges whether the bypass reason addresses each test category that
would otherwise have run, against the diff above."
    ;;
  coreUserStoryNaReason)
    # Called by kit/scripts/preship/verify-story.sh when the spec's
    # `## Core user story` body declares `N/A — <reason>` and Gate 9's
    # artifact assertion is being skipped. The reviewer judges whether the
    # rationale names a verifiable file/path claim (PASS) or interpretive
    # prose (FAIL). Unlike commit-time bypass flags, this fires at pre-ship
    # time on the spec body itself — there is no `git -c devshop.<key>` flag.
    BRANCH=$(git branch --show-current 2>/dev/null || true)
    HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "(unknown)")
    # Surface the diff so the reviewer can judge the rationale against actual
    # file paths in the diff. `origin/main` is the canonical base; fall back
    # to HEAD~1 if origin isn't reachable (test fixtures, fresh clones).
    DIFF_PATHS=""
    if DIFF_PATHS=$(git diff --name-only --diff-filter=AM origin/main...HEAD 2>/dev/null); then
      :
    else
      DIFF_PATHS=$(git diff --name-only --diff-filter=AM HEAD~1..HEAD 2>/dev/null || true)
    fi
    DIFF_PATHS="${DIFF_PATHS:-(no diff or origin/main unreachable)}"
    CONTEXT="The user is skipping Gate 9's Core-user-story artifact assertion by
declaring \`## Core user story: N/A — <reason>\` in the spec.

Gate 9 normally requires that every imperative verb in the Core user story
has a matching artifact at \`specs/<feature>/qa-walk/verb-<N>-<slug>.{png,json}\`
proving the action completed. The N/A path bypasses that requirement when
the PR is non-user-facing (migration-only, internal refactor, kit-only edit).

The reason given is the rationale text for that bypass. Judge whether it
names a verifiable file/path claim (PASS) or interpretive prose (FAIL).

Branch: $BRANCH
HEAD SHA: $HEAD_SHA

Diff paths (origin/main...HEAD, added/modified):
$DIFF_PATHS

The reviewer judges whether the rationale's file/path claim is verifiable
against the diff above."
    ;;
  prTextHygieneReason)
    # Two surfaces, one reviewer engine. Rules (a) accuracy and (b) title
    # readability are universal per kit/docs/guide/conventions.md § Commit + PR
    # Text Style; only the data source and rule (c) body-structure differ.
    #
    #   surface=pr     (default; called by .husky/pre-push)  — gathers PR
    #                  title/body via `gh pr view` and constituent commits
    #                  via `origin/main..HEAD`. Rule (c) judges the
    #                  `## Product update` + `## Engineering details` shape.
    #
    #   surface=squash (called by /ak-merge-devshop Phase 0.4.5) — gathers
    #                  proposed squash subject/body from a tempfile composed
    #                  by Phase 0.3 and constituent commits via
    #                  `origin/main..$DEVSHOP_HYGIENE_BRANCH` (worktree-safe
    #                  — the squash composer's working tree may be a linked
    #                  worktree, not /devshop). Rule (c) is skipped via an
    #                  inlined NOTE: devshop squashes use bold-led bullets
    #                  + `Key details:` + `## Squashed commits`, not the
    #                  project-PR H2 shape.
    SURFACE="${DEVSHOP_HYGIENE_SURFACE:-pr}"

    if [ "$SURFACE" = "squash" ]; then
      MSG_FILE="${DEVSHOP_HYGIENE_MESSAGE_FILE:-}"
      HYG_BRANCH="${DEVSHOP_HYGIENE_BRANCH:-$(git branch --show-current 2>/dev/null || true)}"
      if [ -z "$MSG_FILE" ] || [ ! -f "$MSG_FILE" ]; then
        echo "FAIL: surface=squash requires DEVSHOP_HYGIENE_MESSAGE_FILE pointing to an existing file (got: '${MSG_FILE}')"
        exit 1
      fi
      SQ_SUBJECT=$(head -1 "$MSG_FILE")
      SQ_BODY=$(tail -n +2 "$MSG_FILE")
      COMMITS=$(git log --oneline "origin/main..$HYG_BRANCH" 2>/dev/null || true)
      COMMIT_COUNT=$(echo "$COMMITS" | grep -c . 2>/dev/null || echo 0)
      CONTEXT="Devshop squash commit composed for branch $HYG_BRANCH (${COMMIT_COUNT} constituent commits about to collapse into one).

Proposed squash subject (line 1 of the commit message — judge as you would a PR title):
$SQ_SUBJECT

Proposed squash body (everything after line 1):
$SQ_BODY

Constituent commits being squashed (origin/main..$HYG_BRANCH):
$COMMITS

NOTE 1 — Primary judgment, NOT a bypass review. This invocation fires from
\`/ak-merge-devshop\` Phase 0.4.5 at compose time as a CONTENT CHECK on the
proposed squash subject + body. The operator has NOT supplied a bypass
defense — the 'Reason given' field above is a procedural marker the skill
passes for telemetry (e.g. 'auto-check at compose time'), NOT an operator
rationale that needs to engage with the rules. Judge the subject + body
content directly against rules (a) and (b) below. Do NOT apply the generic
'reason must be specific / generic placeholders FAIL' criterion to the
'Reason given' field — that criterion exists for actual bypass-defense
invocations (PR surface at pre-push time) where the operator IS claiming
the rules don't apply. Here, there is no such claim. A clean subject + body
should PASS regardless of how procedural the 'Reason given' field reads.

NOTE 2 — Surface shape. This is a devshop squash, NOT a project PR. Apply
rules (a) Description accuracy and (b) Title readability normally — they
are universal per kit/docs/guide/conventions.md § Commit + PR Text Style.
SKIP rule (c) Body structure: devshop squashes use the bold-led-bullet
shape from /devshop/.claude/skills/ak-merge-devshop/SKILL.md § 0.3 (e.g.
\`**Adds:**\`, \`**Trade-off:**\`, \`Key details:\`, \`## Squashed commits\`),
NOT the project-PR \`## Product update\` + \`## Engineering details\` H2
shape. Rule (a) accuracy still applies — judge whether the subject + body
accurately describe ALL constituent commits."
    else
      # Called by .husky/pre-push. Gathers PR title/body vs commits on branch.
      BRANCH=$(git branch --show-current 2>/dev/null || true)
      PR_NUM=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number // empty' 2>/dev/null || true)

      if [ -z "$PR_NUM" ]; then
        # Shouldn't happen — pre-push checks for PR existence before invoking — but fail safe.
        CONTEXT="No open PR for branch $BRANCH. This check should not have been invoked."
      else
        PR_DATA=$(gh pr view "$PR_NUM" --json title,body 2>/dev/null || echo "{}")
        PR_TITLE=$(echo "$PR_DATA" | jq -r '.title // "(no title)"')
        # Full body — never truncate. Body-structure check (dimension c) needs to see the
        # entire body to verify `## Engineering details` ends cleanly; accuracy check
        # (dimension a) needs every commit's narrative. Sonnet 4.6's 200k-token context
        # absorbs even a long PR (a 200-line body is ~3k tokens) without strain, and
        # truncating silently turns missing tail content into false FAILs.
        PR_BODY=$(echo "$PR_DATA" | jq -r '.body // ""')
        # All commits in the branch relative to main — this is what reviewers see in the PR.
        COMMITS=$(git log --oneline origin/main..HEAD 2>/dev/null || true)
        COMMIT_COUNT=$(echo "$COMMITS" | grep -c . 2>/dev/null || echo 0)
        CONTEXT="PR #$PR_NUM on branch $BRANCH (${COMMIT_COUNT} commits ahead of main).

Current PR title:
$PR_TITLE

Current PR body (full):
$PR_BODY

All commits on this branch (origin/main..HEAD):
$COMMITS"
      fi
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

    # Fast-path: dismissals on a `blocked` gate are categorically invalid.
    # `blocked` is a tooling-gap signal, not a reviewable finding — dismissing
    # it via the per-gate `## Dismissals` shim short-circuits the orchestrator's
    # `blocked > 0` halt path.
    #
    # The `blocked (n/a per scope: <reason>)` shape IS a legitimate dismissal
    # target — the gate didn't run because of scope, not tooling, and the
    # rationale is what this reviewer normally judges. The fast-path rejects
    # `blocked` ONLY when the parenthetical is missing or is NOT an
    # `n/a per scope:` claim.
    #
    # Codified from home-os PR #15 (2026-05-14): Gate 9 /qa reported
    # `blocked: 1` (Supabase Kong unreachable), the dismissal-shim cascaded
    # the blocked past review, and the PR shipped with placeholder hero
    # shots from the sign-in flow instead of the actual feature.
    if [ -n "$GATE_SECTION" ]; then
      BLOCKED_RESULT_LINE=$(echo "$GATE_SECTION" \
        | grep -E '^(- *)?\*{0,2}Result:\*{0,2} *blocked' \
        | head -1 || true)
      if [ -n "$BLOCKED_RESULT_LINE" ] \
         && ! echo "$BLOCKED_RESULT_LINE" | grep -qE 'n/a per scope:'; then
        cat <<EOF
FAIL: dismissals on a blocked gate are invalid — blocked is a tooling-gap signal, not a reviewable finding.

  Gate: $GATE_NAME
  Result line in review.md: $(echo "$BLOCKED_RESULT_LINE" | sed 's/^- *//')

  Dismissals can be applied to findings the gate produced while running;
  they cannot wave away the gate's own inability to run. Resolve the
  tooling gap (recover the local stack / install the missing tool / clear
  whatever the gate's preflight cited) and re-run /ak-pre-ship so the
  gate emits a real outcome (pass / findings / or — if scope-exempt —
  'blocked (n/a per scope: <specific reason>)', which is a separate
  shape this fast-path explicitly accepts).

  Codified from home-os PR #15 (2026-05-14) where this exact path
  cascaded a Gate 9 blocked past review and shipped placeholder hero
  shots in the PR body.
EOF
        exit 1
      fi
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
  advisorBypassReason)
    # Called by kit/scripts/preship/advisor-clean.sh when the user has set
    # `git config devshop.advisorBypassReason "..."` to short-circuit the
    # DB-hardening advisor gate. The reviewer judges whether the reason is
    # load-bearing (per-finding rationale + TODOS pointer) against the actual
    # advisor findings — not against a generic "extension-in-public is fine"
    # claim.
    BRANCH=$(git branch --show-current 2>/dev/null || true)
    HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "(unknown)")
    MIG_DIFF=$(git diff --name-only --diff-filter=AM origin/main...HEAD 2>/dev/null \
      | grep -E '^supabase/(migrations|functions)/' \
      | head -20 || true)
    CONTEXT="The user is bypassing the advisor-clean pre-ship gate (Gate 2g).

The gate runs 9 advisor lints (function search_path, auth_rls_initplan,
unindexed FKs, multiple permissives, security_definer views, RLS
disabled / no-policy, extension_in_public, duplicate indexes) — each
encodes a DB-hardening rule from kit/docs/guide/security.md § DB
hardening. The bypass claims one or more findings are acceptable to
ship despite the lint flag.

Branch: $BRANCH
HEAD SHA: $HEAD_SHA

Migration / function files in this diff:
${MIG_DIFF:-(none — bypass on a non-migration PR is itself suspicious)}

Bypass reason (the text being judged):
$REASON"
    ;;
  blockedGateOverride)
    # Called by /ak-build § Phase 3 → 4 handoff § Rung 2 when the operator picks
    # the override option in the AskUserQuestion halt. REASON is the override
    # rationale; extra args:
    #   $1 = gate name (canonical, e.g. "Gate 8: /design-review")
    #   $2 = follow-up tracker pointer (path:section or GitHub issue URL)
    #   $3 = path to specs/<feature>/review.md (for spec scope + advance-log context)
    [ -z "$GATE_NAME" ] && GATE_NAME="unknown-gate"
    TRACKER="${2:-}"
    GATE_REPORT_PATH="${3:-}"

    # Pull spec scope so the reviewer can judge "override contradicts § In scope"
    # the same way dismissalLog does. The override is a stronger claim than a
    # finding dismissal — it waves past a gate that didn't run at all — so the
    # spec-scope comparison is load-bearing.
    FEATURE_DIR=$(dirname "$GATE_REPORT_PATH" 2>/dev/null || true)
    SPEC_IN_SCOPE=""
    SPEC_CORE_STORY=""
    if [ -n "$FEATURE_DIR" ] && [ -f "$FEATURE_DIR/spec.md" ]; then
      SPEC_IN_SCOPE=$(awk '/^## In scope/{f=1;next} f && /^## /{exit} f' \
        "$FEATURE_DIR/spec.md" 2>/dev/null | head -80)
      SPEC_CORE_STORY=$(awk '/^## Core user story/{f=1;next} f && /^## /{exit} f' \
        "$FEATURE_DIR/spec.md" 2>/dev/null | head -30)
    fi

    # Prior advance-log entries on the same feature (precedent the operator might
    # try to lean on). The reviewer's rule #12 (a) explicitly rejects precedent
    # framing — inlining the prior entries gives the reviewer the surface to
    # detect a copy-paste reason.
    PRIOR_ADVANCE_LOG=""
    if [ -n "$GATE_REPORT_PATH" ] && [ -f "$GATE_REPORT_PATH" ]; then
      PRIOR_ADVANCE_LOG=$(awk '
        /^## Phase 3 → 4 advance log/{f=1;next} f && /^## /{exit} f
      ' "$GATE_REPORT_PATH" 2>/dev/null | head -120)
    fi

    CONTEXT="Gate being overridden: $GATE_NAME

The operator picked the override option in /ak-build's Phase 3 → 4 halt
AskUserQuestion — advancing past a 'blocked' gate. The orchestrator has
captured the gate, reason, and follow-up tracker into review.md § Phase 3 → 4
advance log; this reviewer judges whether the override reason holds up.

=== Override reason (the rationale being audited) ===
$REASON

=== Follow-up tracker pointer (the operator claims the work is tracked here) ===
${TRACKER:-(not provided — automatic FAIL per rule 12(c))}

=== Spec § Core user story (MUST NOT be waived by override) ===
${SPEC_CORE_STORY:-(not declared — spec lacks Core user story section)}

=== Spec § In scope (what this PR committed to) ===
${SPEC_IN_SCOPE:-(not available)}

=== Prior advance-log entries on this feature (precedent surface) ===
${PRIOR_ADVANCE_LOG:-(no prior overrides on this feature)}"
    ;;
  batsSkipReason)
    # Called by .husky/pre-commit (main, full suite) and check-bats-devshop.sh
    # (branch, affected-only) when bats tests fail and the operator has set
    # `git config devshop.batsSkipReason "..."` to bypass the failure.
    BRANCH=$(git branch --show-current 2>/dev/null || true)
    HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "(unknown)")
    STAGED=$(git diff --cached --stat 2>/dev/null || true)
    # $1 carries the failing test lines (grep '^not ok') from the caller
    BATS_FAILURES="${1:-}"
    CONTEXT="The user is bypassing bats test failures at commit time.

Bats tests are the devshop's structural integrity suite — they verify that
hooks, scripts, and wiring invariants hold. Skipping them means shipping a
commit that may break the enforcement chain for future commits.

Branch: $BRANCH
HEAD SHA: $HEAD_SHA

Failing test lines:
${BATS_FAILURES:-(not captured — caller did not pass failure lines)}

Staged files:
$STAGED

The reviewer judges whether the bypass reason names the specific failing
tests AND explains why skipping is safe for THIS commit."
    ;;
  *)
    # Unknown / removed check-type. PR-C narrowed the supported set —
    # docsReviewed, testCoverage, testCoverageProject, docsFreshnessProject all
    # moved to audit-time `/ak-check-docs-and-tests`. A stale caller hits this
    # branch and surfaces immediately rather than silently no-op'ing.
    echo "FAIL: unknown check type: $CHECK_TYPE" >&2
    echo "  Surviving check-types: prTextHygieneReason | dirtyTreeReason | dirtyPushReason | manifestReviewed | hookBypass | exemptAddition | testReviewSkipReason | localTestSkipReason | coreUserStoryNaReason | dismissalLog | advisorBypassReason | blockedGateOverride | batsSkipReason"
    echo "  Coverage reviews (docsReviewed / testCoverage / testCoverageProject / docsFreshnessProject) moved to audit-time /ak-check-docs-and-tests in PR-C — see kit/ROADMAP.md."
    exit 1
    ;;
esac

# --- Convention inlining (CONVENTIONS_TO_INCLUDE map) ---
# Append relevant sections of `kit/docs/guide/conventions.md` to CONTEXT so the
# reviewer can judge convention adherence (not just bypass-reason semantics).
# Mapping is (CHECK_TYPE [+ GATE_NAME for dismissalLog]) → pipe-separated list
# of `## <heading>` names from conventions.md.
#
# After PR-C, only `testReviewSkipReason`, `exemptAddition`, and `dismissalLog`
# (gate-routed) remain on the convention-inlining surface. The docs/tests
# coverage check-types removed in PR-C took their `Backlog Routing Guide` /
# `Test Presence | Project Docs Coverage | Project Docs Hierarchy` /
# `Non-Negotiables` entries with them.
extract_convention_section() {
  local file="$1"
  local heading="$2"
  awk -v h="$heading" '
    $0 == ("## " h) { in_s=1; print; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$file"
}

# Extract a bolded sub-section from a markdown file. Used by
# coreUserStoryNaReason to pull `**New (Phase 1-B landing — <heading>)**:`-style
# sub-sections out of workflow.md (which uses bolded markers instead of `##`
# headings for its sub-conventions). Reads from the line containing the
# heading marker to the next blank-line-followed-by-bold-marker (or `## `).
extract_bold_section() {
  local file="$1"
  local heading="$2"
  awk -v h="$heading" '
    index($0, h) > 0 && !in_s { in_s=1; print; next }
    in_s && /^## / { exit }
    in_s && prev_blank && /^\*\*/ { exit }
    in_s { print }
    { prev_blank = ($0 ~ /^[[:space:]]*$/) }
  ' "$file"
}

# Returns pipe-separated list of section names to inline, or empty if none.
get_conventions_to_inline() {
  local check_type="$1"
  local gate_name="${2:-}"
  case "$check_type" in
    testReviewSkipReason)
      # Audit-time halt override — the override claims high-severity findings
      # are OK to ship; the reviewer judges that claim against the same
      # Non-Negotiables that gate the rest of the test-coverage discipline.
      echo "Non-Negotiables|Test Assertion Depth"
      ;;
    exemptAddition)
      # Reuse the same convention sections as the gates being exempted —
      # the reviewer should judge new exempt entries against the same rules
      # the gates themselves enforce.
      echo "Test Presence|Project Docs Coverage|Project Docs Hierarchy"
      ;;
    advisorBypassReason)
      # DB-hardening advisor bypass — the reviewer judges per-finding rationale
      # against the Supabase hardening conventions and the security-side
      # SQL rules. Inlining Supabase Hardening Defaults gives the reviewer
      # the migration-time policy + ON DELETE context that the lint rules
      # are themselves enforcing.
      echo "Supabase Hardening Defaults"
      ;;
    dismissalLog)
      case "$gate_name" in
        qa)                        echo "Non-Negotiables" ;;
        docs-and-tests-review)     echo "Wrapper API design" ;;
        design-review)             echo "DESIGN.md as Contract|Screenshot Routing" ;;
        cso|rls-coverage)          echo "Supabase Hardening Defaults" ;;
        slow-job-lifecycle)        echo "Slow-Job Lifecycle" ;;
        review)                    echo "Backlog Routing Guide" ;;
        metrics-check)             echo "Metrics Lifecycle" ;;
        *)                         echo "" ;;
      esac
      ;;
    *)
      echo ""
      ;;
  esac
}

# coreUserStoryNaReason inlines a section of `kit/docs/guide/workflow.md`
# (NOT conventions.md) — the Core user story requirement contract is the
# load-bearing definition for what a valid N/A body looks like. The helper
# above assumes conventions.md for every other surviving check-type; this
# is the single per-file extension. Returns a `file:section` pair, or empty.
get_workflow_to_inline() {
  local check_type="$1"
  case "$check_type" in
    coreUserStoryNaReason)
      echo "kit/docs/guide/workflow.md|Core user story requirement"
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

# --- Workflow-doc inlining (single-purpose extension for coreUserStoryNaReason) ---
# coreUserStoryNaReason inlines a section of `kit/docs/guide/workflow.md`
# (NOT conventions.md) — the Core user story requirement contract is a
# bolded sub-section of `## Step 4: /ak-build`, not a top-level `##`. The
# inlining helper above resolves `## <heading>` slices; this branch resolves
# bolded-marker slices via extract_bold_section().
WORKFLOW_TO_INCLUDE=$(get_workflow_to_inline "$CHECK_TYPE")
if [ -n "$WORKFLOW_TO_INCLUDE" ]; then
  IFS='|' read -r WORKFLOW_RELPATH WORKFLOW_HEADING <<< "$WORKFLOW_TO_INCLUDE"
  WORKFLOW_FILE="$GIT_ROOT/$WORKFLOW_RELPATH"
  if [ -f "$WORKFLOW_FILE" ]; then
    WORKFLOW_BODY=$(extract_bold_section "$WORKFLOW_FILE" "$WORKFLOW_HEADING")
    if [ -n "$WORKFLOW_BODY" ]; then
      CONTEXT="$CONTEXT

=== Relevant workflow contract ($WORKFLOW_RELPATH § $WORKFLOW_HEADING) ===
The rationale must be consistent with the contract below. A rationale that
contradicts the contract — or names a claim the contract calls out as a
bypass surface rather than a verifiable file-system fact — should fail.
$WORKFLOW_BODY"
    fi
  fi
fi

# (Selective guide-doc inlining — formerly GUIDES_TO_INCLUDE — only fired for
# `docsReviewed`, which moved to audit-time `/ak-docs-review` in PR-C. The map
# moved with it; no surviving check-type needs it.)

# --- Devshop-wide adversarial review bypass (tight iteration loops) ---
# Active-human-review escape hatch for pre-ship dismissalLog calls that cascade
# across many gates. NEVER set in CI or release — this is a dev-loop convenience.
if [ "${DEVSHOP_SKIP_ADVERSARIAL:-0}" = "1" ]; then
  echo "✓ Adversarial review bypassed via DEVSHOP_SKIP_ADVERSARIAL=1"
  exit 0
fi

# --- Pre-ship vs commit-guard timeout budgeting ---
# Commit-guard calls are now scoped to bypass-reason judging only; 180s gives
# headroom for context-rich exemptAddition / hookBypass / testReviewSkipReason
# prompts.
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
    prTextHygieneReason|testReviewSkipReason|localTestSkipReason|coreUserStoryNaReason|dismissalLog|hookBypass|exemptAddition|advisorBypassReason|blockedGateOverride|pushToMainApproved|batsSkipReason)
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

The reason must be specific, factually accurate per the context, and address actual risk (forgotten files, missed changes, leaked secrets). Generic placeholders ('docs are fine', 'will fix later', 'low risk', 'WIP', 'minor change') FAIL.

Per-check-type rules:

1. For hookBypass: is this a known legitimate scenario (migration commits with git rm --cached, binary files that break lint-staged, intermediate refactor state with type errors)? Does skipping gitleaks create a real risk for these files?
2. For prTextHygieneReason: judge THREE independent dimensions; FAIL if any fails.
    (a) **Description accuracy** — does the PR title/body accurately describe ALL commits on the branch (origin/main..HEAD)? If the commits add a new capability, the PR description should name it. Accuracy PASSES when either the PR description genuinely matches the commits — the reviewer is wrong — or a specific structural reason the description lags temporarily (e.g. 'batching rebases — will squash-update after final review' with a concrete next step).
    (b) **Title readability** — per /devshop/CLAUDE.md § Commit + PR Text Style, the PR title must:
        - Describe the **observable change**, not the implementation mechanism. \`fix: 404 after save card\` PASSES; \`fix(cards/[id]): explicit auth check + Sentry diagnostics on 404 path\` FAILS (leads with mechanism). \`fix(migrations): qualify column refs in start_triage + complete_triage\` FAILS (leads with mechanism); \`fix: /api/triage 500s on Read this for me\` PASSES.
        - Be ≤ 72 chars.
        - Contain no internal jargon: \`polish\`, \`soak findings\`, \`Phase N\`, \`Tier B\`, raw file paths, function names, or mechanism verbs (\`qualify\`, \`rewrap\`, \`refactor\`, \`rename\`, \`extract\`) UNLESS those words describe what users experience.
        Noun-lists are fine for multi-unit features (\`feat: invite link + member mgmt + audit feed\`). When the title fails readability, the bypass reason must explicitly engage the rule — generic 'title is fine' / 'reviewer wrong' FAILS unless the reason explains why this specific title meets the observable-change bar.
    (c) **Body structure** — per /devshop/CLAUDE.md § Commit + PR Text Style, the PR body must lead with two H2 sections in this exact order:
        1. \`## Product update\` as the first content after the H1 title. Carries either (i) both sub-sections \`### Headline (user-facing)\` AND \`### Detail (team-facing)\`, OR (ii) the collapsed form \`### Headline + Detail (combined)\` when the two would read word-for-word identically.
        2. \`## Engineering details\` next. Opens with a one-sentence TL;DR followed by 3–7 bullets at the engineering grain.
        For pure-infrastructure PRs (no user-visible change) the Headline body MAY read \`Infrastructure update — no user-visible change in this PR.\` — an honest acknowledgment, not fabricated marketing voice. FAIL when: \`## Product update\` is missing entirely; \`## Engineering details\` appears before \`## Product update\`; sub-sections are missing under \`## Product update\`; the body is a bare \`## Summary\` (legacy shape — renamed to \`## Engineering details\` 2026-05-17, and \`## Product update\` is the new lead). When body structure fails, the bypass reason must engage the missing/misordered section by name — generic 'body is fine' / 'reviewer wrong' FAILS.
    PASS overall requires (a) AND (b) AND (c) ALL clean. A correct title doesn't excuse a missing Product update; an accurate description doesn't excuse a mechanism-leading title; etc.
3. For dirtyPushReason: does the reason name WHICH files are intentionally dirty and WHY? PASS requires specificity: 'untracked *.log debug files from local testing, not project code' or 'stashed branch X changes to push unrelated branch Y — will resume after'. Forgotten WIP (files the developer doesn't recognize) should FAIL.
4. For dismissalLog: the Reason is the body of a gate's '## Dismissals' section — the rationales given for NOT acting on specific findings. Judge each dismissal bullet individually. REJECT the whole bypass if ANY bullet exhibits:
    - Generic rationale: 'not critical', 'minor', 'can wait', 'won't fix for now' without specifics
    - Contradicts the spec's § Core user story: dismissing a bug that affects a verb in the core story is categorically NOT acceptable (the core story names the product's load-bearing flow — dismissals must not touch it)
    - Claims 'out of scope for this PR' when the spec's § In scope explicitly covers that behavior
    - Missing rationale field entirely (a bullet that just names a finding without explaining the dismissal)
    - Punts to 'TODOS' or 'follow-up' without a specific tag, issue number, or existing entry to point at
    - Claims 'user-acceptable' or 'product decision' without attributing to a specific approved spec line or design doc
    PASS only when every rationale is: specific (names what was considered and why deferred), consistent with the PR scope (doesn't cross the core user story, doesn't dismiss committed scope), and actionable (a later reviewer could find the rationale plausible given the evidence).
    NOTE: a \`blocked\` outcome on the gate is rejected by a fast-path BEFORE this prompt fires — blocked is a tooling-gap signal, not a reviewable finding, and the only legitimate dismissable shape on a blocked gate is \`blocked (n/a per scope: <reason>)\`.
5. **Convention adherence** (when '=== Relevant conventions ===' appears in the context): the diff/dismissal must follow the inlined conventions. A change that violates an explicit rule (e.g. a dismissal that punts on an RLS-coverage finding when § Supabase Hardening Defaults marks it non-negotiable; a slow-job stripped of the edge-runtime retry when § Slow-Job Lifecycle's checklist requires it) must FAIL unless the reason explicitly engages the rule's stated rationale. Generic 'this convention doesn't apply here' WITHOUT naming why is NOT acceptable.
6. For exemptAddition (project-repo pre-commit, lines added to .devshop-test-coverage-exempt or .devshop-docs-freshness-exempt): the Reason is the staged additions PLUS the list of cited paths verified to exist on disk. Each entry has the format \`path  # inline reason\`. Judge each entry's inline reason individually. REJECT the WHOLE bypass if ANY entry exhibits:
    - Missing inline reason (a path with no \`#\` comment after it)
    - Generic rationale: 'TODO test', 'skip for now', 'covered elsewhere', 'low risk', 'will fix', 'see other tests' without specifics
    - Cites a covering spec/test by description but not by path (e.g. 'covered by the auth flow test' — name the file, not the concept)
    - Claims 'page entry' / 'route' / 'config' for a path that's not actually one of those (judge against the path's location: pages live under apps/*/app/**/page.tsx; routes under app/**/route.ts; configs match *.config.ts; etc.)
    - For test-coverage exemptions: name the covering spec/test path (which the pre-flight has already verified exists) OR explain why this path is intrinsically untestable (pure re-export, type-only, dev-only stub). Reasons of the form 'covered by <path>' where <path> is not in the verified-cited-paths list MUST FAIL — absence from that list means the path was never even cited.
    - For docs-freshness exemptions: explain WHY the surface doesn't need a CLAUDE.md / METRICS.md entry (e.g. 'internal liveness probe', 'feature-flag-gated dev-only screen never shown to users') — not simply assert that it doesn't.
    PASS only when every entry has a specific reason that a future reviewer could verify in 30 seconds against the inlined conventions.
7. For testReviewSkipReason (/ak-build Phase 5.8 halt override): the Reason justifies shipping the PR despite high-severity findings from the post-pre-ship docs+tests re-audit. PASS requires ALL of:
    (a) **Per-finding engagement**: the reason names each high-severity finding from the latest \`## Audit N\` section (file:line + the gap the audit identified) AND explains specifically why shipping without that test/doc is acceptable. Generic 'audit is overzealous' / 'will fix in follow-up' WITHOUT a per-finding rationale FAILS.
    (b) **No core-flow dismissal**: a high finding that touches the project's primary user verb (sign-in / add / list / bought / equivalent) is categorically NOT acceptable. Core-flow gaps must be closed with new test commits, not waved away.
    (c) **Plausible follow-up commitment** (when 'will fix later' appears): the reason names a specific TODOS.md entry, ROADMAP entry, or follow-up issue — not a vague intent. 'Tracked at TODOS.md § <name>' with a verifiable entry PASSES; 'will add tests in next PR' without a tracker entry FAILS.
    (d) **No security-boundary skips**: findings touching auth, RLS, password policy, or other security-relevant assertions cannot be deferred — the existing tests still pass but no longer pin the right behavior, and shipping the gap is a real regression risk.
    Default: REJECT. The Phase 5.8 audit already weighed signal vs noise; high-severity findings reflect real gaps in coverage of behavior that landed after the pre-ship snapshot. The override exists for genuinely-justified ship-now cases, not for skipping the audit.
8. For manifestReviewed: judge whether the proposed manifest treatment matches the actual file's lifecycle (locked / sync / scaffold-once / symlink / locked-dir). Generic 'add to manifest' without naming the lifecycle tag FAILS.
9. For dirtyTreeReason: same shape as dirtyPushReason but at commit-time.
10. For localTestSkipReason (changed-tests-local gate bypass): the Reason justifies
    skipping local execution of changed E2E specs / changed integration specs /
    smoke set despite paths in the diff that need them. PASS requires ALL of:
    (a) Per-finding engagement: the reason names each test category being
        skipped (e.g. \"skipping the smoke set because pnpm dev wedges in this
        devcontainer; the changed E2E specs ran fine\") AND explains why CI
        coverage is sufficient for that category.
    (b) No core-flow dismissal: skipping the smoke set on a diff that touches
        the project's primary user verb is categorically NOT acceptable.
    (c) Plausible follow-up commitment (when \"will fix later\" appears): the
        reason names a specific TODOS.md / ROADMAP entry tracking the
        environmental fix.
    (d) No silent-broken-env skips: \"the local stack is broken so I'm
        skipping\" must include either an open issue tracking the env fix OR
        a concrete recipe the operator already tried.
    Default: REJECT. Generic \"ran out of time\" / \"I'll fix later\" / \"low risk\"
    FAIL.
11. For coreUserStoryNaReason (Gate 9 N/A rationale): the Reason is the body
    of \`## Core user story: N/A — <reason>\` in a spec; the operator is
    skipping Gate 9's per-verb artifact assertion. The shape of a correct
    rationale is a fact a reader can re-verify against \`git diff --name-only\`
    — not interpretive prose about user impact. PASS requires ALL of:
    (a) **Verifiable file/path claim**. ACCEPT vocabulary (positive, file/path-
        based; checkable via the diff-paths block above): \`no .tsx files
        modified\`, \`diff is supabase/migrations/** only\`, \`apps/web/components/**
        untouched\`. The claim must name a file extension, glob, or path that
        the reviewer can grep against the diff list above and confirm.
    (b) **No interpretive prose**. REJECT vocabulary (vibes about user impact;
        not file-system facts): \`no visible UI change\`, \`nothing user-facing
        changed\`, \`cosmetic only\`. These describe the operator's mental model
        of impact, not what's in the diff. A future reviewer cannot re-verify
        them without re-doing the same interpretation. FAIL.
    (c) **No bare 'migration only' / 'refactor only' / similar shorthand**.
        Worked example contrast — \"diff is \`supabase/migrations/**\` only\"
        PASSES (a path glob a reviewer can re-verify against the diff list);
        \"migration only\" alone FAILS (interpretive shorthand for the
        operator's mental model, not a file-system fact). The first names a
        glob that grep-checks; the second names a category. The Sonnet
        reviewer's job is to refuse to bridge that gap.
    (d) **Missing rationale entirely**. If the Reason is empty (the spec body
        was just bare \`N/A\` with nothing after it), automatic FAIL — no
        rationale to verify.
    Default: REJECT. Generic / interpretive / categorical-shorthand reasons
    FAIL even if they sound plausible. The verifiable-file-claim shape exists
    precisely so that the Gate 9 audit-trail surfaces a fact, not a vibe.
12. For blockedGateOverride (/ak-build Phase 3 → 4 halt override): the Reason
    is the operator's rationale for advancing past a \`blocked\` gate when
    the AskUserQuestion halt fired. The override is a stronger claim than a
    finding dismissal — the gate did NOT run at all — so the reviewer's bar
    is higher than for dismissalLog. PASS requires ALL of:
    (a) **Gate-specific reason** (not precedent). The reason must name what
        makes THIS PR's circumstances acceptable for advancing past the
        gate. ACCEPT: \"Chromium not installable in this devcontainer image;
        /design-review will run in CI on a host with playwright deps (tracked
        kit/TODOS.md § chromium-image-roll)\". REJECT: \"matches PR #27's
        override\", \"we've done this before\", \"same as last time\", \"sandbox
        env\" with no specifics. The Prior advance-log entries block in
        context above is the precedent surface — if the operator's reason is
        a near-copy of a prior entry's reason, that is the failure mode this
        rule exists to catch.
    (b) **No core-story crossing**. If the blocked gate covers any verb the
        spec's § Core user story names (sign-in / add / list / equivalent
        primary-flow assertion), the override is categorically NOT
        acceptable — the gate's evidence is load-bearing for the spec's
        contract, and the operator cannot wave it past. The Spec § Core
        user story block in context above names the verbs that are
        off-limits.
    (c) **Verifiable follow-up tracker**. The tracker pointer must be a
        path:section (e.g. \"kit/TODOS.md § chromium-image-roll\") or a
        GitHub issue URL. ACCEPT: a pointer the reviewer could grep against
        the repo's actual tracker files in 30 seconds. REJECT: \"will track
        later\", \"see follow-up\", \"tracked\" without naming the entry,
        empty Follow-up tracker pointer in context above.
    (d) **No In-scope contradiction**. If the blocked gate covers behavior
        the spec's § In scope explicitly committed to delivering, the
        override is NOT acceptable — the PR is shipping less than it
        promised. The Spec § In scope block in context above is the
        contract surface.
    Default: REJECT. The mechanical halt exists precisely because three
    prior PRs (home-os #15 / #27 / #28) shipped past blocked gates on
    rationale a Sonnet reviewer would have caught. The default-REJECT
    posture is the rule's load-bearing property: a borderline-plausible
    reason FAILS unless it visibly engages all four sub-criteria.
13. For pushToMainApproved: the Reason justifies pushing from a feature
    branch directly to refs/heads/main in the devshop repo. The ONLY
    legitimate path is /ak-merge-devshop Phase 3 after the full merge
    ceremony (audit + squash message composition + operator approval).
    PASS requires the reason to name the /ak-merge-devshop ceremony
    explicitly (e.g. \"/ak-merge-devshop Phase 3 — audit passed, squash
    approved\"). REJECT: \"small change\", \"doc fix\", \"single commit\",
    \"already reviewed\", \"trivial\", \"just a build-log update\", or any
    rationale that shortcuts the ceremony. The ceremony exists because
    the squash message is irreversible once pushed (force-push is blocked
    by check-not-force-push.sh). Manual recovery scenarios (the operator
    typing git -c in a raw terminal) are the only legitimate non-ceremony
    path — and even those should name the recovery context, not hand-wave.
14. For batsSkipReason: the Reason justifies committing despite bats test
    failures. Bats tests are the devshop's structural integrity suite —
    hooks, scripts, wiring invariants. Skipping them risks breaking the
    enforcement chain for future commits. PASS requires ALL of:
    (a) **Name the failing tests**. The reason must name the specific
        failing test(s) from the 'Failing test lines' block in context
        (e.g. \"test 629 'wiring: every non-exempt kit script is wired'
        fails because the new script isn't in infra_scripts yet\").
        REJECT: \"some tests fail\", \"a few failures\", \"pre-existing
        failures\" without naming which tests.
    (b) **Explain why skipping is safe for THIS commit**. The reason must
        explain why the specific failures don't undermine the commit's
        correctness (e.g. \"the failing test checks template sync which
        this commit doesn't touch — the failure is pre-existing from
        commit abc123\"). REJECT: \"will fix later\", \"not related to my
        changes\" without naming the test or the pre-existing cause,
        \"low risk\", \"minor\".
    (c) **No enforcement-chain breaks**. If the failing test is a wiring
        invariant (e.g. \"every non-exempt kit script is wired\") or a
        hook-correctness test (e.g. \"pre-commit blocks dirty tree\"),
        skipping it means the enforcement chain itself is compromised.
        The reason must acknowledge this and explain the recovery plan
        (e.g. \"will wire the new script in the next commit\" with a
        specific TODOS.md entry).
    (d) **No blanket skips**. A reason that justifies skipping ALL bats
        failures (\"the suite is flaky\", \"bats tests are slow\", \"will
        fix the suite later\") is categorically NOT acceptable. Each
        failure must be addressed individually.
    Default: REJECT. Generic reasons FAIL. The bats suite is the
    devshop's immune system — skipping it is a judgment call that
    requires per-test specificity.

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
  echo "⏳ Adversarial review ($CHECK_TYPE) — attempt $((ATTEMPT + 1))/$MAX_ATTEMPTS, ${TIMEOUT}s timeout, model=$MODEL"
  REVIEW=$(timeout "$TIMEOUT" claude -p --model "$MODEL" < "$PROMPT_FILE" 2>/dev/null) && break
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
    DELAY=${BACKOFF_DELAYS[$((ATTEMPT - 1))]}
    echo "⚠ Attempt $ATTEMPT failed. Retrying in ${DELAY}s..."
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
