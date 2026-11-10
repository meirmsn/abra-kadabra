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

## Decisions

Each decision below is Claude's proposal of 2026-11-10, revised after the adversarial spec review
and with the owner's pick on the check the same day; the owner's go approves them as written.

- **What "shared" means:** code, config or a test that more than one item, page or feature uses,
  or that every branch's CI runs (a project's `shared/` directory, a layout, a helper, a test over
  all items). Rejected: a fixed path list, since each project names its shared code differently
- **What a flake is:** a test that fails on a commit that doesn't touch it or what it tests, and
  passes when the same commit runs again. A test that fails on every run, `main` included, is
  **broken on `main`**: it gets the same fix PR at once, with no re-run
- **A shared change goes first, in its own PR.** When a feature turns out to need a change to
  shared code, the session raises it with the owner as a spec change (`ak:intent` step 5). On a
  yes it is its own change, with its own spec and go (or, with no real choice in it, a bug fix
  whose failing test is the spec), built by the same session on its own branch cut from a freshly
  fetched `main` (the feature branch's work committed first). Its PR tells the owner it should
  merge before the PRs that wait on it. A flake fix is a bug fix: its check shows the flake fail
  (e.g. the test run under the timing it depends on), and no go is needed. Rejected: the shared
  change carried in the feature PR and named in its body, the case F-NEW-164 is about
- **The waiting feature PR isn't shipped until the shared PR has merged;** then its branch merges
  `main` once and ships. A shared change already pushed on a feature branch moves out with a revert
  commit there, never a rebase or force-push. When the owner declines the separate PR, the shared
  change stays in the feature PR and the PR's body says so
- **Twice:** a session re-runs a flaky test's failed job at most once. Before that re-run it
  runs `flake-sightings.sh` (below) with the test's name and file, read from its own failure log.
  A sighting there (the test failing on another open PR that doesn't touch it, or a row for the
  test in `FINDINGS.md` on `main`) or a second failure of its own is the second sighting: then it
  doesn't re-run, and proposes the fix PR to the owner with the test's name and the failures
  seen, and on a yes opens it. The count is per session; a new session starts at zero, but the
  script sees the other PRs' failures. Each sighting is logged in `FINDINGS.md` (a new row, or a
  sighting on the matching row) in the records-only commit `ak:pr` § 3 describes. When the
  script can't read GitHub (exit 2), the session doesn't re-run and asks the owner
- **The fix addresses the root cause** (the timing, order or state the test depends on). It never
  skips or quarantines the test, and never adds retries to the test or its runner. Re-running a CI
  job once is not a retry in that sense
- **The rules live in `runtime/guidelines/parallel.md`, in a new section,** next to the rules on
  shared lists, since both are about parallel branches stepping on what they share. Its title and
  opening widen to cover both. The skills carry one line each where the session acts, pointing
  there: `ak:build` § 3 when the change turns out to need a shared change, and `ak:pr` § 4 when CI
  fails on a test the change doesn't touch. Rejected: the full rule in each skill (it drifts); a
  load in `ak:build` § 2 (the need shows up only while building)
- **The project CLAUDE.md template gets one line** under "How changes land", because every
  session loads it, including one that adds no item. It names
  `/opt/devshop-current/guidelines/parallel.md`. The template is a `seed`, so an existing project
  gets the line as a template diff at its next upgrade
- **The devshop's own `CLAUDE.md` gets one line** under "How changes land" with the same rule,
  linking `runtime/guidelines/parallel.md`: the devshop has shared scripts and tests of its own,
  and its sessions also run in parallel. That line also names the shared PR's merge as a reason to
  merge `main` into a waiting branch. Rejected: leaving it out, since the reason (the devshop runs
  tasks one at a time) holds only for R-21 to R-23
- **No finding row pins the no-check choice,** since a choice is not something noticed
  (`runtime/templates/findings.md`) and an acceptance item that names a findings row makes later
  rows read as beyond the ask (`F-2026-11-10-spec-pins-finding-rows`). The choice is recorded here
- **This PR marks `ROADMAP.md`'s R-23 row `Done, PR #<n>`**, as the spec template's rule says,
  asked by the devshop session that runs R-21 to R-23 one at a time (the first brief said not to
  edit `ROADMAP.md` because the three ran in parallel then)
