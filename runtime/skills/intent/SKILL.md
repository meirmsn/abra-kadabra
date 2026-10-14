---
name: intent
description: Start of every request. Say its kind (no change, bug fix, change); for a change, sharpen it into a spec in specs/ with AC-<n> items, have it reviewed adversarially, and get the owner's "go" before building.
---

# Intent

Every request starts here (TARGET § L3 Intent). Ask in the chat; the spec is the record.

## 1. Say the kind in your first reply (the owner can correct you)

- **No change** (status, analysis, a question, an investigation): just do it. No spec, no "go".
- **Bug fix:** restate the problem and the expected behaviour; the failing test is the spec. No
  "go": go to `build`. A fix with a real choice (it changes behaviour people rely on, or several
  fixes are reasonable) is a change.
- **Any other change:** the steps below, as is an analysis that ends in "we should change X".

## 2. Sharpen it

- Why, who or the problem not settled (a new product, a big or fuzzy feature)? Propose gstack's
  `/office-hours` first.
- Every change gets gstack's `/spec --file-only --no-gate` interview; stop before it files an issue
  (the spec file is the record; step 4 replaces its gate). Then the plan reviews that fit.
- Before choosing a fix, ask why the problem exists; fix the cause when it is within reach.
- A decision resting on how a tool or version behaves: prove it with a quick experiment first.
- Too big for one change? Propose a split, one spec each.

## 3. Write the spec

- Fill `/opt/devshop-current/templates/spec.md` into the project's `specs/<change>.md`: intent in
  the owner's words; decisions with their reasons; acceptance items `AC-1`, `AC-2`, … (what must be
  true, pass/fail); out of scope. UI changes add the core flow (2–4 steps) and a state table.
- `specs/` holds only spec files, one per change: the reviewer takes the one `specs/**.md` file a
  change touches as its spec, so any other file there makes the review could-not-run.
- Capture decisions when the owner makes them, not turn by turn.
- An item that can't be tested or done goes back to the owner; never reword it to fit.
- Run `/opt/devshop-current/scripts/spec-check.py specs/<change>.md` until it passes. Commit and
  push the draft on its branch as you go; nothing is built before the "go".

## 4. Adversarial spec review, before the owner sees it

Give a fresh read-only helper (the `Plan` agent type, which can't edit) only the spec's path and the
owner's own words. Ask it to attack the design first: does it fix where the problem starts or only
where it shows (name the cause); argue for the strongest option the author rejected or didn't list;
is the size in proportion; what new failure modes does it add. Then the details: does it match
intent and decisions; what is ambiguous or untestable; which edge cases are missing; what scope was
added; does its literal code match the codebase. Its findings are claims to check. Fix what you're
sure of; the rest go to the owner as questions.

_Mitigation:_ TARGET has the independent reviewer do this; its spec mode is an M2 item.

## 5. The "go"

- Show the owner one screen: intent, decisions, acceptance items, out of scope, rough size,
  step 4's open questions.
- On "go", record it on the spec's `**Go:**` line (their words, the date), run `spec-check.py --go`,
  commit and push. Then `build`.
- After the go, the owner decides any change to a decision or an acceptance item, recorded in the
  spec as theirs; the final review fails on any that isn't.
