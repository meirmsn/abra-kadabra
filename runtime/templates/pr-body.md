{{One line: what changes for the user or the system, in plain words, no jargon}}

**Preview:** {{a link to the deploy platform's own comment on this PR, which updates itself on every push; or "none — native: simulator screenshots under Evidence"; or "none — <why there is nothing to preview>"}}

<!--
PR body template (TARGET § L3 Review). Top-down, so the owner can stop reading at any level and
judge from a phone. Replace every {{…}}; delete these comments and any section marked optional
that doesn't apply. Check the result with runtime/scripts/pr-body-check.py before the PR goes
ready. Claim only what you have just read from the real signal (L-28).
-->

## Announcement

<!-- Optional: only when the change is user-facing. A short blurb for non-technical readers, as it
would appear in release notes. Delete the whole section otherwise. -->

{{Two or three sentences a user would understand}}

## What you should know

- **Behaviour change:** {{what now works differently, in plain words}}
- **Decisions:** {{the decisions that shaped it, each with its reason; link the spec, e.g. specs/<change>.md, or "bug fix: the failing test is the spec"}}
- **Changed after the go:** {{each spec change after the owner's "go", with the owner's recorded answer; or "nothing"}}
- **Tests deleted or loosened:** {{each one with the spec reason that justifies it; or "none"}}
- **Manual steps for you:** {{what the merge doesn't carry (dashboard settings, auth config, DNS…), as a checklist from the real deploy config; or "none"}}

## Evidence

<!-- Visuals: upload them, or link them by commit SHA, never by branch (L-30). For UI changes,
one per core-flow step and per state in the spec's state table. -->

- **Screenshots:** {{core-flow steps and state-table states; or "no UI change"}}
- **Reviewer:** {{the verdict per lens (spec, code, tests, docs, security, design/QA when UI), for commit <sha>}}
- **CI:** {{the required checks' result for commit <sha>, read when this was written}}
- **Low findings:** {{each low finding the reviewer listed; or "none"}}

<details>
<summary>Engineering details</summary>

{{How it works, files and modules touched, migrations and how they are reversible (Ship 3), anything
a future reader of this PR needs}}

</details>
