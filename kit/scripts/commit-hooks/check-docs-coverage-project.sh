#!/bin/bash
# What: Pre-commit check (project repos) — flags code changes that touch documented surfaces
#       without a paired doc update.
# Why: Area READMEs (apps/<x>/, packages/<x>/, supabase/functions/), METRICS.md, OVERVIEW.md
#      and ARCHITECTURE.md decay silently as routes, API wrappers, and analytics events land.
#      Layer 1 catches the obvious gaps at commit time so audit-time `/ak-docs-review` can
#      focus on substance, not paperwork.
# Does NOT: Verify doc quality (the audit-time reviewer does). Does NOT block changelog/version bumps.
# Does NOT: Demand CLAUDE.md updates for new surfaces (post-2026-05-18 architecture migration —
#      CLAUDE.md is reserved for silent-failure traps + project framing per
#      `kit/docs/guide/claude-md.md § The inclusion rule`; surface inventory lives in area READMEs).
#
# Layer 1 only. Per-commit Sonnet judgment was removed alongside the audit-time
# migration (see kit/ROADMAP.md § PR-C). Bypass via
# `git -c devshop.docsCoverageReason="<why>"` accepts the commit without an LLM
# round-trip; the bypass is recorded as a `Docs-Coverage-Bypass:` trailer by
# the prepare-commit-msg hook (kit/scripts/commit-hooks/append-bypass-trailers.sh)
# and harvested at audit time by `/ak-docs-review`.
#
# Trigger map (staged path → required doc update):
#   apps/<x>/app/**/page.tsx (NEW user-visible page/flow)   → OVERVIEW.md (if exists)
#                                                            → ARCHITECTURE.md (if exists)
#   apps/<x>/** (NEW non-test under app/src/lib/hooks/etc)  → apps/<x>/README.md (NOW required —
#                                                              opt-in semantics: only when the README
#                                                              exists at HEAD)
#   packages/<x>/src/** (NEW, non-test)                     → packages/<x>/README.md (NOW required —
#                                                              opt-in)
#   supabase/functions/** (NEW, non-test)                   → supabase/functions/README.md (opt-in)
#   any new posthog.capture(...) / Sentry.captureException  → METRICS.md
#   removed source — doc must NOT still reference its name  → BLOCK
#
# Opt-in semantics: area-README and OVERVIEW/ARCHITECTURE triggers fire ONLY when the target
# doc file exists at HEAD. Projects opt in by creating the file from the template skeleton or
# during the CLAUDE.md architecture migration (`kit/docs/guide/claude-md.md § Migration recipe`).
#
# Per-project override: .devshop-docs-freshness-exempt at repo root (one path per line).

set -euo pipefail

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$GIT_ROOT" ] && exit 0

# Project-repo only.
if [ -d "$GIT_ROOT/kit" ] && [ ! -L "$GIT_ROOT/kit" ]; then exit 0; fi
[ "$GIT_ROOT" = "/devshop" ] && exit 0

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

METRICS_STAGED=false
OVERVIEW_STAGED=false
ARCHITECTURE_STAGED=false
echo "$STAGED" | grep -Fxq "METRICS.md" && METRICS_STAGED=true || true
echo "$STAGED" | grep -Fxq "OVERVIEW.md" && OVERVIEW_STAGED=true || true
echo "$STAGED" | grep -Fxq "ARCHITECTURE.md" && ARCHITECTURE_STAGED=true || true

# is_per_package_readme_staged <readme-path>
is_per_package_readme_staged() {
  echo "$STAGED" | grep -Fxq "$1"
}

# Collects per-area README requirements (opt-in: only when the README exists at
# HEAD-equivalent) and root-level OVERVIEW/ARCHITECTURE requirements for
# user-visible additions. CLAUDE.md is intentionally NOT a destination here
# (post-2026-05-18 architecture migration) — surface inventory lives in area
# READMEs; CLAUDE.md is reserved for silent-failure traps + project framing per
# kit/docs/guide/claude-md.md.
NEEDS_OVERVIEW=""           # set when a new user-visible page/flow lands AND OVERVIEW.md exists
NEEDS_ARCHITECTURE=""       # set when module-map-affecting structural change lands AND ARCHITECTURE.md exists
declare -A NEEDS_PACKAGE_README   # key: README path; value: accumulated reasons
while IFS= read -r f; do
  [ -z "$f" ] && continue
  is_override "$f" && continue

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
# Build the list of doc files to scan: CLAUDE.md (still scanned for stale refs
# even though it's no longer a coverage destination — pre-migration entries may
# still cite source paths) + always-present (METRICS) + opt-in (OVERVIEW,
# ARCHITECTURE) + every existing per-package README discovered at HEAD under
# apps/<x>/, packages/<x>/, and supabase/functions/.
STALE_TARGETS=()
[ -f "$GIT_ROOT/CLAUDE.md" ] && STALE_TARGETS+=("$GIT_ROOT/CLAUDE.md")
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
  # Bypass: accept on flag presence (no LLM call). Trailer emission is the
  # prepare-commit-msg hook's job — see append-bypass-trailers.sh.
  REASON=$(git config --get devshop.docsCoverageReason 2>/dev/null || true)
  if [ -n "$REASON" ]; then
    echo "$BLOCK_MSG"
    echo ""
    echo "⚠ Docs-coverage block bypassed: $REASON"
    echo "  → recorded as Docs-Coverage-Bypass: trailer; will be revisited at audit time."
    exit 0
  fi

  echo "$BLOCK_MSG"
  echo ""
  echo "  Convention: guide/conventions.md § Project Docs Coverage"
  echo ""
  echo "  Bypass for this commit (recorded as a Docs-Coverage-Bypass: trailer):"
  echo "    git -c devshop.docsCoverageReason=\"<per-doc enumeration of what's affected and why no update needed; with named distinctive phrases for each AFFECTED edit per audit rule 1(a)>\" commit ..."
  exit 1
fi

exit 0
