# ponytail

Analysed: https://github.com/DietrichGebert/ponytail at 96608e078b2d5ea607c5c3b8b5a54d1c1fba6846
(2026-10-29, no tag; v5.3.3 is its parent), on 2026-11-10.

## What it is

A Claude Code plugin (it also ships for about 20 other agents) built around one prompt, "the lazy
senior dev". It is active every session, in three levels (lite, full, ultra).

Before writing code, the agent reads the code the change touches and lists every place the change
must reach. Then it stops at the first rung of a ladder that works:

1. Does it need to exist?
2. Is it already in this codebase?
3. Does the standard library or the platform do it?
4. Does an installed dependency do it?
5. Can it be one clear line?
6. Only then, the minimum code that works.

It never cuts validation at trust boundaries, data-loss handling, security or accessibility.
Non-trivial logic leaves one small test. A deliberate shortcut gets a
`shortcut: <the limit>, <when to upgrade>` comment. Every reply ends with what was skipped or not
checked.

Around the prompt it ships:

- review and audit skills: a finding needs a concrete case, and each says what the code does, the
  problem, the fix and "if we skip it";
- a skill that collects the shortcut comments into a ledger;
- a hook that injects the rules into subagents;
- a cost and token band above the prompt.

**How far it is backed:** its own agentic benchmark has 39 tasks, 5 runs each, the arms interleaved
in one run, with medians per task and bootstrap intervals. It claims:

- 53% less code, 26% lower cost and 41% less time than no skill;
- hidden checks passed level (97% against 96%);
- a test for 98% of risky logic, against 68%.

These are the author's numbers, from a README that is largely marketing. Two independent runs, which
it links, confirm the smaller code. One of them found higher process cost on large tasks that must
run to completion.

## Could adopt

1. **The ladder and the "never cut" list, in the `build` skill's § 3.** This bears on F-NEW-65
   (kit/notes/revamp/FINDINGS.md): reviews don't question a design the author argued for, so
   oversized fixes get through, and the owner named the risk as code bases bloating. The devshop's
   tests of review-side questions caught it in 0 of 6 runs, and the finding is not tracked because no
   fix tested better than nothing. Ponytail works at build time instead, before the code exists.
   Copy the few rules rather than install the plugin: the plugin injects a persona every session and
   adds its own reply format and comment convention. The devshop can't measure the gain today, so
   try it first, with and without the rules, on a few tasks of the reviewer eval's fixture.
   Cost: one skill edit, plus that trial.
2. **A "Not checked:" line in the PR body.** In ponytail's blind comparison, a judge preferred the
   replies that end with what was skipped or not checked, 110 to 67. The devshop's "What you should
   know" has no such line. Cost: the template plus `pr-body-check.py` and its test.
3. **Two rules for the reviewer:** every finding needs a concrete case ("no case, no finding"), and
   the reviewer reads the callers of each changed function, not only the diff. The reviewer's `code`
   lens is one line today (`runtime/reviewer/prompt.md`). Ponytail claims its review found 100% of
   planted problems outside the diff, against 78% without it. This changes how the reviewer reviews,
   so it needs the reviewer eval's result (runtime/reviewer/README.md § Proof). Cost: the prompt,
   new plants and an eval run.
4. **An in-code marker for a deliberate limit,** naming the limit and when to revisit it. The
   reviewer would treat it as a decision rather than a finding. CLAUDE.md's "label a mitigation as
   one and name the root cause beside it" has no fixed form today, so neither a reviewer nor a script
   can find these. Low priority: no finding in the devshop yet asks for it.

## Already have

- **A baseline the tool under test can't reach:** ponytail's earlier safety run was void because
  its own startup hook fired in the no-skill arm. The devshop's reviewer runs
  `claude -p --restricted --safe-mode`, which loads no CLAUDE.md, hooks, plugins or MCP
  (runtime/reviewer/README.md).
- **Instruments proven on known-good and known-bad input before they are trusted:** this is
  ponytail's `--selftest` and its judges' self-tests. The devshop has its mutant rule (CLAUDE.md:
  every check is proven to fail) and the reviewer eval's 15 honest and 15 planted changes.
- **Copies of shared rules checked against the original** (ponytail's `check-rule-copies.js`): the
  project contract and the upgrade's re-copy check (specs/project-contract.md).
- **Cost and tokens per change:** the metrics comment (specs/metrics-model-and-tokens.md).
- **Questioning the request** (its `ultra` level): `ak:intent` and gstack's `/office-hours`.

## Don't adopt

- **The cost band and the local board:** they don't show in cloud sessions, where the devshop runs,
  and the metrics comment already records cost per PR.
- **The three levels and the twenty-agent adapters:** the devshop runs one agent, Claude Code, and
  wants one behaviour, not a dial.
- **"One good test, not coverage":** it would weaken the devshop's rule that every acceptance item is
  named by a test that would fail without it.
- **Injecting the rules into subagents:** the devshop's helpers only read (the `build` skill), so
  rules about how to write code don't apply to them. The startup hook's `DEVSHOP:` line is for the main session alone.
- **Installing the plugin as it is:** it would add a second voice beside the devshop's skills,
  including its own reply ending and comment marker, and write config under `~/.config`. The ideas
  worth having are a few lines, above.

## The owner's answers

None yet: items 1 to 4 were put to the owner as "roadmap or keep watching?" on 2026-11-10.
