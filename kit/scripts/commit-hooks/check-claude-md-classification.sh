#!/bin/bash
# What: Pre-commit check — blocks CLAUDE.md additions/modifications unless a
#       `claudeMdClassification` bypass flag classifies each entry as
#       trap / reference / convention per the inclusion rule.
# Why: Mechanical gate (Layer B) that prevents CLAUDE.md regrowth by requiring
#      per-entry classification + placement at commit time. Reference and
#      convention content must be relocated to its canonical home in the same
#      commit (for skill-operational logic — a step/check/gate a named skill
#      performs — that home is the owning skill's SKILL.md, per the
#      skill-operational routing row in kit/docs/guide/claude-md.md); trap
#      entries must declare and justify their target section.
# Does NOT: Judge classification quality (the adversarial reviewer does that).
#           Fire on pure deletions (removing content is unconditionally good).
#
# Fires in BOTH devshop and project repos — CLAUDE.md exists in both, and the
# routing table in kit/docs/guide/claude-md.md handles destination differences.
#
# Bypass via `git -c devshop.claudeMdClassification="trap → § <section>: <entry> — <why>"`.
# The adversarial reviewer (Sonnet) judges classification accuracy against the
# inclusion rule + routing table, placement fit (the entry earns its spot in the
# named section; a NEW section must justify why no existing section fits), and
# verifies relocations landed in the same commit. The bypass is recorded as a
# `Claude-MD-Classification:` trailer by
# the prepare-commit-msg hook (kit/scripts/commit-hooks/append-bypass-trailers.sh)
# and harvested at audit time by `/ak-docs-review`.

set -euo pipefail

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$GIT_ROOT" ] && exit 0

STAGED=$(git diff --cached --name-only 2>/dev/null || true)
[ -z "$STAGED" ] && exit 0

# Check if CLAUDE.md is among the staged files
HAS_CLAUDE_MD=false
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ "$f" = "CLAUDE.md" ]; then
    HAS_CLAUDE_MD=true
    break
  fi
done <<< "$STAGED"

[ "$HAS_CLAUDE_MD" = false ] && exit 0

# Check if the diff is pure deletion — no added/modified lines.
# Parse git diff for `+`-prefixed lines (excluding the `+++ b/CLAUDE.md` header).
# If zero `+` lines exist, it is pure deletion → exit 0 (D1).
# Uses awk instead of grep to avoid regex-engine portability issues
# (ugrep's default mode rejects `^\+\+\+` as invalid syntax).
ADDED_LINES=$(git diff --cached CLAUDE.md 2>/dev/null \
  | awk '/^\+/ && !/^\+\+\+/' | wc -l | tr -d ' ')

if [ "$ADDED_LINES" -eq 0 ]; then
  exit 0
fi

# Check bypass flag
REASON=$(git config --get devshop.claudeMdClassification 2>/dev/null || true)

if [ -n "$REASON" ]; then
  # Resolve adversarial-review.sh path: worktree or canonical devshop
  SCRIPTS_DIR=""
  if [ -d "$GIT_ROOT/kit/scripts" ] && [ ! -L "$GIT_ROOT/kit" ]; then
    SCRIPTS_DIR="$GIT_ROOT/kit/scripts"
  elif [ -d "/devshop/kit/scripts" ]; then
    SCRIPTS_DIR="/devshop/kit/scripts"
  fi

  if [ -n "$SCRIPTS_DIR" ] && [ -f "$SCRIPTS_DIR/adversarial-review.sh" ]; then
    bash "$SCRIPTS_DIR/adversarial-review.sh" claudeMdClassification "$REASON"
    exit $?
  else
    echo ""
    echo "⚠ CLAUDE.md classification bypass accepted (adversarial-review.sh not found)"
    echo "  Classification: $REASON"
    echo "  → recorded as Claude-MD-Classification: trailer; will be revisited at audit time."
    exit 0
  fi
fi

# No bypass flag — block with guidance
echo ""
echo "✖ BLOCKING: CLAUDE.md staged with additions/modifications but no classification."
echo ""
echo "  Every addition to CLAUDE.md must pass the inclusion test:"
echo "    Belongs in CLAUDE.md = causes SILENT wrong work if not known."
echo ""
echo "  Classify each addition as trap / reference / convention:"
echo "    - trap:       silent wrong work if forgotten → stays in CLAUDE.md"
echo "    - reference:  look-it-up information → relocate to canonical home"
echo "    - convention: already documented in a guide → delete the duplicate"
echo ""
echo "  Skill-operational logic (a step / check / gate / decision a NAMED skill"
echo "  performs — only bites once you're inside that skill's run) is reference"
echo "  content whose canonical home is that skill's SKILL.md, NOT CLAUDE.md —"
echo "  even when phrased as an ambient directive. Keep at most a one-line value"
echo "  + pointer inline; relocate the mechanic to the skill in the same commit."
echo ""
echo "  Each trap must also declare its placement — which section it lands in,"
echo "  and (if it needs a NEW section) why no existing section fits:"
echo "    - extends existing section → name the section; it must be the closest home"
echo "    - NEW section              → justify why no existing section fits (high bar)"
echo ""
echo "  Usage:"
echo "    git -c devshop.claudeMdClassification=\"trap → § <section>: <entry> — <why silent>; placement: <extends|NEW> — <why>\" commit ..."
echo ""
echo "  Reference/convention entries must be relocated to their canonical home"
echo "  (guide doc, area README, code comment, or owning skill's SKILL.md for"
echo "  skill-operational logic) in the same commit."
echo ""
echo "  See kit/docs/guide/claude-md.md for the routing table + inclusion rule."
exit 1
