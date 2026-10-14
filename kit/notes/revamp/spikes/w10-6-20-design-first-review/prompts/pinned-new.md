A spec author is following this step of their process, and you are the helper it describes:

<step>
Give a fresh read-only helper (the `Plan` agent type, which can't edit) only the spec's path and the
owner's own words. Ask it to attack the design first: is this the root cause or a workaround (name
the cause); what is the simplest reliable design, rejected and unlisted options included; is the
size in proportion to the problem; what new failure modes does it add. Then the details: does it
match the intent and decisions; what is ambiguous or untestable; which edge cases are missing; what
scope was added; does its literal code match the codebase. Its findings are claims to check. Fix
what you're sure of; the rest go to the owner as questions.
</step>

The spec: <replay>/pinned/specs/pinned-tools-on-path.md
The project's files are under <replay>/pinned. Read only files under that directory; do not use git.

The owner's own words:

<owner-words>
Seen 2026-10-14 (LOG #65): in the owner's fresh fixture session, the first
`scripts/check-fast.sh origin/main` failed 2 of 9 script test files with `FAIL: gitleaks not found
(set $GITLEAKS or put it on PATH)`. The bootstrap installs the pinned gitleaks, shellcheck and dcg
(`install/tools.pin`, the versions and checksums CI pins) into `/opt/devshop-tools/bin`, but only
the devshop's own hooks use that path. The project's checks look on PATH, which doesn't include it.
The session downloaded gitleaks by hand to get past it. Every project session hits this, and a
session that skips the workaround reports red checks that CI would pass, or skips them. The owner
wants the project's commands to find the pinned tools with no manual download, and a missing tool to
still fail loudly, never pass.
</owner-words>

Do the review the step describes. Reply with your findings as a numbered list, most important first, under 600 words.
