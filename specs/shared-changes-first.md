# Shared changes and flaky-test fixes land first, in their own small PR

**Go:** pending

## Intent

Picks up roadmap entry R-23 (source: F-NEW-164). A project ran 11 parallel sessions, one feature
branch each, merged one at a time. Shared changes and fixes to shared or flaky tests rode inside
unrelated feature PRs:

- a shell prompt that every item uses shipped inside one item's PR, so every other branch had to
  adapt its tests;
- a fix for a flaky test (a size measured mid-animation) sat in a branch near the end of the merge
  queue while that flake failed CI on at least three other PRs;
- two more flakes stayed unfixed.

The owner wants a devshop rule that a change to shared code (e.g. a project's `shared/`) or a fix
to a shared or flaky test goes in its own small PR, merged first; and that a session which sees an
unrelated flake twice proposes that PR instead of re-running. Where the rule lives and whether a
check can back it are for this spec to decide.

Then (2026-11-11), pointing at the same project's later sessions that fixed its flakes: "we
actually have been following an approach of not doing retries and actually understand where the
issue is coming from and testing against that. Maybe even rewriting the code so that we can test
it, as opposed to doing retries or trying to put some statistics around the flakiness."

## Decisions

Each decision below is Claude's proposal of 2026-11-10, revised after the adversarial spec review
and again on 2026-11-11 after reading the project sessions the owner pointed at; the owner's go
approves them as written.

- **What "shared" means:** code, config or a test that more than one item, page or feature uses,
  or that every branch's CI runs (a project's `shared/` directory, a layout, a helper, a test over
  all items). Rejected: a fixed path list, since each project names its shared code differently
- **A shared change goes first, in its own PR.** When a feature turns out to need a change to
  shared code, the session raises it with the owner as a spec change (`ak:intent` step 5). On a
  yes it is its own change, with its own spec and go (or, with no real choice in it, a bug fix
  whose failing test is the spec), built by the same session on its own branch cut from a freshly
  fetched `main` (the feature branch's work committed first). Its PR tells the owner it should
  merge before the PRs that wait on it. Rejected: the shared change carried in the feature PR and
  named in its body, the case F-NEW-164 is about
- **The waiting feature PR isn't shipped until the shared PR has merged;** then its branch merges
  `main` once and ships. A shared change already pushed on a feature branch moves out with a revert
  commit there, never a rebase or force-push. When the owner declines the separate PR, the shared
  change stays in the feature PR and the PR's body says so
- **An unrelated failure is never re-run to get green, not even once.** An unrelated failure is a
  test that fails on a change that touches neither it nor what it tests, on the change's PR or on
  `main`. The session doesn't re-run the job: it reproduces the failure on `main`'s code, finds its
  cause and proposes a fix PR to the owner with the cause shown; on a yes it opens it, as for any
  shared change, and the PR asks to merge first. One sighting is enough once the cause is shown.
  Until the fix merges, the failure is a row in `FINDINGS.md` (or a sighting on its row), logged in
  the records-only commit `ak:pr` § 3 describes. A cause it can't reproduce after the steps below
  goes to the owner with what was tried; still no re-run. Changed from the owner's first ask ("an
  unrelated flake twice"), on the owner's words of 2026-11-11 above: a re-run tells nothing about
  the cause, and the project's sessions that fixed seven flakes made none. Rejected: one re-run per
  session, and a script that searched other PRs' CI logs before it (drafted on 2026-11-10; with no
  re-run left to gate, it has no use)
