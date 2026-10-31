# {{Change title, in the owner's terms}}

**Go:** pending

<!--
Spec template (TARGET § L3 Intent 2). One file per change in the project's specs/, named
specs/<change>.md and kept after merge as context for future work. Replace every {{…}} and delete
these comments and any optional section that doesn't apply. Check it with
/opt/devshop-current/scripts/spec-check.py <file>; once the owner says "go", record it on the Go
line (their words, then the date as YYYY-MM-DD) and check again with --go.
-->

## Intent

<!-- A change that picks up a roadmap entry names its R-<n> here; the change that delivers it marks
the entry Done. A slice (devshop:split) also links the plan document when there is one. A change
that changes what a page renders names its surface, customer-facing or internal, and the DESIGN.md
tokens and components it uses; anything DESIGN.md must gain is a decision. -->

{{What the owner asked for and why, in their words}}

## Decisions

<!-- Each with its reason, the rejected alternative where it matters, and who decided when. A
decision changed after the go is recorded here as the owner's, with its date (Intent 7). -->

- {{Decision}}: {{reason}}; rejected: {{alternative}} ({{owner, YYYY-MM-DD}})

## Acceptance items

<!-- Numbered AC-1, AC-2, … in order: what must be true, each pass/fail. How it is tested can't
narrow it (Intent 4). An item shown by a demonstrated step instead of a test ends
"— verified by review: <the step>". Every item is checkable from the repo (its code, tests, files
and commits): what only the owner can confirm (their chat, a dashboard) or what is true only after
the merge (a live domain) goes in Decisions, as their recorded confirmation or a post-merge step. -->

- **AC-1** {{What must be true}}

## Core flow

<!-- Optional: UI changes only. The core flow in 2 to 4 steps (L-20). -->

1. {{Step}}

## States

<!-- Optional: anything that shows or hides by state (L-73). One row per state. -->

| State     | {{What shows or hides}} |
| --------- | ----------------------- |
| {{state}} | {{shown or hidden}}     |

## Out of scope

- {{What this change deliberately doesn't do}}
