{{One line: what changes for the user or the system, in plain words, no jargon}}

{{Two or three sentences, one paragraph: what changed and why it matters, in the same plain words}}

**Preview:** {{a link to the deploy platform's own comment on this PR, which updates itself on every push; or "none — native: simulator screenshots under Evidence"; or "none — <why there is nothing to preview>"}}

<!--
PR body template (TARGET § L3 Review). Top-down, so the owner can stop reading at any level and
judge from a phone. The paragraph under the summary is the second level, in this register: "Every
item now shows its category (Work or Home to start), and the links above the list show just one
category or all of them. A mistyped filter link says it seems corrupted and offers a way
back."
Replace every {{…}}; delete these comments and any section marked optional that doesn't apply. Check the result with runtime/scripts/pr-body-check.py before
the PR goes ready. Claim only what you have just read from the real signal (L-28).
-->

## Announcement

<!-- Optional: only when the change is user-facing; delete the whole section otherwise. A release
note for the person who uses the app: what they can now do, or what now works for them, in their
words. No routes, status codes, file names, code or AC ids; name what they see and tap ("the
filter links above the list"), not how it is built. -->

{{Two or three sentences a user of the app would understand}}

## What you should know

- **Behaviour change:** {{what now works differently, in plain words}}
- **Decisions:** {{the decisions that shaped it, each with its reason; link the spec, e.g. specs/<change>.md, or "bug fix: the failing test is the spec"}}
- **Changed after the go:** {{each spec change after the owner's "go", with the owner's recorded answer; or "nothing"}}
- **Tests deleted or loosened:** {{each one with the spec reason that justifies it; or "none"}}
- **Manual steps for you:** {{what the merge doesn't carry (dashboard settings, auth config, DNS…), as a checklist from the real deploy config; or "none"}}

## Evidence

<!-- Screenshots go on the PR, never only in chat. For UI changes, one per core-flow step and per
state in the spec's state table, taken at the final commit. Upload them with
/opt/devshop-current/scripts/pr-assets.sh and paste the lines it prints: they are pinned to a
commit, so they survive the merge and the branch's deletion (L-30). -->

- **Screenshots:** {{one sub-item per core-flow step and state-table state, each "<step or state>: <image line from pr-assets.sh>"; or "no UI change"}}
- **Reviewer:** {{the verdict per lens (spec, code, tests, docs, security, design/QA when UI), for commit <sha>}}
- **CI:** {{the required checks' result for commit <sha>, read when this was written}}
- **Low findings:** {{each low finding the reviewer listed; or "none"}}

<details>
<summary>Engineering details</summary>

{{How it works, files and modules touched, migrations and how they are reversible (Ship 3), anything
a future reader of this PR needs}}

</details>
