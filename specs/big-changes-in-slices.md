# A whole app or a big feature is built as slices, each its own change

**Go:** pending

## Intent

The owner (2026-10-27, in chat), on v2 as it stands:

> i thhink v2 works for feature requests and bug fixes, but whole app is not yet wired up? If
> requesting a whole app (or a big feature that would not fit into one spec) then we need to break
> it down into smaller chunks, record those somehow, and then do one by one (each one on a PR).
> […] One idea to consider: if whole app / big feature, after you get the intent understood but
> before you write the spec you flag this has to be split into multiple tasks, whcih ones those
> would be, that you will update the roadmap (perhaps confirm about the placement if there are
> items in there already) and then proceed with the spec of the first one, or something like that

On the record of the split (2026-10-28): "could we have the simpler entries as usual, but first
you know when you're slicing you show me and if I approve, given that I approve then you can add
them to the roadmap." On gstack's planning and design skills (2026-10-28, 2026-10-30): "there are
some skills from G Stack that apply to also this use case of the whole app when establishing the
initial spec files […] office hours and CEO […] review for design and for engineering"; "the
consultation we should include for sure […] let's keep it simple"; the shotgun: "look at the skill
and create our own version so that you can run it yourself […] think where in the flow it should
go". And (2026-10-30) the "DevShop UI tooling strategy" session's proposal is this session's to
carry from now on.

Today TARGET § L3 Intent 8 and the `intent` skill § 2 say only "too big? propose a split, one spec
each": nothing says where the split is recorded, how the next slice is picked, or how the slices
stay one product. The devshop builds itself that way by hand (milestone, epic, task lines in the
workstreams); a project has only `ROADMAP.md` and `specs/`.

## Decisions

- **A split step in `intent`, between sharpening and the spec.** A request that doesn't fit one
  change (a whole app, a feature that needs more than one PR to show working) stops before any
  spec: Claude says so and shows one screen: the whole in the owner's words, the slices in order,
  each one line, the first marked, what the whole leaves out, and where the slices sit among the
  roadmap's open entries. The owner's approval is a go on the shape and the order only; each slice
  still gets its own spec and its own go. Rejected: one big spec with phases (one spec is one
  change, one PR, one reviewer run); specs for every slice up front (the first slice's build
  changes the next spec; rolling wave, PROCESS § 1)
- **Recorded as ordinary roadmap entries, nothing new in the template's shape** (owner,
  2026-10-28). On approval, a records-only roadmap PR (the one "later" requests use, no spec) adds
  one `R-<n>` entry per slice, in the approved order, placed where the owner said. Each entry's
  section quotes the owner's original request and their approval of the split, and names the
  other slices' IDs. The slice's spec names its `R-<n>` in Intent, as any roadmap request does;
  the change that delivers it marks it `Done`. "What's next?" stays the top `Open` entry, so the
  next slice is picked by the existing rule. Rejected: a parent entry with child entries, or
  `R-<n>.<m>` IDs (owner: the simpler entries as usual); a plan file holding status (status lives
  on the roadmap row only, one source)
- **The whole, for a whole app only: one plan document under `docs/`,** written at the split step
  and linked from the docs map and from each slice's entry: the product in the owner's words, the
  core flow, the model, the slices and why they are in that order. It carries no status. gstack's
  `/office-hours` produces a design document; when it ran, that is the plan document. A big
  feature on an existing app gets no document beyond its slices. Never under `specs/`: the
  reviewer takes the one `specs/**.md` file a change adds as its spec, and a plan there breaks the
  review
- **How to slice: the walking skeleton first, then vertical slices.** The first slice is the
  thinnest path that deploys and shows one user-visible step; for a new repo that is
  `devshop:new-project` plus one screen. Later slices thicken it, each one shippable and visible
  to a user, never a layer ("the schema", "the API", "the UI"). A slice is the right size when its
  go fits one screen and its PR is one the owner can judge in a sitting. After each slice ships,
  the next one is re-read against what the build taught and the merged specs; only the next one or
  two carry detail. A change to the slices after the approval is the owner's decision, recorded in
  the entries it changes with their words and date, as a spec change after a go is (Intent 7)
