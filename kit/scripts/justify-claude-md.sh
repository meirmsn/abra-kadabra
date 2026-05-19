#!/usr/bin/env bash
# What: Helper for the CLAUDE.md justification mechanism. Prints (a) an inline
#       <!-- justified: --> marker to paste next to a CLAUDE.md entry AND (b)
#       a CLAUDE-MD-Bypass: commit trailer text to paste into the commit message.
# Why:  When adding an entry to CLAUDE.md that's plausibly questionable (a new
#       section; an entry whose home is unclear; anything /ak-docs-review §
#       Section E might CHALLENGE), the operator records the reasoning durably:
#       commit trailer (visible in git log) + inline marker (visible to every
#       future reader AND re-examined by every audit). See
#       kit/docs/guide/claude-md.md § The bypass mechanism is now informational.
# Does NOT: Block any commit. There is no gate to bypass post-2026-05-18 — this
#           helper exists for transparency + audit-trail, not enforcement. The
#           adversarial reviewer is the canonical hygiene gate.
#
# Usage:
#   kit/scripts/justify-claude-md.sh "<reason>"
#
# Output:
#   - Inline marker block (paste above the CLAUDE.md entry you're justifying)
#   - Commit trailer line (paste into commit message, ideally last)
#
# Example:
#   $ kit/scripts/justify-claude-md.sh "load-bearing on QA loop UX; rolling back
#       the round-insert on side-channel write failure would surface a 'Q&A failed'
#       error when Q&A actually succeeded — silent-failure-causing if forgotten"
#
# The reason is captured verbatim. Be specific — the next audit will re-judge
# the entry against this reason, and the operator (you or future-you) will need
# to defend the entry if the reviewer CHALLENGES it.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 \"<reason>\"" >&2
  echo "" >&2
  echo "Provides the inline marker + commit-trailer text for adding a CLAUDE.md" >&2
  echo "entry that future /ak-docs-review audits should re-examine." >&2
  echo "" >&2
  echo "See kit/docs/guide/claude-md.md § The bypass mechanism is now informational." >&2
  exit 1
fi

REASON="$1"
TODAY=$(date -u +%Y-%m-%d)

# Reject empty / placeholder reasons. Future audits judge the entry against
# this reason; "TODO" or "n/a" are not useful records.
TRIMMED=$(echo "$REASON" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
case "$TRIMMED" in
  "" | "TODO" | "todo" | "n/a" | "N/A" | "fixme" | "FIXME")
    echo "✖ Reason is empty or a placeholder ($TRIMMED). Provide specific reasoning." >&2
    echo "" >&2
    echo "Examples of acceptable specificity:" >&2
    echo "  - load-bearing on Q&A UX; rolling back round-insert on side-channel" >&2
    echo "    write failure would surface 'Q&A failed' when Q&A succeeded" >&2
    echo "  - locks the v0 data shape so row #5 (monitor-beta) reading users.location" >&2
    echo "    doesn't trip over JSON-vs-string split" >&2
    echo "  - shared validator across LLM-output + user-PATCH trust boundaries —" >&2
    echo "    inlining either path silently lets the other accept rejected shapes" >&2
    exit 1
    ;;
esac

# Single-line reason for the inline marker (HTML comments can span lines but
# matched parsers in /ak-docs-review prefer single-line). Newlines collapsed to
# spaces; multi-paragraph reasons stay on one line.
REASON_ONELINE=$(echo "$REASON" | tr '\n' ' ' | sed 's/[[:space:]]\{2,\}/ /g; s/^[[:space:]]*//;s/[[:space:]]*$//')

cat <<EOF
─────────────────────────────────────────────────────────────────
 Inline marker — paste IMMEDIATELY ABOVE the CLAUDE.md entry:
─────────────────────────────────────────────────────────────────

<!-- justified: $REASON_ONELINE; recorded $TODAY -->

─────────────────────────────────────────────────────────────────
 Commit trailer — paste into the commit message (ideally last):
─────────────────────────────────────────────────────────────────

CLAUDE-MD-Bypass: $REASON_ONELINE

─────────────────────────────────────────────────────────────────
EOF

cat <<'EOF'

Next steps:
  1. Paste the inline marker ABOVE the CLAUDE.md entry you just added.
  2. Stage CLAUDE.md and any other files for your commit.
  3. Commit with the trailer at the end of the message (HEREDOC works).
  4. The next /ak-docs-review § Section E run will re-examine the entry
     against the recorded reason. If the entry could plausibly relocate
     (a closer home exists now, the toolchain catches it loudly, etc.),
     the reviewer surfaces a CHALLENGE finding — you defend or relocate.

See kit/docs/guide/claude-md.md § Layer C — Adversarial audit.
EOF
