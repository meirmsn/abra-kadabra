#!/usr/bin/env bash
# What: Classify a git range as "tracker-only / no source surface" vs "has
#       source surface to audit", so /ak-check-docs-and-tests can short-circuit
#       doc-only merges instead of scaffolding an orphan review.md stub.
# Why:  Doc-only / tracker-only devshop merges left orphan specs/<feature>/review.md
#       stubs behind. Classifying the diff up front (this helper) lets Step 1
#       exit cleanly when there is no auditable source surface.
# Does NOT: run any audit, scaffold/modify review.md, or call the sub-skills —
#       it only reports the verdict via exit code (0 short-circuit / 1 audit).
#
# Usage:
#   audit-tracker-only.sh <git-range>
#
# Exit codes:
#   0 — tracker-only (every changed path matches the tracker set, incl. empty
#       diff) → caller short-circuits, no scaffold
#   1 — has source surface (≥1 changed path is NOT a tracker path) → caller audits
#  64 — usage error (no range argument)
#
# Tracker set (spec D2) — a path is a tracker path iff it matches ANY of:
#   ^(PLAN|TODOS|BUILD-LOG|PRODUCT-ROADMAP|DEPS-WATCH)\.md$   (exact)
#   ^kit/(TODOS|ROADMAP)\.md$                 (exact — TODOS/ROADMAP are files)
#   ^kit/notes/                              (dir prefix — kit/notes/** are trackers)
#   ^kit/version$                            (exact — extensionless file)
#   ^kit/docs/CHANGELOG\.md$                  (exact — NOT all of kit/docs/)
#   ^kit/FRICTION-LOG\.md$
# Anchored exact (not prefix) on the file trackers so a future kit/versioning.md,
# kit/ROADMAPER, or kit/TODOS-archive.md is NOT falsely swept as tracker-only.
# Deliberately NOT trackers (auditable source surface): kit/docs/guide/**,
# kit/tests/**, all kit/scripts/**, .claude/skills/**, template/**, and any
# project-side apps/ packages/ src/ app/ path.
#
# POSIX-clean body (case globbing, no regex engine) so dash-sourcing is safe.
#
# Spec: specs/ak-check-docs-orphan-stubs/spec.md

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <git-range>" >&2
  exit 64
fi

RANGE="$1"

# Resolve the changed-path set first, in command position, so a failing
# `git diff` (e.g. a bad/rewritten-history range) is NOT swallowed into a
# false "empty diff" verdict. `set -e` does NOT catch a failure inside a
# `$(...)` used as heredoc/redirection input, so capture + check explicitly.
# Safe direction on diff failure: exit 1 (caller audits) — never short-circuit
# an audit away on an unresolvable range.
if ! CHANGED=$(git diff --name-only "$RANGE"); then
  echo "audit-tracker-only: could not resolve range '$RANGE' — not short-circuiting" >&2
  exit 1
fi

# Classify every changed path. Short-circuit to exit 1 on the first non-tracker
# (source) path — no need to scan the rest. Empty diff falls through to exit 0.
while IFS= read -r path; do
  [ -z "$path" ] && continue
  case "$path" in
    PLAN.md|TODOS.md|BUILD-LOG.md|PRODUCT-ROADMAP.md|DEPS-WATCH.md) ;;
    kit/TODOS.md|kit/ROADMAP.md|kit/notes/*|kit/version) ;;
    kit/docs/CHANGELOG.md) ;;
    kit/FRICTION-LOG.md) ;;
    *)
      # Any other path is auditable source surface → caller must audit.
      exit 1
      ;;
  esac
done <<EOF
$CHANGED
EOF

# Every changed path (or none) was a tracker path → no source surface to audit.
echo "✓ tracker-only: no source surface to audit (short-circuit)"
exit 0
