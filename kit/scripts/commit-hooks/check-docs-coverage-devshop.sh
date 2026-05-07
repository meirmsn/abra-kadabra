#!/bin/bash
# What: Pre-commit check (devshop self) — flags devshop-source surfaces touched without
#       a paired guide / orientation doc in the same commit.
# Why: Layer 1 deterministic file-pairing for devshop docs. Audit-time `/ak-docs-review`
#      judges quality + cross-file coherence at audit moments — this hook just catches
#      the obvious "added a script, forgot to mention it anywhere" gap at commit time.
# Does NOT: Verify doc quality / cross-file coherence (the audit-time reviewer does).
#
# Layer 1 only. Per-commit Sonnet judgment was removed alongside the audit-time
# migration (see kit/ROADMAP.md § PR-C). Bypass via
# `git -c devshop.docsCoverageReason="<why>"` accepts the commit without an LLM
# round-trip; the bypass is recorded as a `Docs-Coverage-Bypass:` trailer by
# the prepare-commit-msg hook (kit/scripts/commit-hooks/append-bypass-trailers.sh)
# and harvested at audit time by `/ak-docs-review`.
#
# Surface → required staged doc map (at least one per surface):
#
#   kit/scripts/**.sh                                       → any kit/docs/guide/*.md OR CLAUDE.md
#   kit/scripts/commit-hooks/**                             → kit/docs/guide/hooks.md
#   kit/scripts/preship/**                                  → .claude/skills/devshop/pre-ship/SKILL.md
#                                                             OR kit/docs/guide/*
#   kit/hooks/**                                            → kit/docs/guide/hooks.md OR CLAUDE.md
#   .claude/skills/**/SKILL.md                              → kit/docs/guide/workflow.md OR CLAUDE.md
#   template/**  (excl. template/.devcontainer/.env*)       → kit/docs/guide/{architecture,security,ops}.md
#   .devcontainer/**  (excl. .env)                          → kit/docs/guide/{security,ops}.md
#   kit/manifest.txt                                        → kit/docs/guide/architecture.md
#
# Carve-outs (no firing): kit/notes/**, kit/ROADMAP.md, kit/TODOS.md, kit/docs/CHANGELOG.md,
# kit/version, kit/tests/**, kit/docs/** itself (audit handles guide-only commits).

set -euo pipefail

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$GIT_ROOT" ] && exit 0

# Devshop-self only. kit/ is a real directory in the devshop repo (not a symlink).
if [ -d "$GIT_ROOT/kit" ] && [ ! -L "$GIT_ROOT/kit" ]; then
  : # devshop-self mode, continue
elif [ "$GIT_ROOT" = "/devshop" ]; then
  : # devshop repo, continue
else
  exit 0
fi

STAGED=$(git diff --cached --name-only 2>/dev/null || true)
[ -z "$STAGED" ] && exit 0