- **The gstack planning reviews, named where they fit** (TARGET Intent 1 already says "the
  planning reviews that fit"; this names them): `/office-hours` first when the why, who or problem
  isn't settled, as now; `/plan-ceo-review` on the whole before slicing, since it questions scope
  and premise, which is what decides the slices; `/plan-eng-review` on the split and its order,
  since the skeleton is an architecture call. Each is proposed by Claude, run in the session, and
  its result goes into the split screen, never written to the project by the skill. Rejected on
  the default route: `/plan-design-review`, which generates mockups with gstack's OpenAI image
  binary and a board on 127.0.0.1 (neither runs in a cloud session, F-NEW-87) and edits the spec
  in its own voice; the owner can ask for it
- **The design direction is its own slice** for a project with a UI and no `DESIGN.md`: after the
  split is approved and before the first slice that renders a page. It runs gstack's
  `/design-consultation`, whose fallback path with no design binary writes an HTML preview with
  the real faces and palette, published as a page the owner can open, and ends in `DESIGN.md` on
  the owner's approval; its override list (no `CLAUDE.md` write, which product questions the
  builder answers from the plan document, the preview published instead of `open`) and the
  hand-built variants page go in a design guideline that the UI tooling strategy's first spec
  writes, not here. The `intent` skill carries one line pointing at it. Not with `/office-hours`:
  the consultation reads the settled product as its input and produces `DESIGN.md`, which the
  build's design review and the reviewer judge against. A big feature on an app that has
  `DESIGN.md` skips it. Closing F-NEW-79 is that guideline's, not this change's
- **No devshop version of `/design-shotgun` in this change.** What it needs OpenAI for (image
  variants, a vision check) is replaced by what worked on the website (F-NEW-87): hand-built HTML
  variants with the real tokens on one published page, the owner picks, the pick is recorded in
  `DESIGN.md`'s decisions log. That is a step of the design direction change, before build, as
  input to `DESIGN.md`, never per change by default (the UI tooling strategy's proposal, for the
  touchpoint budget); the owner can ask for variants of one screen while a UI slice is sharpened,
  and the pick then feeds the spec's core flow and states. Its home is the design guideline above
- **The `/spec` interview goes to features only** (D-19, 2026-10-20; F-NEW-122): a feature gets
  gstack's `/spec --file-only --no-gate` interview; a small change gets a one-paragraph spec and
  the go, no interview. Folded in because it edits the same lines of `intent` § 2 and shortens
  them. A slice is a feature unless it is plainly small
- **Size: `intent` comes back inside its one page** (60 lines, 600 words, `skills-check.py`;
  owner, 2026-10-14: a skill that outgrows it splits along a seam). It is at 72 lines and 723
  words today, a warning. The rules live where the devshop keeps rules: the entry's shape in the
  roadmap template's comment, the spec's link to its slice in the spec template's comment; the
  skill has the steps, a line each. If trimming can't get it inside the page, the seam is the
  owner's call, raised before the build goes on
- **Proof: a dry run on a made-up app in this session,** since the devshop's next whole app is not
  yet asked for. A read-only helper gets the rewritten skill and a synthetic request (a small
  web app for a made-up household, three or four features, `example.com` only) and produces the
  split screen and the roadmap entries it would write. Pass, fixed before the run: the first slice
  deploys and shows one user-visible step; every slice is vertical, one PR each; the design
  direction is a slice before the first page; the entries follow the template; nothing is specced
  before the approval. The request, the screen, the entries and the grading go in a spike record.
  The real check is the first whole app through v2, watched there, not an item here

## Acceptance items

- **AC-1** `runtime/skills/intent/SKILL.md` has the split step between sharpening and the spec:
  stop before any spec, the one screen's contents, the approval as a go on shape and order, the
  records-only roadmap PR with one entry per slice in the approved order, the plan document for a
  whole app under `docs/`, the slicing rule (skeleton first, vertical, one PR each, re-read after
  each slice), the named planning reviews, the design direction as its own slice pointing at the
  design guideline, and the interview for features only — verified by review: the diff
- **AC-2** `runtime/templates/roadmap.md`'s comment has the slice entry: an ordinary `R-<n>` row,
  its section quoting the request and the approval of the split and naming the other slices; and
  `runtime/templates/spec.md`'s Intent comment says a slice's spec names its `R-<n>` and links the
  plan document when there is one — verified by review: the diff
- **AC-3** `python3 scripts/skills-check.py runtime` prints no warning for `intent`, and the
  descriptions stay within their budget; `tests/skills-check.test.sh` passes
- **AC-4** The spike record under `kit/notes/revamp/spikes/` holds the dry run (the request, the
  screen, the entries, the grading fixed before the run) and it passes — verified by review: the
  record
- **AC-5** `docs/README.md` links the spike record and still passes `scripts/docs-map-check.py`;
  `FINDINGS.md` has no F-NEW-122 row; `kit/notes/revamp/LOG.md` has an entry — verified by review:
  the diff and CI on the PR's head

## Out of scope

- The design guideline (`runtime/guidelines/design.md`): the consultation's override list, the
  hand-built variants page, the surface rule, the UI definition of done, the forced `DESIGN.md`
  read in `build`. It is the UI tooling strategy's first spec, next after this one
- The rest of that strategy: impeccable's detector engine in the bootstrap, a `DESIGN.md` shape
  check in the fast tier, the Next.js home at M3; and its three open owner decisions, which come
  with that spec's go screen
- Parallel builders for slices (TARGET Build 1: one central agent; slices ship one at a time)
- Any change to `ROADMAP.md`'s table format, `spec-check.py` or `pr-body-check.py`
- The `pr` skill's size (also over its page); a separate change
