---
name: intent
description: Start of every request. Say its kind (no change, bug fix, change); for a change, sharpen it into a spec in specs/ with AC-<n> items, have it reviewed adversarially, and get the owner's "go" before building.
---

# Intent

Every request starts here (TARGET § L3 Intent). The chat is where you ask and the owner answers; the
spec is the record.

## 1. Say the kind up front

Name it in your first reply; the owner can correct you.

- **No change** (status, analysis, a question, an investigation): just do it. No spec, no "go".
- **Bug fix:** restate the problem and the expected behaviour; the failing test is the spec. No
  "go": go to `build`. A fix that involves a real choice (it changes behaviour people rely on, or
  there are several reasonable fixes) is a change.
- **Any other change:** the steps below. An analysis that ends in "we should change X" becomes a
  change at that point.

## 2. Sharpen it

- Why, who or the problem not settled (a new product, a big or fuzzy feature)? Propose gstack's
  `/office-hours` first.
- Every change, however small, gets gstack's `/spec --file-only --no-gate` interview; stop before it
  files an issue (the spec file is the record; step 4 replaces its gate). Then the plan reviews that fit.
- A decision that rests on how a tool or version behaves: prove it with a quick experiment first.
- Too big for one change? Propose a split, one spec each.

## 3. Write the spec

- Fill `/opt/devshop-current/templates/spec.md` into the project's `specs/<change>.md`: intent in
  the owner's words; decisions with their reasons; acceptance items `AC-1`, `AC-2`, … (what must be
  true, pass/fail); out of scope. UI changes add the core flow (2–4 steps) and a state table.
- `specs/` holds spec files only, one per change. The reviewer takes the one `specs/**.md` file a
  change adds or changes as its spec, so a README or template there makes the review could-not-run.
- Capture decisions when the owner makes them, not turn by turn.
- An item that can't be tested or can't be done goes back to the owner; never reword it to fit.
- Run `/opt/devshop-current/scripts/spec-check.py specs/<change>.md` until it passes. Commit and
  push the draft on the change's branch as you go; nothing is built before the "go".

## 4. Adversarial spec review, before the owner sees it

Give a fresh read-only helper (the `Plan` agent type, which can't edit) only the spec's path and the
owner's own words. Ask it to attack the spec: does it match the intent and the recorded decisions;
what is ambiguous; which items can't be tested; which edge cases and failure modes are missing;
what scope was added beyond the ask; does literal code in it match the codebase. Its findings are
claims to check. Fix what you're sure of; the rest go to the owner as questions.

_Mitigation:_ TARGET has the independent reviewer do this; its spec mode is an M2 item.

## 5. The "go"

- Show the owner one screen: intent, decisions, acceptance items, out of scope, rough size, and the
  open questions from step 4.
- On "go", record it on the spec's `**Go:**` line (their words, the date), run `spec-check.py --go`,
  commit and push on the same branch. Then `build`.
- After the go, a change to a decision or an acceptance item is raised with the owner, decided by
  them and recorded in the spec as theirs. The final review fails on any that isn't.
