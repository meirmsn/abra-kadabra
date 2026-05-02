#!/bin/bash
# What: Pre-commit check (project repos) — flags code changes that touch documented surfaces
#       without a paired doc update.
# Why: CLAUDE.md § Where Things Happen, METRICS.md, and TODOS.md decay silently as routes,
#      API wrappers, and analytics events land. Layer-1 deterministic check + Layer-2
#      adversarial reviewer makes the convention enforceable instead of advisory.
# Does NOT: Verify doc quality (the reviewer does). Does NOT block changelog/version bumps.
#
# Trigger map (staged path → required doc update):
#   apps/*/app/**/page.tsx, layout.tsx, route.ts            → CLAUDE.md (must be staged)
#   apps/*/middleware.ts                                    → CLAUDE.md
#   packages/*/src/api/*.ts (NEW)                           → CLAUDE.md
#   any new posthog.capture(...) / Sentry.captureException  → METRICS.md
#   apps/<x>/app/**/page.tsx (NEW user-visible page/flow)   → OVERVIEW.md (if exists)
#                                                            → ARCHITECTURE.md (if exists)
#   apps/<x>/** (NEW)                                       → apps/<x>/README.md (if exists)
#   packages/<x>/src/** (NEW, non-test)                     → packages/<x>/README.md (if exists)
#   supabase/functions/** (NEW, non-test)                   → supabase/functions/README.md (if exists)
#   removed source — doc must NOT still reference its name  → BLOCK
#
# Opt-in semantics: per-package and OVERVIEW/ARCHITECTURE triggers fire ONLY when the target
# doc file exists at HEAD. Projects opt in by creating the file from the template skeleton.
#
# Bypass: git -c devshop.docsFreshnessReviewed="<per-doc enumeration>" commit ...
#
# Per-project override: .devshop-docs-freshness-exempt at repo root (one path per line).

set -euo pipefail

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$GIT_ROOT" ] && exit 0

# Project-repo only.
if [ -d "$GIT_ROOT/kit" ] && [ ! -L "$GIT_ROOT/kit" ]; then exit 0; fi
[ "$GIT_ROOT" = "/devshop" ] && exit 0

CLAUDE_MD="$GIT_ROOT/CLAUDE.md"
METRICS_MD="$GIT_ROOT/METRICS.md"
OVERVIEW_MD="$GIT_ROOT/OVERVIEW.md"
ARCHITECTURE_MD="$GIT_ROOT/ARCHITECTURE.md"
OVERRIDE_FILE="$GIT_ROOT/.devshop-docs-freshness-exempt"

# doc_exists checks the working tree (HEAD-equivalent for opt-in semantics — a file
# that doesn't exist on disk also can't be staged-as-modified, so working-tree presence
# is a sufficient proxy without a `git cat-file` round-trip per check).
doc_exists() { [ -f "$1" ]; }

is_override() {
  [ -f "$OVERRIDE_FILE" ] || return 1
  # Strip whole-line comments, trailing inline comments, surrounding whitespace,
  # and blank lines; then exact-match. Both `path` and `path  # reason` work.
  sed -E 's/[[:space:]]*#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//' "$OVERRIDE_FILE" 2>/dev/null \
    | grep -v '^$' \
    | grep -Fxq "$1"
}

STAGED=$(git diff --cached --name-only 2>/dev/null || true)
ADDED=$(git diff --cached --name-only --diff-filter=A 2>/dev/null || true)
DELETED=$(git diff --cached --name-only --diff-filter=D 2>/dev/null || true)
[ -z "$STAGED" ] && exit 0

CLAUDE_STAGED=false
METRICS_STAGED=false
OVERVIEW_STAGED=false
ARCHITECTURE_STAGED=false
echo "$STAGED" | grep -Fxq "CLAUDE.md" && CLAUDE_STAGED=true || true
echo "$STAGED" | grep -Fxq "METRICS.md" && METRICS_STAGED=true || true
echo "$STAGED" | grep -Fxq "OVERVIEW.md" && OVERVIEW_STAGED=true || true
echo "$STAGED" | grep -Fxq "ARCHITECTURE.md" && ARCHITECTURE_STAGED=true || true

# is_per_package_readme_staged <readme-path>
is_per_package_readme_staged() {
  echo "$STAGED" | grep -Fxq "$1"
}

