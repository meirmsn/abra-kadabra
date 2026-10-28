# Abra-Kadabra

> **Status: Work in progress** · last touched 2026-10

**Describe the app you want. Get one that is slick, reliable and secure, with you in control at
every step.**

This is a running prototype of a dev shop run by Claude Code agents: you bring the strategy and
the product you want; agents plan, spec, build and review; your input steers and your approval ships
the changes. Made for one person running their own products.

Used to build [lalista](https://lalista.store) ([repo](https://github.com/meirmsn/lalista)),
[home-os](https://github.com/meirmsn/home-os) and
[meirmsn.dev](https://meirmsn.dev). Suggestions welcome; see Feedback below.

## Approach

While building lalista with coding agents, I kept whatever seemed generic enough to reuse on other
projects in a separate system: this repo. It covers the steps I kept doing by hand:

- **Intent:** getting clear on what to build for a project, exploring the assumptions and the
  blind spots, creating a product plan and then a spec.
- **Build:** a builder that takes the spec and implements it.
- **Verify:** a checker that verifies the result against the intention, tests and docs included,
  so the next agent knows where things stand and nothing built so far regresses.
- **Walls:** all of it set up so the agents cannot sidestep it: what I have approved so far does
  not change without me noticing.

**v1** came out of lalista and was used as is to build home-os, with the development environment
on my own machine. **v2** is a rewrite so that everything runs in cloud sessions, which were easy
to interact with from my phone as well; my personal website was built with it. Human in the loop:
[@meirmsn](https://github.com/meirmsn); robot hands:
[@meirmsn-agent](https://github.com/meirmsn-agent).

**The recursion.** The manual work of setting up a system that builds apps is the same work the
system is meant to do: I open PRs by hand in the shape I want the machine to use, I keep a roadmap
by hand and pick the next task from it, as I want its projects to. The recursion ends in me: I am
the base case, the manual start the automated version is refined from, the way a rough tool is
used to make a finer one.

## What it does

**One change, from the request to production:**

```text
you ──▶ "I want …"           a whole app, a feature, or a bug fix
         │
         ▼
       intent   Claude sharpens it with you into a spec (split into smaller changes if too large)
         │
         ▼  you approve the spec and say "go"
       build    one agent loads the skills and guidelines the change needs, then writes code,
         │      tests and docs together, keeping to the spec and the project's design file
         ▼
       review   a second agent, with none of the builder's context, checks the diff against the
         │      spec, and the tests and docs with it; fail → back to build, until it passes
         ▼
       ship     the PR opens only on a pass, with the verdict on it
         │
         ▼
you ──▶ read the PR (summary, release note, preview, evidence), comment to steer, or approve
         │
         ▼  approve
       merge → deploy from main → canary → a summary on the PR: how long it took, what it cost

walls the agent can't move: main takes only PRs you approved · required CI · no production secrets
```

**From request to PR.** Every request, from a whole app to a one-line fix, starts as a
conversation in which Claude helps you sharpen what you want into a **one-screen spec** you say
"go" to. One agent builds the change with its tests and docs; a **second agent** with none of the
builder's context reviews it against the spec, and only a pass opens the PR.

**The PR.** It reads top-down: one line, a **release note** in your users' words, what you should
know, a **preview** you can try yourself, **evidence** (screenshots when the UI changed, the
reviewer's verdict, CI), and the engineering details.

**After your approval.** The merge deploys; the deploy and a **canary** of the live site report
back on the PR, rollback instructions included, and lastly a **summary** is posted to it with the
time and cost taken for the change. Any issue the agent noticed outside the spec is **logged, not
fixed**, so the PR stays scoped; it comes back to you only when it recurs. A **new project** starts
green in its first session: seed files placed, CI included, and a checklist of the steps only you
can do.

**The walls.** The other half of the devshop is what the agent can never do (push to `main`, merge
without you, hold a production secret), so that trusting a change means **reading its PR, not
auditing the agent**.

## How it works

### Adversarial review

**The builder never grades its own work: a second agent with none of its context reviews the
change against the spec, and the PR cannot open until it passes.**

#### The one road to a PR

`ship.sh` runs `review.sh`, which starts a fresh, locked-down `claude -p` in a throwaway clone: it
can read, run the tests and browse a local run of the app, and can neither edit nor push. The
reviewer finds the spec the change adds, checks every acceptance item for evidence, then applies the
lenses that fit (code, security, design, QA, tests, docs). Only a pass pushes the branch and opens
or updates the PR with exactly the words that were reviewed, then posts the verdict as a comment
tied to that commit. A hook refuses the other roads (`gh pr create`, a push on a branch with an open
PR).

#### What it checks

- **Three outcomes:** pass, fail, could-not-run; the last never passes. The verdict is JSON against
  a schema, and anything the reviewer can't parse or trust fails closed.
- **Tests and docs at the same depth as code:** would this test fail if the code were wrong; is a
  deleted or loosened test justified by the spec; would a future agent reading only the docs do
  the right thing.
- **Findings:** medium or above is fixed or goes to the owner; low is logged, not fixed on reflex.
  After three rounds on the same thing, the agent asks.

#### How it is kept honest

- **Measured:** an eval of planted spec violations, run by hand before any change to how it
  reviews, whose result goes in that PR. Its recall was 0.33 until its Bash tool turned out to be
  missing, then 1.0.
- **Tried and changed:** a full review on every change to the PR's words cost five reviews on one
  PR, so a change to title or body alone now gets a words-only review.
- **Before the "go" too:** a read-only helper checks the spec against the owner's own words
  before the owner sees it.

#### What it is not

- **Not a wall:** an agent that controls its own session could skip it. The walls are GitHub's
  rules on `main`, plain CI and the owner's approval; a push with no verdict after it is the
  tripwire. An air-gapped reviewer as a required check is on the roadmap.

### Product, design and engineering, separated

**Product, design and engineering each hand the next step a written artefact (the spec, the
design file and its review, the tests and docs), and the chat is never the record.**

#### Three skills, one hand-off each

`intent` names the kind of request (no change, bug fix,
change) and, for a change, writes a spec file in the project's `specs/`: intent in the owner's
words, decisions with their reasons, numbered acceptance items, out of scope; a UI change adds its
core flow and a state table. The owner's "go" is recorded on the spec, which stays after the merge
as context for later sessions. `build` is one writer: it loads only what applies (the project's
rules, the stack's home, the guideline of each discipline it touches), changes code, tests and
docs together, and names each acceptance item in the test that proves it. `pr` writes the PR's
words from a template and hands them to `ship`.

#### Design

A baseline of design tokens in light and dark, a `DESIGN.md` per project, a design review on a local
run before the PR, and the reviewer's browser judging each touched page against that `DESIGN.md`.

#### What holds it together

- **Decisions are written where they belong** (the spec, the PR, the decision log) when the owner
  makes them; a decision changed after the "go" is recorded as the owner's, and the review fails
  on one that isn't.
- **One home per stack,** loaded only when a project uses it. Cloudflare Workers is the one that
  exists, written from what the owner's website shipped.
- **gstack** (Garry Tan's skills for Claude Code) is the pinned upstream toolbox for the thinking
  and design steps (`/office-hours`, `/spec`, `/design-review`): one commit, never edited.

#### Tried and dropped

v1 ran every change through 19 gates and carried about 225k words of docs and 90k words of skills
that drifted apart; v2 has six skills, each meant to fit a page (five in `runtime/`, the upgrade
with the install), and a 200-word budget for what is always loaded. A spec interview on every change
cost 9 to 22 owner answers per website change and was skipped in practice, so it is now for features
only. Design questions first in the spec review missed the case they were for and were dropped.

### Tests and docs written for the next agent

**Every test and doc is written for an agent session that has no memory of this one, so a wrong
doc is a bug and an unproven check is no check.**

#### The repo carries everything

A session resumes from the PR, the spec and the branch, never from a chat transcript. The docs form
one hierarchy under a **docs map**, and CI fails when a doc is unreachable from it or a link is
broken. Tests are named after what they test and **name the acceptance item** they prove, and a
project's CI fails an item no test names (this repo does not yet run that check on itself).

#### Every check is proven to fail

A check that guards something ships with a test that feeds it a known-bad input, and its PR records
the mutants killed, by hand, no mutation tool; a missing tool or unparseable output fails, never
passes. Mechanical steps live in **tested scripts** with explicit arguments, never as shell in prose
for the model to retype.

#### Budgets and bounds

- **Two tiers** (`tests/run.sh fast|slow`); a test is slow when it tests end to end (the whole
  install, the UI render check, the reviewer's browser), not when it takes long.
- **The secret scan** is a required check, and its own test commits fake secrets to a scratch repo
  and fails unless every one is caught.
- **What is always loaded is budgeted:** `CLAUDE.md` stays short, and the skills' descriptions
  together fit 200 words, checked in CI.
- **The record is bounded too:** a log entry per session is at most 150 words; a finding is one
  row with a severity and its sightings.
- **No unverified claims:** PR bodies claim only what was just read from the real signal (CI, the
  preview), and the reviewer checks the words against the commit.
- **Lessons carry only what bit:** the lessons harvested from v1 and the two apps carry only what
  caught a real problem or kept recurring; the rest is listed as considered and not carried.

### Operations: roadmap, bugs, triage, deployment

**The owner decides and the agent records: a roadmap of what was decided, a findings log of what
was noticed, and a deploy that reports back on the PR.**

#### Roadmap and findings

A `ROADMAP.md` of what the owner decided, in their words and their order (the top open entry is the
next task), and a `FINDINGS.md` of what the agent noticed and didn't fix.

**Intake** is the first step of `intent`: a question is answered, a bug fix gets a failing test as
its spec and no "go", a change gets a spec, "put it on the roadmap" gets an entry quoting the
request.

#### Deployment

A merged PR deploys from `main` only, with deploy secrets in a `production` environment that only
`main` can use; a comment on the PR follows the deploy (Merged, Deploying, Live, with the previous
version and how to undo it), and a second comment records how the change went. The devshop itself is
released from a button only the owner can press: CI computes the version from the PR titles (a `!`
is a breaking change) and creates the tag.

- **Rollback from day one:** each deploy records the previous version and how to undo it;
  migrations are append-only by rule, so a code rollback never needs a database rollback.
- **Production health** is a required check before the merge and a canary after the deploy, on
  the one project with traffic.
- **Measured on the PR:** the website's last change cost about $8 and 79 minutes from request to
  live, with the owner's touchpoints being decisions, the go and the approval; two recent devshop
  changes cost $6 and $34.

#### Identity and environments

- **The agent's identity:** its own GitHub account with Write access, which cannot approve its own
  PRs; `main` takes PRs only, with the owner's review, and CODEOWNERS covers everything.
- **One cloud environment per project** holds that project's tokens and network allowlist; the
  agent holds no production secrets, and production access is read-only observability.
- **Approval ships:** on the owner's approval with green checks, the agent squash-merges without
  asking for a merge message; a push after approval needs a new approval.

### Versioning and migration: where it is paused

**Each project pins a devshop version and carries copies of the few files its CI runs; keeping
those copies honest across versions is where the work stopped.**

#### How a project gets the devshop

Its cloud environment clones the devshop read-only with a two-line setup script. At session start a
hook extracts the **pinned version** and switches to it, so several versions run side by side and
the project's tree stays clean of the devshop.

#### What a project keeps

It is a contract of 25 items: `.devshop-version`, identical copies of the checks its CI runs (the
secret scan, the spec check, the title check, the contract check), the seeds it adapted (CI, the
fast tier) and its own files. Drift between a copy and the pin shows on a `DEVSHOP:` line at session
start, and the `upgrade` skill opens one PR that moves the pin and re-copies. Releases are SemVer
from the owner's button; a breaking change is a major version and means "this upgrade needs a
migration".

#### The problem, and where it stopped

- **The problem:** every devshop change that touches a copy reaches a project only through an
  upgrade PR, one per project, and the devshop's own repo would go red every session without a
  special case. A check weakened inside a project's copy goes green on the weakened copy; only the
  owner's reading of the diff catches it.
- **"Needs a migration" is a label so far:** the upgrade skill says it and shows the diffs, but no
  migration has been written, and the one real one, lalista from v1 to v2, has not run.
- **Where it stopped:** 2026-10-21, after lalista was shown to build and run locally on Cloudflare
  Workers. The next step is a sitting of steps only the owner can do (lalista's accounts, tokens
  and branch rules), then the move itself.

## Learnings so far

- **No boundary inside the session.** Nothing inside the agent's session is a real boundary: a
  determined agent finds a way around a hook or a check it can reach.
- **Constraints out of reach.** For constraints to work they must sit out of the agent's reach,
  and change only through a PR that only a human can approve. That way the agent can never grant
  itself more than you have already granted it.
- **The walls here.** On this devshop the walls are GitHub's rules on `main`, plain CI and human
  approval of every PR (the agent works under its own GitHub identity); the mechanical checks they
  run are the guards, and everything else is feedback.
- **Log, don't chase.** Agents always find something to improve, and will happily chase long
  tails. Nothing is fixed on reflex: each suggestion is logged with its sightings, and it is built
  once it has come back enough times.
- **The reviewer is a mentee.** Adversarial review is a must, but it only checks what you taught
  it to check, so it grows like a mentee, from your corrections. You are the last reviewer: when
  the agent didn't do as you wanted, because the guidance was thin or the model wasn't up to it,
  your correction goes back into the guidance. Don't expect it to work your way until the cases
  you keep hitting are covered.
- **Bootstrapped by hand.** A system that builds apps is bootstrapped by hand with the very work
  it will automate. The recursion ends in you, and each manual round makes the next automated one
  finer.

## Build log

- **2026-04-10** · Seeded from lalista's own tooling (v0.2.0); v1.0.0 two days later.
- **2026-04 to 2026-06** · v1: a devcontainer with a firewall, hooks and a 19-gate pipeline, used
  to build lalista and home-os; 38 minor releases; last commit 2026-06-02 (v1.38.0).
- **2026-06 to 2026-10** · No commits.
- **2026-10-07 to 09** · Analysis session: six findings against v1, among them a secret scan that
  detected nothing; an adversarial review of the plan; the target picture agreed top-down.
- **2026-10-11** · `v1-final` tagged; `main` protected; the agent gets its own GitHub identity;
  the full history scanned for secrets.
- **2026-10-12** · v2 starts: v1 removed from `main`, a secret scan that works, the pinned install,
  a fixture project on Cloudflare Workers; the independent reviewer and `ship`, with the eval that
  took its recall from 0.33 to 1.0.
- **2026-10-15** · M1 declared met after two end-to-end runs on the fixture.
- **2026-10-16** · v2.0.0; a roadmap and a findings log in every repo; approval merges.
- **2026-10-17 to 18** · The Cloudflare stack home; a design review in build; the reviewer gets a
  browser.
- **2026-10-19** · A new project set up end to end on a throwaway repo; v2.1.0.
- **2026-10-20** · M2 met: the owner's website runs a plain change through v2 (Lighthouse
  99/100/100/100); one project contract; lalista's move to Cloudflare decided.
- **2026-10-21** · lalista builds and runs locally on Workers; the last commit before this README.
  Paused before lalista's move, as above.

## Known limitations

- **Cloud only:** runs only as a Claude Code cloud session on a GitHub repository; there is no
  local or Mac path yet, so no native builds.
- **One stack:** Cloudflare Workers is real in v2; Next.js with Supabase, which v1 ran lalista and
  home-os on, is a placeholder in v2, and iOS has not started.
- **The review is feedback, not a wall,** and a PR can weaken a check in a copy it carries and go
  green on it; the owner's reading of the diff is the catch.
- **Each change costs money:** a few dollars for a small website change.
- **One person's tool:** written for one person's projects and changing often; no support and no
  compatibility promise. If any of this is a problem you face, the Feedback section below is where
  to say so.

## Run it

- **To use it** you need a GitHub repository you administer, a Claude Code cloud environment and
  a second GitHub account for the agent. With those: do
  [the owner's steps](runtime/templates/new-project-steps.md), then ask the first session to set
  up the project ([the `new-project` skill](runtime/skills/new-project/SKILL.md)).
- **To read it:** [the docs map](docs/README.md) links every doc, and
  [the revamp notes](kit/notes/revamp/README.md) hold the plan, the decisions and the per-session
  log.
- **To test it:** `npm ci`, then `tests/run.sh` (it needs gitleaks, shellcheck and dcg at the
  versions pinned in `.github/workflows/ci.yml`).

## Feedback

Suggestions and critiques welcome — open an issue or a discussion.

## License

MIT
