#!/bin/bash
# propagation-entry.sh — extract **Existing projects:** blocks from commits
# since a tag and append a versioned section to PROPAGATION.md.
# Called by release.sh after version bumps.
#
# Usage:
#   propagation-entry.sh <version> <last-tag> [propagation-path]
set -euo pipefail

VERSION="${1:?Usage: propagation-entry.sh <version> <last-tag> [propagation-path]}"
LAST_TAG="${2:?Usage: propagation-entry.sh <version> <last-tag> [propagation-path]}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_PROPAGATION="$(cd "$SCRIPT_DIR/../.." && pwd)/kit/docs/PROPAGATION.md"
PROPAGATION="${3:-$DEFAULT_PROPAGATION}"

if [ ! -f "$PROPAGATION" ]; then
  echo "ERROR: $PROPAGATION not found."
  exit 1
fi

ENTRIES=""

while IFS= read -r sha; do
  [ -z "$sha" ] && continue
  SUBJECT=$(git log -1 --format='%s' "$sha")
  BODY=$(git log -1 --format='%b' "$sha")

  # Detect MORE THAN ONE **Existing projects:** marker in the body. The
  # convention is one block per commit; the extractor below only processes the
  # first. A second block's tag is invisible to the line-1 tag parse, so a real
  # [manual]/[conditional] step in block 2 would be SILENTLY DROPPED (D2). Warn
  # loudly so it can't vanish without a signal; we still process only the first.
  PROP_MARKER_COUNT=$(printf '%s\n' "$BODY" | grep -cE '^\*\*Existing projects:\*\*' || true)
  if [ "${PROP_MARKER_COUNT:-0}" -gt 1 ]; then
    echo "WARN: ${sha:0:9} '${SUBJECT}' has ${PROP_MARKER_COUNT} **Existing projects:** blocks — only the first is processed; consolidate into one block." >&2
  fi

  # Extract the **Existing projects:** block. It runs from the FIRST marker
  # through the next section break (---, ##, Key details:, a SECOND marker, or
  # EOF). Stopping at the second marker keeps a concatenated block-2 (no section
  # break between them) out of $BLOCK so its tag can't mis-classify block 1.
  BLOCK=$(echo "$BODY" | awk '
    /^\*\*Existing projects:\*\*/ && found { exit }
    /^\*\*Existing projects:\*\*/ { found=1; sub(/^\*\*Existing projects:\*\* */, ""); }
    found && /^---$/ { exit }
    found && /^## / { exit }
    found && /^Key details:/ { exit }
    found { print }
  ')

  BLOCK=$(echo "$BLOCK" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sed '/^$/d')
  # Collapse any internal newlines to single spaces so a multi-line block (tag
  # alone on line 1, step text on line 2) renders as ONE clean Markdown bullet.
  # Without this the tag strip below only blanks line 1, leaving a leading
  # newline → an empty bullet body with the step on an un-bulleted line.
  BLOCK=$(printf '%s' "$BLOCK" | tr '\n' ' ' | sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//')

  # Parse the leading disposition tag ([auto]/[manual]/[conditional]) at the
  # head of the block. The author tags the block; the prose doesn't reliably
  # encode the disposition (empirically: no-op and actionable openers are
  # textually indistinguishable). The generator reads the tag to decide what
  # reaches the migration log: [auto] is dropped (auto-propagates, audit trail
  # stays in the commit), [manual] kept plain, [conditional] kept + labelled.
  # An untagged non-empty block is KEPT + warned (D2 — silently dropping a real
  # step is the dangerous failure mode; bias to keep). Handles both the
  # `[tag] — text` (em-dash) and `[tag] text` (bare-space) separators.
  TAG=$(printf '%s' "$BLOCK" | sed -n '1s/^\[\(auto\|manual\|conditional\)\].*/\1/p')
  # Strip the leading tag token + any following `— `/`-`/whitespace separator.
  BLOCK_NOTAG=$(printf '%s' "$BLOCK" | sed -e 's/^\[\(auto\|manual\|conditional\)\][[:space:]]*//' -e 's/^—[[:space:]]*//' -e 's/^-[[:space:]]*//' -e 's/^[[:space:]]*//')

  if [ -n "$BLOCK" ]; then
    case "$TAG" in
      auto)
        # Drops out of PROPAGATION.md — auto-propagates; audit trail stays in
        # the commit message. Do not append to ENTRIES.
        :
        ;;
      manual)
        ENTRIES="${ENTRIES}- **${SUBJECT}** — ${BLOCK_NOTAG}
"
        ;;
      conditional)
        ENTRIES="${ENTRIES}- **${SUBJECT}** — (conditional) ${BLOCK_NOTAG}
"
        ;;
      *)
        # Untagged non-empty block — keep verbatim (D2) and warn so the author
        # learns to tag it (the squash-time hygiene gate enforces it going
        # forward; without a tag the generator re-admits no-op noise).
        ENTRIES="${ENTRIES}- **${SUBJECT}** — ${BLOCK}
"
        echo "WARN: ${sha:0:9} '${SUBJECT}' has an untagged **Existing projects:** block — kept; tag it [auto]/[manual]/[conditional] so the generator can filter no-op steps." >&2
        ;;
    esac
  else
    # No block. If this commit touched a propagation-relevant surface, the
    # omission silently drops it from PROPAGATION (this generator's only input
    # is the **Existing projects:** block). Warn loudly to stderr — non-fatal —
    # so the release-time PROPAGATION review (/ak-release-devshop Phase 2.5)
    # catches the gap instead of an existing-project step vanishing unnoticed.
    SURFACE=$(git show --name-only --format= "$sha" 2>/dev/null \
      | grep -E '^(template/|kit/scripts/|kit/hooks/|\.devcontainer/)|(^|/)manifest\.txt$' \
      | head -5 || true)
    if [ -n "$SURFACE" ]; then
      {
        echo "WARN: ${sha:0:9} '${SUBJECT}' touches a propagation-relevant surface but has no **Existing projects:** block — silently dropped from PROPAGATION:"
        echo "$SURFACE" | sed 's/^/    /'
      } >&2
    fi
  fi
done < <(git log --format='%H' --reverse "${LAST_TAG}..HEAD" 2>/dev/null)

# ENTRIES now holds ACTIONABLE entries only — [auto] blocks were filtered out
# above and never appended. So a version whose blocks are all [auto] (or which
# has no blocks at all) leaves ENTRIES empty and collapses to the existing
# `(no manual steps)` branch (D3 — the core payoff). Do NOT reintroduce [auto]
# blocks into ENTRIES above, or this collapse stops working.
if [ -n "$ENTRIES" ]; then
  SECTION="## v${VERSION}\n\n${ENTRIES}"
else
  SECTION="## v${VERSION}\n\n(no manual steps)"
fi

# Insert before the first existing ## v line (newest at top).
# Same pattern as changelog-entry.sh.
awk -v entry="$SECTION" '
  /^## v[0-9]/ && !inserted {
    printf "%s\n\n", entry
    inserted = 1
  }
  { print }
  END { if (!inserted) printf "\n%s\n", entry }
' "$PROPAGATION" > "${PROPAGATION}.tmp"

mv "${PROPAGATION}.tmp" "$PROPAGATION"
echo "Propagation entry added: v${VERSION}"