# Triggers requiring CLAUDE.md update — applied to ADDED files only.
# Also collects per-package README requirements (opt-in: only when the README
# exists at HEAD-equivalent) and root-level OVERVIEW/ARCHITECTURE requirements
# for user-visible additions.
NEEDS_CLAUDE=""
NEEDS_OVERVIEW=""           # set when a new user-visible page/flow lands AND OVERVIEW.md exists
NEEDS_ARCHITECTURE=""       # set when module-map-affecting structural change lands AND ARCHITECTURE.md exists
declare -A NEEDS_PACKAGE_README   # key: README path; value: accumulated reasons
while IFS= read -r f; do
  [ -z "$f" ] && continue
  is_override "$f" && continue

  # CLAUDE.md (existing rules).
  case "$f" in
    apps/*/app/*page.tsx|apps/*/app/*layout.tsx|apps/*/app/*route.ts|apps/*/app/*middleware.ts)
      NEEDS_CLAUDE+="    $f (new page/layout/route)"$'\n'
      ;;
    apps/*/middleware.ts)
      NEEDS_CLAUDE+="    $f (new middleware)"$'\n'
      ;;
    packages/*/src/api/*.ts)
      # Skip test files
      case "$f" in *.test.ts|*.integration.test.ts) ;; *)
        NEEDS_CLAUDE+="    $f (new API wrapper)"$'\n'
      ;;
      esac
      ;;
  esac

  # OVERVIEW.md (product-level): new user-visible page or layout, opt-in.
  if doc_exists "$OVERVIEW_MD"; then
    case "$f" in
      apps/*/app/*page.tsx|apps/*/app/*layout.tsx)
        NEEDS_OVERVIEW+="    $f (new user-visible page/flow)"$'\n'
        ;;
    esac
  fi

  # ARCHITECTURE.md (system-level): module-map-affecting changes, opt-in.
  # Specifically: a NEW package/app/function module (not just a file inside one).
  # The dead-reckoning is "first source file under a packages/<x>/, apps/<x>/, or
  # supabase/functions/<x>/ dir" — but we lack cheap "is this the first" knowledge,
  # so fire on directory-creating additions: detect by extracting the package dir
  # and checking if that's the only file we've seen in it. Simpler approximation:
  # fire on any add under apps/ or supabase/functions/ that creates a top-level
  # entrypoint (page/route/layout/middleware/index.ts) — these are the load-bearing
  # surfaces a module map cares about.
  if doc_exists "$ARCHITECTURE_MD"; then
    case "$f" in
      apps/*/app/*page.tsx|apps/*/app/*route.ts|apps/*/middleware.ts|supabase/functions/*/index.ts)
        NEEDS_ARCHITECTURE+="    $f (module-map surface added)"$'\n'
        ;;
    esac
  fi

  # Per-package README (opt-in). Match apps/<name>/, packages/<name>/, supabase/functions/.
  case "$f" in
    *.test.ts|*.integration.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx) ;;
    apps/*/*)
      # Extract apps/<name>/.
      pkg_dir=$(echo "$f" | awk -F/ '{print $1"/"$2}')
      readme="$pkg_dir/README.md"
      if doc_exists "$GIT_ROOT/$readme"; then
        NEEDS_PACKAGE_README["$readme"]+="    $f"$'\n'
      fi
      ;;
    packages/*/src/*)
      pkg_dir=$(echo "$f" | awk -F/ '{print $1"/"$2}')
      readme="$pkg_dir/README.md"
      if doc_exists "$GIT_ROOT/$readme"; then
        NEEDS_PACKAGE_README["$readme"]+="    $f"$'\n'
      fi
      ;;
    supabase/functions/*/*)
      readme="supabase/functions/README.md"
      if doc_exists "$GIT_ROOT/$readme"; then
        NEEDS_PACKAGE_README["$readme"]+="    $f"$'\n'
      fi
      ;;
  esac
done <<< "$ADDED"

# Triggers requiring METRICS.md update — fires on any staged file (added or modified)
# whose diff introduces a new posthog.capture(...) or Sentry.captureException(...) call.
NEEDS_METRICS=""
# Fetch the staged diff once and grep added lines for new event call-sites.
DIFF_FULL=$(git diff --cached 2>/dev/null || true)
# Match lines starting with '+' (added) that contain the analytics calls.
NEW_EVENT_LINES=$(echo "$DIFF_FULL" \
  | grep -E '^\+[^+]' \
  | grep -E 'posthog\.capture\s*\(|Sentry\.captureException\s*\(' \
  | head -10 || true)
if [ -n "$NEW_EVENT_LINES" ]; then
  NEEDS_METRICS+="    new posthog.capture(...) / Sentry.captureException(...) call site(s)"$'\n'
fi

# Stale-reference check on DELETE: if a source path is removed, no project-level
# orientation doc may still mention its full path.
STALE_REFS=""
# Build the list of doc files to scan: always-present (CLAUDE, METRICS) + opt-in
# (OVERVIEW, ARCHITECTURE) + every existing per-package README discovered at HEAD
# under apps/<x>/, packages/<x>/, and supabase/functions/.
STALE_TARGETS=()
[ -f "$CLAUDE_MD" ] && STALE_TARGETS+=("$CLAUDE_MD")
[ -f "$METRICS_MD" ] && STALE_TARGETS+=("$METRICS_MD")
[ -f "$OVERVIEW_MD" ] && STALE_TARGETS+=("$OVERVIEW_MD")
[ -f "$ARCHITECTURE_MD" ] && STALE_TARGETS+=("$ARCHITECTURE_MD")
while IFS= read -r readme; do
  [ -z "$readme" ] && continue
  STALE_TARGETS+=("$readme")
