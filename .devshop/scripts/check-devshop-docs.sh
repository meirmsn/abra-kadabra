#!/bin/bash
# check-devshop-docs.sh — pre-commit nudge: if one devshop reference doc is staged,
# remind to verify the other is in sync. Not a hard block — prints a warning only.
# Checks two pairs:
#   1. .devshop/README.md + .devshop/GUIDE.md (reference docs)
#   2. init/SKILL.md + .devshop/templates/README.md.tmpl (template landing page)
# Build blueprints (.devshop/notes/bootstrap/) are independent — no sync enforcement.
set -euo pipefail

STAGED=$(git diff --cached --name-only)

HAS_README=false
HAS_GUIDE=false

echo "$STAGED" | grep -q '^\.devshop/README\.md$' && HAS_README=true
echo "$STAGED" | grep -q '^\.devshop/GUIDE\.md$' && HAS_GUIDE=true

if [ "$HAS_README" = true ] || [ "$HAS_GUIDE" = true ]; then
  if [ "$HAS_README" = true ] && [ "$HAS_GUIDE" = true ]; then
    # Both staged — good, no warning needed
    :
  else
    echo ""
    echo "⚠ Devshop reference doc changed — verify both are in sync:"
    echo "  .devshop/README.md  (bird's eye)"
    echo "  .devshop/GUIDE.md   (full reference)"
    echo ""
  fi
fi

# Nudge: init skill changes may affect the template README (prerequisites, auth, getting started)
HAS_INIT=false
HAS_TMPL_README=false

echo "$STAGED" | grep -q '^\.claude/skills/devshop/init/SKILL\.md$' && HAS_INIT=true
echo "$STAGED" | grep -q '^\.devshop/templates/README\.md\.tmpl$' && HAS_TMPL_README=true

if [ "$HAS_INIT" = true ] && [ "$HAS_TMPL_README" = false ]; then
  echo ""
  echo "⚠ Init skill changed — verify template README is still accurate:"
  echo "  .devshop/templates/README.md.tmpl  (template repo landing page)"
  echo ""
fi
