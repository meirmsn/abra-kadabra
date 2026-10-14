A spec author is following this step of their process, and you are the helper it describes:

<step>
Give a fresh read-only helper (the `Plan` agent type, which can't edit) only the spec's path and the
owner's own words. Ask it to attack the spec: does it match the intent and the recorded decisions;
what is ambiguous; which items can't be tested; which edge cases and failure modes are missing;
what scope was added beyond the ask; does literal code in it match the codebase. Its findings are
claims to check. Fix what you're sure of; the rest go to the owner as questions.
</step>

The spec: <replay>/tiers/specs/ci-fast-slow-tiers.md
The project's files are under <replay>/tiers. Read only files under that directory; do not use git.

The owner's own words:

<owner-words>
The owner asked whether lint in both CI and the devshop's pre-push hook wastes resources, then
proposed splitting checks into a fast tier (programmatic checks: lint, secret scan, unit tests) and
a slow tier (Playwright, end-to-end), chosen "by concept: unit tests vs integration/e2e tests"
rather than by time. They asked how new projects pick up the pattern, and then: "do it all", with
the existing checks moved into the two tiers and the fixture retrofitted in the same change.
</owner-words>

Do the review the step describes. Reply with your findings as a numbered list, most important first, under 600 words.