done < <(find "$GIT_ROOT/apps" "$GIT_ROOT/packages" "$GIT_ROOT/supabase/functions" \
  -maxdepth 3 -name README.md -type f 2>/dev/null || true)

while IFS= read -r f; do
  [ -z "$f" ] && continue
  # Match the full path — narrow enough to avoid false positives.
  for target in "${STALE_TARGETS[@]}"; do
    if grep -qF "$f" "$target" 2>/dev/null; then
      rel="${target#$GIT_ROOT/}"
      STALE_REFS+="    $f referenced in $rel after delete"$'\n'
    fi
  done
done <<< "$DELETED"

FAILED=false
BLOCK_MSG=""

if [ -n "$NEEDS_CLAUDE" ] && [ "$CLAUDE_STAGED" = false ]; then
  BLOCK_MSG+="
✖ BLOCKING: New surface added that requires CLAUDE.md § Where Things Happen update:
${NEEDS_CLAUDE}  CLAUDE.md is NOT staged in this commit. Add a Where-Things-Happen entry
  pointing at the new path, or add the path to .devshop-docs-freshness-exempt."
  FAILED=true
fi

if [ -n "$NEEDS_METRICS" ] && [ "$METRICS_STAGED" = false ]; then
  BLOCK_MSG+="
✖ BLOCKING: New analytics event call sites added without METRICS.md update:
${NEEDS_METRICS}  Stage METRICS.md with an entry for the new event(s), or add to override."
  FAILED=true
fi

if [ -n "$NEEDS_OVERVIEW" ] && [ "$OVERVIEW_STAGED" = false ]; then
  BLOCK_MSG+="
✖ BLOCKING: New user-visible page/flow added but OVERVIEW.md NOT staged:
${NEEDS_OVERVIEW}  Stage OVERVIEW.md with the new flow described under § Core flows or § Features,
  or add the path to .devshop-docs-freshness-exempt."
  FAILED=true
fi

if [ -n "$NEEDS_ARCHITECTURE" ] && [ "$ARCHITECTURE_STAGED" = false ]; then
  BLOCK_MSG+="
✖ BLOCKING: Module-map surface added but ARCHITECTURE.md NOT staged:
${NEEDS_ARCHITECTURE}  Stage ARCHITECTURE.md with the new component documented under § Components
  or § Module map, or add the path to .devshop-docs-freshness-exempt."
  FAILED=true
fi

# Per-package README requirements (one block per missing README).
for readme in "${!NEEDS_PACKAGE_README[@]}"; do
  if ! is_per_package_readme_staged "$readme"; then
    paths="${NEEDS_PACKAGE_README[$readme]}"
    BLOCK_MSG+="
✖ BLOCKING: New file(s) under the package documented at $readme without that README staged:
${paths}  Stage $readme with the new file(s) noted in its module map / route map / function list,
  or add the path(s) to .devshop-docs-freshness-exempt."
    FAILED=true
  fi
done

if [ -n "$STALE_REFS" ]; then
  BLOCK_MSG+="
✖ BLOCKING: Source paths deleted but still referenced in docs:
${STALE_REFS}  Remove or update the doc references in the same commit."
  FAILED=true
fi

if [ "$FAILED" = true ]; then
  echo "$BLOCK_MSG"
  echo ""
  echo "  Convention: guide/conventions.md § Project Docs Freshness"
  echo ""
  REASON=$(git config --get devshop.docsFreshnessReviewed 2>/dev/null || true)
  if [ -n "$REASON" ]; then
    SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
    REVIEW_CONTEXT="Project docs-freshness hook blocking. Developer's reason:
$REASON

Blocked items (raw hook output):
$BLOCK_MSG

CLAUDE.md staged in this commit: $CLAUDE_STAGED
METRICS.md staged in this commit: $METRICS_STAGED
OVERVIEW.md staged in this commit: $OVERVIEW_STAGED
ARCHITECTURE.md staged in this commit: $ARCHITECTURE_STAGED

Staged file list:
$STAGED"
    echo "⏳ Docs-freshness bypass: reviewing reason with adversarial agent..."
    if RESULT=$(bash "$SCRIPT_DIR/../adversarial-review.sh" docsReviewed "$REVIEW_CONTEXT" 2>&1); then
      echo "✓ Docs-freshness bypass: adversarial review accepted."
      exit 0
    else
      echo ""
      echo "✖ ADVERSARIAL REVIEW REJECTED the reason."
      echo "  $RESULT"
      exit 1
    fi
  fi
  echo "  Bypass: git -c devshop.docsFreshnessReviewed=\"<per-doc enumeration of what's affected and why no update needed>\" commit ..."
  exit 1
fi

exit 0