- **The rule is prose, plus one tested script for the flake lookup (option A with a light C).**
  The owner asked for an adversarial review of the four options and a pick (owner, 2026-11-10:
  "Do an adversarial review to check the pros and cons of each of the options and pick"). The
  review found that the "Twice" step, a lookup across other PRs' CI, is a mechanical step, which
  CLAUDE.md says lives in a tested script, and that only it reaches the two flake incidents.
  `runtime/scripts/flake-sightings.sh --test <name> --path <test file>`, shipped to sessions as
  `/opt/devshop-current/scripts/flake-sightings.sh` and run by `ak:pr` § 4 before any re-run:
  - it reads, with `gh`, the open PRs other than the current branch's (at most 30), skips each
    whose changed files include the test file, and searches the failed-job log of each one's
    latest failed CI run on its head commit for the test's name, as a fixed string;
  - it also searches `FINDINGS.md` on `origin/main` for the name (a missing file is no sighting);
  - exit 0: no sighting (it says how many PRs it checked); 1: each sighting listed (PR number and
    run, or the FINDINGS.md row); 2, never 0: a missing tool (`gh`, `jq`, `git`), a missing or
    empty argument, a `gh` call that fails, or a log it can't read.

  It is in-session feedback, not a wall: nothing stops a re-run by hand. It sees only open PRs'
  latest runs. Rejected, from the same review:
  - **B, a blocking fast-tier path check** (a project's `SHARED` paths beside `COLLECTIONS` in
    `check-fast.sh`): it catches at most the shared-prompt incident, neither flake, and fails
    legitimate shared PRs that adapt their callers and the item that first creates the shared
    code. It is the next step if a shared change rides in a feature PR again;
  - **the full C**, parsing test names out of every stack's logs: per-stack work; the session
    already has the name from its own log;
  - **D, a reviewer rule:** it sees a diff, not CI runs, so it misses both flakes, and it needs the
    paid reviewer eval and a new planted case;
  - **B as a warning in `ship.sh`:** a check that only warns gets ignored (R-22's spec)

## Acceptance items

- **AC-1** `runtime/guidelines/parallel.md`'s title and opening cover shared changes and flakes,
  and a new section says:
  - what counts as shared code, a flake, and a test broken on `main`;
  - a shared change is raised with the owner as a spec change and, on a yes, goes in its own PR
    from a freshly fetched `main`, built by the same session, merged before the PRs that wait on
    it, with the owner told so;
  - a flake fix is a bug fix whose check shows the flake fail;
  - the waiting feature PR isn't shipped until the shared PR has merged, then merges `main` once;
    a shared change already pushed moves out with a revert commit; a declined split stays in the
    feature PR, which says so;
  - a flake is re-run at most once per session, after `flake-sightings.sh` finds no sighting; a
    sighting (another open PR failing on it, a row in `FINDINGS.md` on `main`), or a second failure of
    its own gets a proposed fix PR instead of a re-run; a test broken on `main` gets it at once;
  - each sighting is logged in `FINDINGS.md` in the records-only commit;
  - the fix addresses the root cause, never skipping, quarantining or adding retries to the test,
    and a single CI re-run is not such a retry

  — verified by review: the file

- **AC-2** `runtime/guidelines/README.md`'s line for `parallel.md` names shared changes and flakes
  — verified by review: the diff
- **AC-3** `runtime/skills/build/SKILL.md` § 3 says a change that turns out to need a change to
  shared code or a fix to a shared test stops there and goes first in its own PR, pointing to
  `parallel.md` — verified by review: the diff
- **AC-4** `runtime/skills/pr/SKILL.md` § 4 says a CI failure in a test the change doesn't touch
  follows `parallel.md`'s flake rule: run `flake-sightings.sh` before any re-run; exit 0 allows one
  re-run, exit 1 gets a proposed fix PR instead, exit 2 asks the owner; and
  `tests/skills-check.test.sh`'s checks still pass on both skills — verified by review: the diff
  and the skills check's output in the PR's evidence
- **AC-5** `runtime/templates/project-claude.md` has one line under "How changes land": a shared
  change or a fix to a shared or flaky test goes first in its own small PR, and a flake seen twice
  gets that PR, not a re-run, naming `/opt/devshop-current/guidelines/parallel.md` — verified by
  review: the diff
- **AC-6** The devshop's `CLAUDE.md` has one line under "How changes land" with the same rule,
  linking `runtime/guidelines/parallel.md`, and naming the shared PR's merge as a reason a waiting
  branch merges `main` — verified by review: the diff
- **AC-7** `flake-sightings.sh` exits 1 and lists the PR and run of each other open PR whose latest
  failed run's failed-job log contains the test's name and whose changed files don't include the
  test file, and the `FINDINGS.md` row on `origin/main` that contains the name;
  `tests/flake-sightings.test.sh` feeds it each case with a stub `gh`
- **AC-8** `flake-sightings.sh` exits 0 when there is no other open PR, when the name is only in the
  log of a PR that changes the test file, only in the current branch's own PR, in no log, when the
  other PRs have no failed run, and when `origin/main` has no `FINDINGS.md`
- **AC-9** `flake-sightings.sh` exits 2, never 0, on a missing `gh`, `jq` or `git`, a missing or
  empty `--test` or `--path`, an unknown argument, a `gh` call that fails, and a log it can't read;
  its mutants are killed, as listed in the PR's evidence
- **AC-10** `ROADMAP.md`'s R-23 row reads `Done, PR #<n>` — verified by review: the diff

## Out of scope

- A blocking check or a reviewer rule (options B and D above), and parsing test names from CI logs
- Flake detection inside CI, retry wrappers or quarantine lists
- Changes in any project's own files; they arrive at the project's next upgrade
