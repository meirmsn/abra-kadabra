# Control run 1 (old `intent` § 2 wording), verbatim

_Set-up flaw, found after the run: the scratch `ROADMAP.md`'s comment was the roadmap template as
changed by this PR, so this run could read the new slice rule. Its entries' shape (grading line 6)
is therefore not evidence; a second control run uses the template as on `main` (the README)._

**(1) What I would say to the owner**

Thanks, that is a clear picture. Before anything gets built, here is where I am and what I propose.

**What this is.** A new product, not a feature: there is no app yet, so the why and who are not settled anywhere but in your sentence. The devshop has me propose gstack's `/office-hours` first for that. I expect it to be short, because you have already named the users (the four Example members) and the parts, but it would settle the things the specs will otherwise have to guess at: what the one thing is that the app must do well on day one (I'd guess: add to the list from a phone in two taps), whether a member ever acts for the household versus only for themselves, and whether the meal plan is the reason for the app or a nice-to-have on top of the list. Say "office hours" and I'll run it now, or "skip it" and I'll go straight to the split below with those as questions in the first spec interview.

**It is too big for one change.** Four features, a sign-in and a responsive two-theme shell is several PRs' worth, and each piece is testable on its own. I propose this split, one spec each, in this order:

1. **Sign-in and the shell.** The four members, sign-in and sign-out, and the empty app frame: responsive layout, light and dark. Nothing to do yet once signed in, but every later slice stands on it. (Your open R-2, "show who is signed in in the header", lands naturally here or right after; I'd fold it into this slice's spec unless you want it kept separate.)
2. **The shared shopping list.** One list for the household; any signed-in member adds, edits, ticks off, from a phone. This is the first slice that is useful on its own.
3. **The pantry.** What the household has at home. An item ticked off on the list moves into the pantry; a member can mark pantry items used up, which can put them back on the list.
4. **The weekly meal plan.** A week of meals, each meal with its ingredients; planning a meal puts its ingredients on the shopping list, skipping what the pantry already holds.

Each slice is one spec, one build, one PR; the one after it starts when the one before is in. If you would rather see the list before sign-in (a link anyone can open, members added later), say so and I'll swap 1 and 2, though "any member can add" reads to me as wanting to know who added what.

**One question about order on the roadmap.** R-1 (privacy page in the footer) and R-2 (who is signed in, in the header) are open and ahead of this, but both need an app to live in. Should the slices go above them, or do you want R-1 and R-2 done right after slice 1? The roadmap is your order; I won't move R-1 or R-2 myself.

**What happens next, once you approve the split.** I write nothing until you answer. On your "go" for the split I add the slices to ROADMAP.md as ordinary entries quoting your request and your approval, then start the `/spec --file-only --no-gate` interview for slice 1 (sign-in and shell) with you, stopping before it files an issue; the spec file is the record. After that I run the plan reviews that fit, which for a slice with this much UI means the engineering review and the design review. The stack is not chosen yet; if a choice in the spec comes to rest on how some tool or version behaves (say, which auth library handles four fixed accounts without a mail server), I'll prove it with a quick experiment before we commit to it rather than assume.

So: office hours first, or skip? And does the four-slice split and its order suit you, and where does it sit relative to R-1 and R-2?

**(2) Files**

Before the owner answers: nothing. No file is written or changed.

After the owner approves the split, ROADMAP.md gets four rows and four sections. Placed at the bottom unless the owner says where (the question above); shown here at the bottom, after R-2. The owner's approval is quoted word for word in each section, so the fenced block that holds it cannot be filled until they give it; it is marked below.

Rows added to the table:

```text
| R-3 | 2026-10-30 | Household app, slice 1 of 4: sign-in for the four members and the responsive light/dark shell | Open   |
| R-4 | 2026-10-30 | Household app, slice 2 of 4: the shared shopping list any member adds to from their phone     | Open   |
| R-5 | 2026-10-30 | Household app, slice 3 of 4: the pantry, ticking items off the list when bought                | Open   |
| R-6 | 2026-10-30 | Household app, slice 4 of 4: the weekly meal plan that puts ingredients on the list            | Open   |
```

Sections added after the R-2 section:

````markdown
## R-3: Household app, slice 1 of 4: sign-in for the four members and the responsive light/dark shell

Asked 2026-10-30, in chat (the whole request; slices R-3 to R-6 deliver it):

```text
A small web app for a made-up household, the Example family at example.com: a shared shopping
list that any member can add to from their phone, with a weekly plan of meals that puts its
ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four
members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop
(its first PR is up); the roadmap already holds two open entries.
```

Split approved 2026-10-30, in chat:

```text
[the owner's approval, word for word]
```

The other slices: R-4, R-5, R-6.

### Claude's notes

The four members of the Example family at example.com can sign in and out. The empty app frame:
responsive layout, light and dark themes. Nothing to do once signed in; R-4 adds the first
feature. R-2 (who is signed in, in the header) belongs to this shell; its spec says whether it
is folded in.

## R-4: Household app, slice 2 of 4: the shared shopping list any member adds to from their phone

Asked 2026-10-30, in chat (the whole request; slices R-3 to R-6 deliver it):

```text
A small web app for a made-up household, the Example family at example.com: a shared shopping
list that any member can add to from their phone, with a weekly plan of meals that puts its
ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four
members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop
(its first PR is up); the roadmap already holds two open entries.
```

Split approved 2026-10-30, in chat:

```text
[the owner's approval, word for word]
```

The other slices: R-3, R-5, R-6.

### Claude's notes

One list for the household. Any signed-in member adds, edits and ticks off items, from a phone.
Needs R-3. The first slice that is useful on its own.

## R-5: Household app, slice 3 of 4: the pantry, ticking items off the list when bought

Asked 2026-10-30, in chat (the whole request; slices R-3 to R-6 deliver it):

```text
A small web app for a made-up household, the Example family at example.com: a shared shopping
list that any member can add to from their phone, with a weekly plan of meals that puts its
ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four
members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop
(its first PR is up); the roadmap already holds two open entries.
```

Split approved 2026-10-30, in chat:

```text
[the owner's approval, word for word]
```

The other slices: R-3, R-4, R-6.

### Claude's notes

What the household has at home. An item ticked off on the list (R-4) moves into the pantry; a
member marks pantry items used up, which puts them back on the list. Needs R-4.

## R-6: Household app, slice 4 of 4: the weekly meal plan that puts ingredients on the list

Asked 2026-10-30, in chat (the whole request; slices R-3 to R-6 deliver it):

```text
A small web app for a made-up household, the Example family at example.com: a shared shopping
list that any member can add to from their phone, with a weekly plan of meals that puts its
ingredients on the list, a pantry that ticks items off when bought, and sign-in for the four
members. Responsive, light and dark. No app exists yet: the repo was just set up with the devshop
(its first PR is up); the roadmap already holds two open entries.
```

Split approved 2026-10-30, in chat:

```text
[the owner's approval, word for word]
```

The other slices: R-3, R-4, R-5.

### Claude's notes

A week of meals, each with its ingredients. Planning a meal puts its ingredients on the shopping
list (R-4), skipping what the pantry (R-5) already holds. Needs R-5.
````

If the owner answers that the slices go before R-1 and R-2, the four rows move to the top of the table as one consecutive block, in the same order; the sections' content does not change. The spec for slice 1 (`specs/`, named by the `/spec` interview) is written only through that interview, after the go, and names R-3; no content for it exists yet.
