# Abra-Kadabra

> **Status: Work in progress** · last touched 2026-10. What is this? A running prototype of how an
> AI dev shop could run, not a supported product. Used to build lalista, home-os and meirmsn.dev.
> Suggestions welcome; see Feedback below.

```text
you ──▶ "I want …"            a whole app, or a one-line fix
         │
         ▼
       intent   Claude sharpens it with you into a spec: your words, decisions, acceptance items
         │      (a read-only helper attacks the spec before you see it)
         ▼  "go"
       build    one agent writes code, tests and docs together
         │
         ▼
       ship     a second agent, with none of the builder's context, reviews the diff against the spec
         │        fail → back to build            pass → the PR opens, with the verdict on it
         ▼
you ──▶ read the PR (summary, release note, preview, evidence), comment to steer, or approve
         │
         ▼  approve
       merge → deploy from main → canary → a summary on the PR: how long it took, what it cost

walls the agent can't move: main takes PRs only · required CI · your approval · no production secrets
```

A dev shop run by Claude Code agents: you bring the strategy and the product you want; agents
plan, spec, build and review; your input steers and your approval ships the changes. Made for one
person running their own products.

Every request, from a whole app to a one-line fix, starts as a conversation in which Claude helps
you sharpen what you want into a one-screen spec you say "go" to. One agent builds the change with
its tests and docs; a second agent with none of the builder's context reviews it against the spec,
and only a pass opens the PR. The PR reads top-down: one line, a release note in your users'
words, what you should know, a preview you can try yourself, evidence (screenshots when the UI
changed, the reviewer's verdict, CI), and the engineering details. Your approval merges it; the
deploy and a canary of the live site report back on the PR, and lastly a summary is posted to it
with how long the change took and what it cost. What the agent noticed and didn't fix is logged,
and comes back to you only when it recurs. The other half of the experiment is the walls: what the
agent can never do (push to `main`, merge without you, hold a production secret), so that trusting
a change means reading its PR, not auditing the agent.

## Approach

Built by hand with the process it automates, codifying only the steps that proved their worth. v1
(April to June 2026) grew out of lalista's own tooling into a devcontainer with a firewall and a
19-gate pipeline, and built lalista and home-os. v2 (October 2026) is a rewrite in this repo from
a harvest of v1's lessons: one target picture agreed top-down, then small PRs under the rule that
the check comes before the change. The agent wrote v2's specs, code, tests, docs and notes (all but
two of its PRs) and ran its own reviewer on each; I made the decisions, gave each "go" and each
approval, and did the steps only an owner can (accounts, branch rules, cloud environments).
Human in the loop: [@meirmsn](https://github.com/meirmsn); robot hands:
[@meirmsn-agent](https://github.com/meirmsn-agent).

What the process taught: a check that was never shown to fail does not exist (v1's secret scan
had no rules loaded and passed everything, unnoticed until the revamp's analysis); and
nothing inside the agent's session is a boundary. The only walls are GitHub's rules on `main`,
plain CI and the owner's approval; everything else is feedback.

## What it does

- You describe a change in chat, from a one-line fix to a whole app; it comes back as a
  one-screen spec in your own words (intent, decisions, acceptance items, out of scope) that you
  say "go" to.
- A second agent that never saw the builder's chat reviews the change against that spec before
  you see the PR; its verdict sits on the PR, tied to the commit it reviewed.
- Each PR is written to be judged on a phone: a one-line summary, a release note in your users'
  words, what you should know, a preview to try, screenshots in light and dark, the engineering
  details.
- Your approval ships: the merge deploys from `main`; the deploy and the canary after it report
  on the PR, with the previous version and the way to undo it; a last comment sums up the time,
  your input, the cost and the rounds.
- A new project starts green in its first session: files placed, CI in two tiers, and a checklist
  of the steps only you can do.
- What the agent noticed but didn't fix is logged with a severity and its sightings; you hear of
  it when it is medium or higher, or has come back three times.

## How it works

### Adversarial review

**The builder never grades its own work: a second agent with none of its context reviews the
change against the spec, and the PR cannot open until it passes.**

`ship.sh` is the only road from a branch to a PR. It runs `review.sh`, which starts a fresh,
locked-down `claude -p` in a throwaway clone: it can read, run the tests and browse a local run of
the app, and can neither edit nor push. The reviewer finds the spec the change adds, checks every
acceptance item for evidence, then applies the lenses that fit (code, security, design, QA,
tests, docs). Only a pass pushes the branch and opens or updates the PR with exactly the words
that were reviewed, then posts the verdict as a comment tied to that commit. A hook refuses the
other roads (`gh pr create`, a push on a branch with an open PR). The same shape runs before the
"go": a read-only helper attacks the spec against the owner's intent before the owner sees it.

- Three outcomes: pass, fail, could-not-run; the last never passes. The verdict is JSON against a
  schema, and anything the reviewer can't parse or trust fails closed.
- Tests and docs get the same depth as code: would this test fail if the code were wrong; is a
  deleted or loosened test justified by the spec; would a future agent reading only the docs do
  the right thing.
- A finding at medium or above is fixed or goes to the owner; low findings are logged, not fixed
  on reflex. After three rounds on the same thing, the agent asks.
- The reviewer is measured: an eval of planted spec violations, run by hand before any change to
  how it reviews, whose result goes in that PR. Its recall was 0.33 until its Bash tool turned out
  to be missing, then 1.0.
- Tried and changed: a full review on every change to the PR's words cost five reviews on one PR,
  so a change to title or body alone now gets a words-only review.
- Not a wall: an agent that controls its own session could skip it. The walls are GitHub's rules
  on `main`, plain CI and the owner's approval; a push with no verdict after it is the tripwire.
  An air-gapped reviewer as a required check is on the roadmap.

### Product, design and engineering, separated

**Product, design and engineering each hand the next step a written artefact (the spec, the
design file and its review, the tests and docs), and the chat is never the record.**

`intent` names the kind of request (no change, bug fix, change) and, for a change, writes a spec
file in the project's `specs/`: intent in the owner's words, decisions with their reasons,
numbered acceptance items, out of scope; a UI change adds its core flow and a state table. The
owner's "go" is recorded on the spec, which stays after the merge as context for later sessions.
`build` is one writer: it loads only what applies (the project's rules, the stack's home, the
guideline of each discipline it touches), changes code, tests and docs together, and names each
acceptance item in the test that proves it. `pr` writes the PR's words from a template and hands
them to `ship`. Design has its own artefacts: a baseline of design tokens in light and dark, a
`DESIGN.md` per project, a design review on a local run before the PR, and the reviewer's browser
judging each touched page against that `DESIGN.md`.

- Decisions are written where they belong (the spec, the PR, the decision log) when the owner
  makes them; a decision changed after the "go" is recorded as the owner's, and the review fails
  on one that isn't.
- Stack knowledge lives in one home per stack, loaded only when a project uses it. Cloudflare
  Workers is the one that exists, written from what the owner's website shipped.
- gstack (Garry Tan's skills for Claude Code) is the pinned upstream toolbox for the thinking and
  design steps (`/office-hours`, `/spec`, `/design-review`): one commit, never edited.
- Tried and dropped: v1 ran every change through 19 gates and carried about 225k words of docs and
  90k words of skills that drifted apart; v2 has six skills, each meant to fit a page (five in
  `runtime/`, the upgrade with the install), and a 200-word budget for what is always loaded. A spec
  interview on every change cost 9 to 22 owner answers per website change and was skipped in
  practice, so it is now for features only. Design questions first in the spec review missed the
  case they were for and were dropped.

### Tests and docs written for the next agent

**Every test and doc is written for an agent session that has no memory of this one, so a wrong
doc is a bug and an unproven check is no check.**

A session resumes from the PR, the spec and the branch, never from a chat transcript, so the repo
has to carry everything. The docs form one hierarchy under a docs map, and CI fails when a doc is
unreachable from it or a link is broken. Tests are named after what they test and name the
acceptance item they prove, and a project's CI fails an item no test names (this repo does not
yet run that check on itself). Every check that guards something ships with a test that feeds it
a known-bad input, and its PR records the mutants killed, by hand, no mutation tool; a missing
tool or unparseable output fails, never passes. Mechanical steps live in tested scripts
with explicit arguments, never as shell in prose for the model to retype.

- The tests run in two tiers (`tests/run.sh fast|slow`); a test is slow when it tests end to end
  (the whole install, the UI render check, the reviewer's browser), not when it takes long.
- The secret scan is a required check, and its own test commits fake secrets to a scratch repo and
  fails unless every one is caught.
- What is always loaded is budgeted: `CLAUDE.md` stays short, and the skills' descriptions
  together fit 200 words, checked in CI.
- The record is bounded too: a log entry per session is at most 150 words; a finding is one row
  with a severity and its sightings.
- PR bodies claim only what was just read from the real signal (CI, the preview), and the
  reviewer checks the words against the commit.
- The lessons harvested from v1 and the two apps carry only what caught a real problem or kept
  recurring; the rest is listed as considered and not carried.

### Operations: roadmap, bugs, triage, deployment

**The owner decides and the agent records: a roadmap of what was decided, a findings log of what
was noticed, and a deploy that reports back on the PR.**

Every repo keeps a `ROADMAP.md` of what the owner decided, in their words and their order (the
top open entry is the next task), and a `FINDINGS.md` of what the agent noticed and didn't fix.
Intake is the first step of `intent`: a question is answered, a bug fix gets a failing test as its
spec and no "go", a change gets a spec, "put it on the roadmap" gets an entry quoting the request.
A merged PR deploys from `main` only, with deploy secrets in a `production` environment that only
`main` can use; a comment on the PR follows the deploy (Merged, Deploying, Live, with the
previous version and how to undo it), and a second comment records how the change went. The
devshop itself is released from a button only the owner can press: CI computes the version from
the PR titles (a `!` is a breaking change) and creates the tag.

- The agent has its own GitHub account with Write access and cannot approve its own PRs; `main`
  takes PRs only, with the owner's review, and CODEOWNERS covers everything.
- One cloud environment per project holds that project's tokens and network allowlist; the agent
  holds no production secrets, and production access is read-only observability.
- Approval ships: on the owner's approval with green checks, the agent squash-merges without
  asking for a merge message; a push after approval needs a new approval.
- Rollback from day one: each deploy records the previous version and how to undo it; migrations
  are append-only by rule, so a code rollback never needs a database rollback.
- On the one project with traffic, production health is a required check before the merge and a
  canary after the deploy.
- Measured on the PR: the website's last change cost about $8 and 79 minutes from request to
  live, with the owner's touchpoints being decisions, the go and the approval; two recent devshop
  changes cost $6 and $34.

### Versioning and migration: where it is paused

**Each project pins a devshop version and carries copies of the few files its CI runs; keeping
those copies honest across versions is where the work stopped.**

A project's cloud environment clones the devshop read-only with a two-line setup script. At
session start a hook extracts the pinned version and switches to it, so several versions run side
by side and the project's tree stays clean of the devshop. What the project keeps is a contract of
25 items: `.devshop-version`, identical copies of the checks its CI runs (the secret scan, the spec
check, the title check, the contract check), the seeds it adapted (CI, the fast tier) and its own
files. Drift between a copy and the pin shows on a `DEVSHOP:` line at session start, and the
`upgrade` skill opens one PR that moves the pin and re-copies. Releases are SemVer from the
owner's button; a breaking change is a major version and means "this upgrade needs a migration".

- The problem: every devshop change that touches a copy reaches a project only through an upgrade
  PR, one per project, and the devshop's own repo would go red every session without a special
  case. A check weakened inside a project's copy goes green on the weakened copy; only the owner's
  reading of the diff catches it.
- "Needs a migration" is a label so far: the upgrade skill says it and shows the diffs, but no
  migration has been written, and the one real one, lalista from v1 to v2, has not run.
- Where it stopped: 2026-10-21, after lalista was shown to build and run locally on Cloudflare
  Workers. The next step is a sitting of steps only the owner can do (lalista's accounts, tokens
  and branch rules), then the move itself.

## Build log

- 2026-04-10 · Seeded from lalista's own tooling (v0.2.0); v1.0.0 two days later.
- 2026-04 to 2026-06 · v1: a devcontainer with a firewall, hooks and a 19-gate pipeline, used to
  build lalista and home-os; 38 minor releases; last commit 2026-06-02 (v1.38.0).
- 2026-06 to 2026-10 · No commits.
- 2026-10-07 to 09 · Analysis session: six findings against v1, among them a secret scan that detected
  nothing; an adversarial review of the plan; the target picture agreed top-down.
- 2026-10-11 · `v1-final` tagged; `main` protected; the agent gets its own GitHub identity; the
  full history scanned for secrets.
- 2026-10-12 · v2 starts: v1 removed from `main`, a secret scan that works, the pinned install, a
  fixture project on Cloudflare Workers; the independent reviewer and `ship`, with the eval that
  took its recall from 0.33 to 1.0.
- 2026-10-15 · M1 declared met after two end-to-end runs on the fixture.
- 2026-10-16 · v2.0.0; a roadmap and a findings log in every repo; approval merges.
- 2026-10-17 to 18 · The Cloudflare stack home; a design review in build; the reviewer gets a
  browser.
- 2026-10-19 · A new project set up end to end on a throwaway repo; v2.1.0.
- 2026-10-20 · M2 met: the owner's website runs a plain change through v2 (Lighthouse
  99/100/100/100); one project contract; lalista's move to Cloudflare decided.
- 2026-10-21 · lalista builds and runs locally on Workers; last commit. Paused before lalista's
  move, as above.

## Known limitations

- Runs only as a Claude Code cloud session on a GitHub repository; there is no local or Mac path
  yet, so no native builds.
- One stack is real (Cloudflare Workers); Next.js with Supabase is a placeholder, and iOS has not
  started.
- Needs you at the keyboard for the "go" and the approval; nothing merges otherwise, and the first
  set-up has steps only an owner can do.
- The review is feedback, not a wall, and a PR can weaken a check in a copy it carries and go
  green on it; the owner's reading of the diff is the catch.
- Each change costs money: a few dollars for a small website change, tens for a large devshop
  change.
- Written for one person's projects and changing often; no support and no compatibility promise.

## Run it

Not runnable without a GitHub repository you administer, a Claude Code cloud environment and a
second GitHub account for the agent. With those: do [the owner's steps](runtime/templates/new-project-steps.md),
then ask the first session to set up the project ([the `new-project` skill](runtime/skills/new-project/SKILL.md)).
To read instead: [the docs map](docs/README.md) links every doc, and
[the revamp notes](kit/notes/revamp/README.md) hold the plan, the decisions and the per-session
log. To run this repo's own tests: `npm ci`, then `tests/run.sh` (it needs gitleaks, shellcheck and
dcg at the versions pinned in `.github/workflows/ci.yml`).

## Feedback

Suggestions and critiques welcome — open an issue or a discussion.

## License

MIT