# Apply carve-outs first — these paths never fire the hook regardless of co-staging.
# Returns 0 (true) if path is fully carved out.
is_carveout() {
  case "$1" in
    kit/notes/*|kit/ROADMAP.md|kit/TODOS.md|kit/docs/CHANGELOG.md|kit/version) return 0 ;;
    kit/tests/*|kit/docs/*) return 0 ;;
    template/.devcontainer/.env*|.devcontainer/.env*) return 0 ;;
  esac
  return 1
}

# Identify which surface groups appear in STAGED. Each group has its own
# acceptable-doc set (any one of those staged satisfies the requirement).
SURFACE_HITS=""              # human-readable list of staged source paths that fired a surface
declare -A NEEDS_DOCS=()     # key = surface label, value = pipe-separated list of acceptable docs

while IFS= read -r f; do
  [ -z "$f" ] && continue
  is_carveout "$f" && continue

  case "$f" in
    kit/scripts/commit-hooks/*)
      NEEDS_DOCS["commit-hooks"]="kit/docs/guide/hooks.md"
      SURFACE_HITS+="    $f → guide/hooks.md"$'\n'
      ;;
    kit/scripts/preship/*)
      NEEDS_DOCS["preship"]=".claude/skills/devshop/pre-ship/SKILL.md|kit/docs/guide/workflow.md|kit/docs/guide/conventions.md|kit/docs/guide/hooks.md|kit/docs/guide/architecture.md|kit/docs/guide/security.md|kit/docs/guide/ops.md|kit/docs/guide/supabase-ssr-boilerplate.md"
      SURFACE_HITS+="    $f → pre-ship SKILL.md OR any guide/*.md"$'\n'
      ;;
    kit/scripts/*.sh|kit/scripts/sync/*|kit/scripts/notify/*)
      NEEDS_DOCS["scripts"]="CLAUDE.md|kit/docs/guide/workflow.md|kit/docs/guide/conventions.md|kit/docs/guide/hooks.md|kit/docs/guide/architecture.md|kit/docs/guide/security.md|kit/docs/guide/ops.md|kit/docs/guide/supabase-ssr-boilerplate.md"
      SURFACE_HITS+="    $f → CLAUDE.md OR any guide/*.md"$'\n'
      ;;
    kit/hooks/*)
      NEEDS_DOCS["hooks"]="kit/docs/guide/hooks.md|CLAUDE.md"
      SURFACE_HITS+="    $f → guide/hooks.md OR CLAUDE.md"$'\n'
      ;;
    .claude/skills/*/SKILL.md)
      NEEDS_DOCS["skills"]="kit/docs/guide/workflow.md|CLAUDE.md"
      SURFACE_HITS+="    $f → guide/workflow.md OR CLAUDE.md"$'\n'
      ;;
    template/*)
      NEEDS_DOCS["template"]="kit/docs/guide/architecture.md|kit/docs/guide/security.md|kit/docs/guide/ops.md"
      SURFACE_HITS+="    $f → guide/{architecture,security,ops}.md"$'\n'
      ;;
    .devcontainer/*)
      NEEDS_DOCS["devcontainer"]="kit/docs/guide/security.md|kit/docs/guide/ops.md"
      SURFACE_HITS+="    $f → guide/{security,ops}.md"$'\n'
      ;;
    kit/manifest.txt)
      NEEDS_DOCS["manifest"]="kit/docs/guide/architecture.md"
      SURFACE_HITS+="    $f → guide/architecture.md"$'\n'
      ;;
  esac
done <<< "$STAGED"

[ "${#NEEDS_DOCS[@]}" -eq 0 ] && exit 0

# A surface is satisfied if ANY of its acceptable docs is staged.
UNSATISFIED=""
for surface in "${!NEEDS_DOCS[@]}"; do
  IFS='|' read -ra ACCEPTABLE <<< "${NEEDS_DOCS[$surface]}"
  satisfied=false
  for doc in "${ACCEPTABLE[@]}"; do
    if echo "$STAGED" | grep -Fxq "$doc"; then
      satisfied=true
      break
    fi
  done
  if [ "$satisfied" = false ]; then
    UNSATISFIED+="    $surface (acceptable docs: ${NEEDS_DOCS[$surface]//|/ , })"$'\n'
  fi
done

[ -z "$UNSATISFIED" ] && exit 0

# Bypass: accept on flag presence (no LLM call). Trailer emission is the
# prepare-commit-msg hook's job — see append-bypass-trailers.sh.
REASON=$(git config --get devshop.docsCoverageReason 2>/dev/null || true)
if [ -n "$REASON" ]; then
  echo ""
  echo "⚠ Docs-coverage block bypassed: $REASON"
  echo "  Surfaces touched:"
  echo -n "$SURFACE_HITS"
  echo "  Unsatisfied:"
  echo -n "$UNSATISFIED"
  echo "  → recorded as Docs-Coverage-Bypass: trailer; will be revisited at audit time."
  exit 0
fi

echo ""
echo "✖ BLOCKING: Devshop surfaces touched without a paired guide / orientation doc:"
echo -n "$SURFACE_HITS"
echo ""
echo "  Unsatisfied surface groups (need at least one acceptable doc staged):"
echo -n "$UNSATISFIED"
echo ""
echo "  Options:"
echo "    1. Stage the relevant doc with a substantive update."
echo "    2. Bypass for this commit (recorded as a Docs-Coverage-Bypass: trailer):"
echo "       git -c devshop.docsCoverageReason=\"<per-doc enumeration of all 11 catalog docs;"
echo "         AFFECTED edits name a distinctive phrase from the diff per audit rule 1(a);"
echo "         NOT-AFFECTED docs get a grep-verified zero-match attestation>\" commit ..."
echo ""
echo "  See kit/docs/guide/conventions.md § Bypass trailers for the full convention."
exit 1
