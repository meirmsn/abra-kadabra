# The `split` run (the new skill's body), verbatim

## (1) What I would say to the owner

This is a change, and a whole app, so it goes through the split before any spec: nothing gets specced until you approve the split's shape and order. Two things first, then one screen.

**Where the repo stands.** The set-up PR from `devshop:new-project` is up and stays unmerged until you have done its part 2, the steps only you can do. The roadmap PR for this split and the first slice both follow that merge. The stack's owner set-up steps (hosting and the like) are part of the first slice's go, so expect to be asked for those then, not now.

**Settling the whole.** Who (the four members of the Example family) and the problem (one list the household shares, fed by the week's meals, cleared by what gets bought) are settled in your request, so I won't run `/office-hours` unless you want it. I do propose two reviews before you give the go:

- `/plan-ceo-review` on the whole: it questions scope and premise, which is what decides the slices.
- `/plan-eng-review` on the split and its order below: the skeleton is an architecture call.

Each runs on a copy of the repo outside it; nothing they write lands in the repo. Their results feed the screen below and the plan document. `/plan-design-review` only if you ask for it. Say "run them" and I come back with this screen revised for your go, or "skip" and the screen below is what you are approving.

**The screen.**

The whole, in your words:

> A small web app for a made-up household, the Example family at example.com: a shared shopping list that any member can add to from their phone, with a weekly plan of meals that puts its ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop (its first PR is up); the roadmap already holds two open entries.

The slices, in order. Each is one PR you can judge in a sitting, shippable and visible; each still gets its own spec and go.

1. **Walking skeleton: the shared shopping list, deployed.** One page at the app's address. Opened on a phone it shows the family's list and lets you add an item, and the item is there for the next person who opens it. No sign-in, baseline look, phone-first. This slice carries the deploy, so your stack set-up steps come with its go.
2. **Design direction.** `DESIGN.md` (type, colour, spacing, light and dark), applied to the list page. It comes before anything is styled beyond the baseline; "light and dark" lands here.
3. Sign-in for the four members at example.com; the list sits behind it and says who added what.
4. Bought: tick an item off the list; it leaves the list and lands on a pantry page that shows what is at home.
5. The weekly plan: a week of meals, each with its ingredients; putting a meal on the week puts its ingredients on the list.
6. Plan meets pantry: ingredients the pantry already holds are not put on the list; a pantry item marked used up goes back on it.

Only 1 and 2 carry detail; 3 to 6 stay one line until each is next. 6 is my reading of why there is a pantry at all; drop it if that is not it.

What the whole leaves out: more than one household; self sign-up, invitations and password reset (four fixed members); notifications; quantities, prices, stores and aisles; recipe import or search; offline use and native apps. R-1 and R-2 stay their own entries.

Where the block sits: I would put it at the top, as R-3 to R-8, with R-1 (privacy page) and R-2 (who is signed in, in the header) after it, since both need the app to exist first, a footer and a sign-in. R-2 is close to slice 3: it can stay its own entry after the block, or you can fold it into slice 3's spec. Your call, and you can reorder any of it.

Your approval is a go on the shape and the order only. On it, and once the set-up PR is merged, one PR records a row and a section per slice on the roadmap, in this order, where you say, with the plan document under `docs/`; then I start slice 1 at once on its own branch, naming its R-number. After each slice ships I re-read the next against what the build taught; any change to the slices is yours to decide and gets recorded on the entries with your words and the date.

So, three answers: run the reviews or skip them; approve the shape and the order, or change them; and where the block goes.

## (2) Files

**Before the owner answers: nothing.** No file is written or changed. The reviews, if the owner wants them, run on a copy of the repo outside it and nothing they write lands. The roadmap PR waits for the approval and for the set-up PR's merge.

**After the owner's approval:** one PR on its own branch whose body says the split's screen was approved, carrying `ROADMAP.md` below and the plan document `docs/plan.md` (the product in the owner's words, the core flow, the model, the slices and why in that order; no status), linked from each entry. IDs R-3 to R-8 assume they are the next free numbers; they are re-checked against `main` at ship. Placement assumes the owner took "at the top"; if they say otherwise the block moves as one, consecutive. The approval quote and its date are what the owner actually says, inserted word for word where marked.

`ROADMAP.md`, in full as it would appear (the header, template comment, and the R-1 and R-2 sections are unchanged):

````markdown
# Roadmap

What the owner decided will happen, in their words. The table's order is the priority: the top
`Open` entry is next. What Claude noticed but nobody decided is in `FINDINGS.md`.

<!--
Roadmap template (specs/findings-and-roadmap.md in the devshop). Create the repo's root ROADMAP.md
from it on its first entry; delete this comment and the example row there.

- What goes in: a request the owner wants done later ("put it on the roadmap", "later"), or a
  finding the owner answered "roadmap" to (its FINDINGS.md row is deleted in the same commit). A
  new request is its own small PR with no spec: the owner's words are the go.
- Only this repo's: a project need that is really a devshop feature goes on the devshop's roadmap,
  through the block of devshop findings the session gives the owner at hand-over.
- ID: R-<n>, never reused; the next free number, checked against the latest main before ship.
- Order: the owner's priority. Add at the bottom unless the owner says where; only the owner
  reorders.
- Status: Open, Done (with the PR that delivered it) or Dropped (with the reason). A closed entry
  keeps its row as a one-line record and loses its section: from the go on, the spec quotes the
  request.
- Section: one per Open entry, quoting the owner's request word for word in a fenced text block,
  with where and when they said it. Claude's own notes, if any, go under a heading that says so.
- A slice (devshop:split; specs/big-changes-in-slices.md in the devshop): an ordinary R-<n> row,
  one per slice, in the order the owner approved, the block consecutive and placed where they said.
  Its section quotes the owner's original request and their approval of the split, word for word,
  and names the other slices' IDs; the slice's own detail goes under Claude's notes. The quoted
  approval is the owner's go for the entry. The spec that delivers a slice names its R-<n>.
-->

| ID  | Added      | What                                                                                              | Status |
| --- | ---------- | ------------------------------------------------------------------------------------------------- | ------ |
| R-3 | 2026-10-30 | Household app, slice 1 of 6: the shared shopping list, deployed; one page, add an item from a phone | Open   |
| R-4 | 2026-10-30 | Household app, slice 2 of 6: the design direction (DESIGN.md), light and dark, on the list page    | Open   |
| R-5 | 2026-10-30 | Household app, slice 3 of 6: sign-in for the four members; the list says who added what            | Open   |
| R-6 | 2026-10-30 | Household app, slice 4 of 6: tick an item off as bought; it moves to the pantry page               | Open   |
| R-7 | 2026-10-30 | Household app, slice 5 of 6: the weekly meal plan puts its ingredients on the list                 | Open   |
| R-8 | 2026-10-30 | Household app, slice 6 of 6: the plan skips what the pantry holds; used up goes back on the list   | Open   |
| R-1 | 2026-10-28 | A privacy page, one paragraph, linked from the footer                                             | Open   |
| R-2 | 2026-10-29 | The sign-in page says which member is signed in, in the header                                    | Open   |

## R-3: Household app, slice 1 of 6: the shared shopping list, deployed

Asked 2026-10-30, in chat (the whole app; R-3 to R-8 are its slices):

```text
A small web app for a made-up household, the Example family at example.com: a shared shopping
list that any member can add to from their phone, with a weekly plan of meals that puts its
ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four
members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop
(its first PR is up); the roadmap already holds two open entries.
```

Split approved <date>, in chat:

```text
<the owner's approval, word for word>
```

Slice 1 of 6. The other slices: R-4, R-5, R-6, R-7, R-8. The plan: [docs/plan.md](docs/plan.md).

### Claude's notes

The walking skeleton: the thinnest path that deploys and shows one end-to-end step. One page at
the app's address; opened on a phone it shows the family's list and lets you add an item, and the
item is there for the next person who opens it. No sign-in, baseline look, phone-first. Carries
the deploy: the stack's owner set-up steps are part of this slice's go.

## R-4: Household app, slice 2 of 6: the design direction (DESIGN.md), light and dark, on the list page

Asked 2026-10-30, in chat (the whole app; R-3 to R-8 are its slices):

```text
A small web app for a made-up household, the Example family at example.com: a shared shopping
list that any member can add to from their phone, with a weekly plan of meals that puts its
ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four
members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop
(its first PR is up); the roadmap already holds two open entries.
```

Split approved <date>, in chat:

```text
<the owner's approval, word for word>
```

Slice 2 of 6. The other slices: R-3, R-5, R-6, R-7, R-8. The plan: [docs/plan.md](docs/plan.md).

### Claude's notes

The repo has no `DESIGN.md`, so the design direction is the second slice, before any page is
styled beyond the baseline. `DESIGN.md` (type, colour, spacing, light and dark) applied to the
list page; "light and dark" from the request lands here.

## R-5: Household app, slice 3 of 6: sign-in for the four members; the list says who added what

Asked 2026-10-30, in chat (the whole app; R-3 to R-8 are its slices):

```text
A small web app for a made-up household, the Example family at example.com: a shared shopping
list that any member can add to from their phone, with a weekly plan of meals that puts its
ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four
members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop
(its first PR is up); the roadmap already holds two open entries.
```

Split approved <date>, in chat:

```text
<the owner's approval, word for word>
```

Slice 3 of 6. The other slices: R-3, R-4, R-6, R-7, R-8. The plan: [docs/plan.md](docs/plan.md).

### Claude's notes

Sign-in for the four members at example.com; the list sits behind it and says who added what.
R-2 (who is signed in, in the header) is close to this slice; it stays its own entry unless the
owner folds it into this slice's spec.

## R-6: Household app, slice 4 of 6: tick an item off as bought; it moves to the pantry page

Asked 2026-10-30, in chat (the whole app; R-3 to R-8 are its slices):

```text
A small web app for a made-up household, the Example family at example.com: a shared shopping
list that any member can add to from their phone, with a weekly plan of meals that puts its
ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four
members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop
(its first PR is up); the roadmap already holds two open entries.
```

Split approved <date>, in chat:

```text
<the owner's approval, word for word>
```

Slice 4 of 6. The other slices: R-3, R-4, R-5, R-7, R-8. The plan: [docs/plan.md](docs/plan.md).

### Claude's notes

Tick an item off the list as bought; it leaves the list and lands on a pantry page that shows
what is at home.

## R-7: Household app, slice 5 of 6: the weekly meal plan puts its ingredients on the list

Asked 2026-10-30, in chat (the whole app; R-3 to R-8 are its slices):

```text
A small web app for a made-up household, the Example family at example.com: a shared shopping
list that any member can add to from their phone, with a weekly plan of meals that puts its
ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four
members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop
(its first PR is up); the roadmap already holds two open entries.
```

Split approved <date>, in chat:

```text
<the owner's approval, word for word>
```

Slice 5 of 6. The other slices: R-3, R-4, R-5, R-6, R-8. The plan: [docs/plan.md](docs/plan.md).

### Claude's notes

A week of meals, each with its ingredients; putting a meal on the week puts its ingredients on
the list.

## R-8: Household app, slice 6 of 6: the plan skips what the pantry holds; used up goes back on the list

Asked 2026-10-30, in chat (the whole app; R-3 to R-8 are its slices):

```text
A small web app for a made-up household, the Example family at example.com: a shared shopping
list that any member can add to from their phone, with a weekly plan of meals that puts its
ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four
members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop
(its first PR is up); the roadmap already holds two open entries.
```

Split approved <date>, in chat:

```text
<the owner's approval, word for word>
```

Slice 6 of 6. The other slices: R-3, R-4, R-5, R-6, R-7. The plan: [docs/plan.md](docs/plan.md).

### Claude's notes

Ingredients the pantry already holds are not put on the list by the plan; a pantry item marked
used up goes back on the list. Claude's reading of why there is a pantry; the owner kept it on the
screen.

## R-1: A privacy page, one paragraph, linked from the footer

Asked 2026-10-28, in chat:

```text
we need a privacy page, one paragraph is enough, linked from the footer
```

## R-2: The sign-in page says which member is signed in, in the header

Asked 2026-10-29, in chat:

```text
when signed in, show who is signed in in the header
```
````

Then `intent` § 3 for R-3 at once, on its own branch, its spec naming R-3.