- **How a flake fix is made** (the method those sessions followed, which fixed seven flakes):
  1. tell load from logic: run the test alone, then under load (several suites at once, busy CPU
     loops, a throttled CPU);
  2. measure the raw values the test asserts on, not only pass or fail;
  3. make the failure deterministic: a seeded random source, the state set at a boundary, the
     arithmetic simulated, frames slowed;
  4. the fix's first check is the old test failing under that cause, then the new test passing
     under it;
  5. a mutation check: the fixed test still fails when the behaviour it protects is broken;
  6. probes that proved the cause become committed tests, not local runs only.

  The fix removes the cause from the test (wait on a state, not a fixed time; take the clock or
  the randomness under the test's control; sample an area, not one pixel or instant), or changes
  the code so it can be tested reliably (a clock, a seed or a manual-step switch the test can set):
  a code change is part of the fix's spec, which the owner approves. It never adds retries or
  repeated samples, a looser limit for CI only, a skip or a quarantine, and never offers "passed N
  times" as proof

- **Where to look first:** the causes those sessions found, as a list in the guideline: a fixed
  wait; time in the code advancing before the test takes control of the clock; state read before
  the frame that updates it has run; a single pixel or instant sampled; a wall-clock duration
  asserted; a floating-point step boundary; a timer in the code that the test's clock doesn't
  control; a port or other resource shared by tests running at once. Rejected: a sweep of each
  project's tests for these, which is each project's own change
- **The rules live in two guidelines.** The shared-change rule goes in a new section of
  `runtime/guidelines/parallel.md`, next to the rules on shared lists, since both are about
  parallel branches stepping on what they share; its title and opening widen to cover it. The
  flake rule, method and causes go in a new `runtime/guidelines/flaky-tests.md`, since an unrelated
  failure hits every PR, parallel or not. The skills carry one line each where the session acts:
  `ak:build` § 3 when the change turns out to need a shared change, and `ak:pr` § 4 when CI fails
  on a test the change doesn't touch. Rejected: the full rules in each skill (they drift); a load
  in `ak:build` § 2 (the need shows up only while building)
- **The project CLAUDE.md template gets one line** under "How changes land", because every
  session loads it, including one that adds no item. It names
  `/opt/devshop-current/guidelines/parallel.md` and `/opt/devshop-current/guidelines/flaky-tests.md`.
  The template is a `seed`, so an existing project gets the line as a template diff at its next
  upgrade
- **The devshop's own `CLAUDE.md` gets one line** under "How changes land" with the same rule,
  linking the two guidelines: the devshop has shared scripts and tests of its own, and its sessions
  also run in parallel. That line also names the shared PR's merge as a reason to merge `main`
  into a waiting branch
- **No mechanical check backs the rule; it is prose.** The owner asked for an adversarial review of
  the options and a pick (owner, 2026-11-10: "Do an adversarial review to check the pros and cons
  of each of the options and pick"). That pick, a script to search other PRs' CI before a re-run,
  went with the re-run (above). Rejected, from the same review:
  - **a blocking fast-tier path check** (a project's `SHARED` paths beside `COLLECTIONS` in
    `check-fast.sh`): it catches at most the shared-prompt incident, neither flake, and fails
    legitimate shared PRs that adapt their callers and the item that first creates the shared
    code. It is the next step if a shared change rides in a feature PR again;
  - **a reviewer rule:** it sees a diff, not CI runs, so it misses both flakes, and it needs the
    paid reviewer eval and a new planted case;
  - **a warning in `ship.sh`:** a check that only warns gets ignored (R-22's spec)
- **No finding row pins the no-check choice,** since a choice is not something noticed
  (`runtime/templates/findings.md`) and an acceptance item that names a findings row makes later
  rows read as beyond the ask (`F-2026-11-10-spec-pins-finding-rows`). The choice is recorded here
- **This PR marks `ROADMAP.md`'s R-23 row `Done, PR #<n>`**, as the spec template's rule says,
  asked by the devshop session that runs R-21 to R-23 one at a time (the first brief said not to
  edit `ROADMAP.md` because the three ran in parallel then)

## Acceptance items

- **AC-1** `runtime/guidelines/parallel.md`'s title and opening cover shared changes, and a new
  section says what counts as shared code; that a shared change is raised with the owner as a spec
  change and, on a yes, goes in its own PR from a freshly fetched `main`, built by the same
  session, merged before the PRs that wait on it, with the owner told so; that the waiting feature
  PR isn't shipped until the shared PR has merged, then merges `main` once; that a shared change
  already pushed moves out with a revert commit; and that a declined split stays in the feature
  PR, which says so — verified by review: the section
- **AC-2** `runtime/guidelines/flaky-tests.md` exists and says:
  - what an unrelated failure is, and that it is never re-run to get green;
  - the session reproduces it on `main`'s code, finds the cause, and proposes a fix PR that merges
    first, after one sighting; until then it is a `FINDINGS.md` row; a cause it can't reproduce
    goes to the owner, without a re-run;
  - the six steps of the method, the two kinds of fix (the cause out of the test, or the code made
    testable as part of the fix's spec), and what a fix never does (retries or repeated samples, a
    looser CI-only limit, a skip, a quarantine, "passed N times" as proof);
  - the list of causes to look at first

  — verified by review: the file

- **AC-3** `runtime/guidelines/README.md` lists `flaky-tests.md`, and its line for `parallel.md`
  names shared changes — verified by review: the diff
- **AC-4** `runtime/skills/build/SKILL.md` § 3 says a change that turns out to need a change to
  shared code or a fix to a shared test stops there and goes first in its own PR, pointing to
  `parallel.md` — verified by review: the diff
- **AC-5** `runtime/skills/pr/SKILL.md` § 4 says a CI failure in a test the change doesn't touch
  is not re-run and follows `flaky-tests.md`; and `tests/skills-check.test.sh`'s checks still pass
  on both skills — verified by review: the diff and the skills check's output in the PR's evidence
- **AC-6** `runtime/templates/project-claude.md` has one line under "How changes land": a shared
  change or a fix to a shared or flaky test goes first in its own small PR, and an unrelated
  failure is never re-run but reproduced and fixed at its cause, naming the two guidelines'
  `/opt/devshop-current/guidelines/` paths — verified by review: the diff
- **AC-7** The devshop's `CLAUDE.md` has one line under "How changes land" with the same rule,
  linking the two guidelines, and naming the shared PR's merge as a reason a waiting branch merges
  `main` — verified by review: the diff
- **AC-8** `ROADMAP.md`'s R-23 row reads `Done, PR #<n>` — verified by review: the diff

## Out of scope

- A mechanical check (a path check, a reviewer rule, a CI-log search); see the decisions
- Sweeping a project's tests for the listed causes; that is the project's own change
- Flake detection inside CI, retry wrappers or quarantine lists
- Changes in any project's own files; they arrive at the project's next upgrade
