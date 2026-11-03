# Control run 2 (old `intent` § 2 wording, scratch roadmap with the template as on `main`), verbatim

(1) What I would say to the owner

This is a change, and a new product: nothing exists yet beyond the devshop setup. The roadmap holds R-1 (a privacy page, linked from the footer) and R-2 (who is signed in, in the header); specs/ is empty. Two things before any spec is written.

Office hours first. The why, who and problem are not settled yet: four members of a made-up family, and four features that touch each other. What "a pantry that ticks items off when bought" means against the list (bought items move off the list into the pantry? the pantry empties as things are used?); whether the weekly plan carries quantities or just ingredient names; whether sign-in is passwords, magic links or a shared family code for four fixed accounts at example.com; how far "from their phone" goes beyond a responsive page (home-screen install, offline). I propose gstack's `/office-hours`, builder mode, to settle these before anything is written. Say "go" for that, or answer those four questions here and we skip it.

It is too big for one change. I propose a split into four slices, one spec each, each leaving a working app behind:

1. The shell and sign-in: the app exists and deploys, is responsive, has light and dark, has a header and a footer; the four members sign in. R-2 (show who is signed in, in the header) belongs here as a line in this spec rather than its own PR, if you agree. R-1 (the privacy page in the footer) stays its own small PR with no spec, once the footer exists.
2. The shared shopping list: any signed-in member adds to it from their phone; items are ticked off when bought.
3. The pantry: what was bought leaves the list and lands in the pantry, and is used up from there (or however office hours settles it).
4. The weekly plan of meals: a week of meals whose ingredients go onto the list, with the pantry taken into account.

Order: sign-in first because every other slice says "any member"; the list before the pantry and the plan because both feed it. If you would rather see the list before accounts, that works too: slice 2 goes first without sign-in and slice 1 adds the members after.

If you say go to the split: slice 1 gets its `/spec --file-only --no-gate` interview and its spec in specs/, then the plan reviews that fit, then your "go" on that spec before I build. Slices 2 to 4 go on the roadmap as R-3 to R-5, quoting your request, added at the bottom; you say where they sit against R-1 and R-2. Both of those need the app from slice 1 to exist, so I would expect the slices above them, but only you reorder.

No experiment is needed for this decision. The stack (framework, how sign-in and dark mode are done) comes up in slice 1's spec, and any choice there that rests on how a tool or version behaves gets a quick experiment first.

One aside: ROADMAP.md still carries the template's comment block, which says to delete it on the first entry. Say the word and it goes in the same commit as the new entries.

So: office hours, yes or no; and the split, yes, reordered, or no.

(2) Files

Before the owner answers: nothing is written or changed. Office hours and the split both wait on the owner; the first spec file comes out of the `/spec` interview after that.

After the owner approves the split (and the order as proposed), the scratch `ROADMAP.md` gains these three table rows, appended after R-2's row, and these three sections, appended after the R-2 section. The rest of the file is unchanged (the template comment stays unless the owner says to drop it):

Table rows:

```text
| R-3 | 2026-10-30 | A shared shopping list that any member can add to from their phone | Open   |
| R-4 | 2026-10-30 | A pantry that ticks items off when bought                     | Open   |
| R-5 | 2026-10-30 | A weekly plan of meals that puts its ingredients on the list  | Open   |
```

Sections:

````markdown
## R-3: A shared shopping list that any member can add to from their phone

Asked 2026-10-30, in chat, as part of the request for the whole app:

```text
A small web app for a made-up household, the Example family at example.com: a shared shopping
list that any member can add to from their phone, with a weekly plan of meals that puts its
ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four
members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop
(its first PR is up); the roadmap already holds two open entries.
```

### Claude's notes

Slice 2 of the four the owner agreed to on 2026-10-30: the shopping-list part of the request
above. Follows slice 1 (the shell and sign-in, its spec in specs/), which it needs for "any
member". Items are ticked off when bought; what happens to a bought item is R-4's.

## R-4: A pantry that ticks items off when bought

Asked 2026-10-30, in chat, as part of the request for the whole app:

```text
A small web app for a made-up household, the Example family at example.com: a shared shopping
list that any member can add to from their phone, with a weekly plan of meals that puts its
ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four
members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop
(its first PR is up); the roadmap already holds two open entries.
```

### Claude's notes

Slice 3 of four: the pantry part of the request above. Needs R-3 (the list it ticks items off
from). How a bought item moves from the list to the pantry, and how the pantry is used up, is
what office hours settled on 2026-10-30; the spec for this slice quotes that.

## R-5: A weekly plan of meals that puts its ingredients on the list

Asked 2026-10-30, in chat, as part of the request for the whole app:

```text
A small web app for a made-up household, the Example family at example.com: a shared shopping
list that any member can add to from their phone, with a weekly plan of meals that puts its
ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four
members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop
(its first PR is up); the roadmap already holds two open entries.
```

### Claude's notes

Slice 4 of four: the meal-plan part of the request above. Needs R-3 (the list its ingredients
go on) and R-4 (so what is already in the pantry is not put on the list again).
````

If the owner instead says the slices sit above R-1 and R-2, the three rows move to the top of the table in the same order (R-3, R-4, R-5, then R-1, R-2); the IDs and sections do not change.
