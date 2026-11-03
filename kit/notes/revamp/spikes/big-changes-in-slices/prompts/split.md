You are the devshop's session in a project. Read only the scratch project at <scratch> (its
ROADMAP.md, README.md and specs/, nothing else), run no git, write nothing. The owner's request,
word for word:

> A small web app for a made-up household, the Example family at example.com: a shared shopping
> list that any member can add to from their phone, with a weekly plan of meals that puts its
> ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four
> members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop
> (its first PR is up); the roadmap already holds two open entries.

Follow the wording below exactly as a skill you were given. Reply with (1) what you would say to
the owner at this point, in full, and (2) if you would write or change any file before the owner
answers, its path and full content; if you would write ROADMAP.md entries after the owner's
approval, give them in full as they would appear.

--- wording ---
# Split

From `intent` § 2, before any spec (TARGET § L3 Intent 8; spec: `big-changes-in-slices`). Nothing
is specced until the owner approves the split.

## 1. Settle the whole

- Why, who or the problem not settled: gstack's `/office-hours` first, if `intent` hasn't run it.
- Propose gstack's `/plan-ceo-review` on the whole (it questions scope and premise, which is what
  decides the slices), then `/plan-eng-review` on the split and its order (the skeleton is an
  architecture call). Run each on a copy of the repo outside it: office-hours writes to
  `docs/designs/` and the plan reviews append to the plan they are given; nothing they write lands.
  Their results feed the screen and the plan document. `/plan-design-review` only if the owner asks.

## 2. Slice it

- **The walking skeleton first:** the thinnest path that deploys and shows one end-to-end step a
  user can exercise (a page; a call, for an app with no UI). In a new repo, `devshop:new-project`
  comes first and is not a slice: set-up, no spec, unmerged until the owner's part 2; the roadmap
  PR and the first slice follow its merge, and the stack's owner set-up steps are part of the
  first slice's go.
- **A UI with no `DESIGN.md`: the design direction is the second slice,** before any slice that
  styles a page beyond the baseline (`/opt/devshop-current/guidelines/ui.md` § Design direction).
- **Then vertical slices,** each shippable and visible to a user, each one PR the owner can judge
  in a sitting; never a layer ("the schema", "the API", "the UI"). Only the next one or two carry
  detail; the rest stay one line.

## 3. One screen, then the owner's approval

- The whole in the owner's words; the slices in order, one line each; what the whole leaves out;
  where the block of slices sits among the roadmap's `Open` entries (consecutive; the owner says
  where the block goes, and may reorder).
- The approval is a go on the shape and the order only: each slice still gets its own spec and go.

## 4. Record, then the first slice

- One PR: one `R-<n>` entry per slice, in the approved order, where the owner said, as the roadmap
  template's slice rule says (each section quotes the request and the approval, word for word, and
  names the other slices). Its body says the split's screen was approved. For a whole app, the
  same PR carries the plan document under `docs/`, linked from each entry and the docs map when
  the project has one: the product in the owner's words, the core flow, the model, the slices and
  why in that order; no status (that lives on the roadmap rows). A big feature on an existing app
  gets no document: its whole is quoted in each slice's entry and spec.
- Then `intent` § 3 for the first slice at once, on its own branch, naming its `R-<n>` (re-checked
  against `main` at ship). "What's next?" picks each later slice: the top `Open` entry.
- After each slice ships, re-read the next against what the build taught and the merged specs. A
  change to the slices is the owner's decision, recorded on the entries it changes with their words
  and date, as a spec change after a go is.
