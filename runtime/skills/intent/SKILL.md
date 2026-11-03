---
name: intent
description: Start of every request: say its kind; a change gets a spec with AC-<n> items, an adversarial review and the owner's "go" before building; too big: `devshop:split`.
---

# Intent

Every request starts here (TARGET § L3 Intent). The spec is the record, not the chat.

## 1. Say the kind up front

Name it in your first reply, for the owner to correct.

- **No change** (status, analysis, a question): just do it; no spec, no "go". "What's next?" is
  the top `Open` entry of `ROADMAP.md`.
- **Later** ("put it on the roadmap"): a `ROADMAP.md` entry quoting the request word for word
  (`/opt/devshop-current/templates/roadmap.md` has the rules), its own small PR, no spec.
- **Set-up:** a repo with no `.devshop-version` and no `.github/workflows/ci.yml`:
  `devshop:new-project`, no spec; a whole app continues at § 2 once that PR is up.
- **Bug fix:** restate the problem and the expected behaviour; the failing test is the spec. No
  "go": `build`. A fix with a real choice (behaviour people rely on, several fair fixes) is a change.
- **Any other change:** the steps below; so is an analysis that ends in "we should change X".

## 2. Sharpen it

- Why, who or the problem not settled (a new product, a big or fuzzy feature)? Propose gstack's
  `/office-hours`. A decision that rests on how a tool behaves: an experiment first.
- **Too big for one change** (a whole app; a feature no one PR could show working):
  `devshop:split` before any spec; it comes back here with the first slice.
- A feature gets gstack's `/spec --file-only --no-gate` interview, stopped before it files an
  issue, then the plan reviews that fit. No interview for a small change (one screen or one rule,
  no new model), which gets a one-paragraph spec, nor for a slice the plan document details.

## 3. Write the spec

- Fill `/opt/devshop-current/templates/spec.md` into `specs/<change>.md` as its comments say.
  `specs/` holds spec files only, one per change: the reviewer takes the one `specs/**.md` file a
  change touches as its spec, and anything else there makes the review could-not-run.
- Capture decisions when the owner makes them, not turn by turn. An item that can't be tested or
  done goes back to the owner, never reworded. What only the owner can confirm, or is true only
  after the merge, goes in Decisions.
- Run `/opt/devshop-current/scripts/spec-check.py specs/<change>.md` until it passes. Commit and
  push the draft as you go; nothing is built before the "go".

## 4. Adversarial spec review, before the owner sees it

Give a fresh read-only helper (the `Plan` agent type) only the spec's path and the owner's own
words, and have it attack the spec: its match to the intent and the recorded decisions; ambiguity;
untestable items; missing edge cases and failure modes; scope added; literal code against the
codebase. Its findings are claims to check: fix what you're sure of; the rest go to the owner as
questions. (A mitigation until the independent reviewer reviews specs.)

## 5. The "go"

- Show the owner one screen: intent, decisions, acceptance items, out of scope, rough size, the
  open questions from step 4. On "go", record it on the spec's `**Go:**` line (their words, the
  date), run `spec-check.py --go`, commit and push. Then `build`.
- After the go, a change to a decision or an acceptance item is the owner's: their answer when you
  raise it, or their PR comment. Record its words and date in the spec as theirs; the final review
  fails on one that isn't.
