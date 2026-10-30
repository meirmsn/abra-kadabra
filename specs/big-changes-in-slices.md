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

On the record of the split (2026-10-28): "Do we need the parent and child entry form or could we
have the simpler entries as usual, but first you know when you're slicing you show me and if I
approve, given that I approve then you can add them to the roadmap." On gstack's planning and
design skills (2026-10-28): "there are some skills from G Stack that apply to also this use case of
the whole app when establishing the initial spec files for the strategy from office hours and CEO,
I think, review for design and for engineering. the design, there's the design consultation and
shotgun skills […] I wonder if we should also be you know figuring that out as well in this change,
or if we should do in a separate session after this is done, I don't know. What do you think?" And
(2026-10-30): "the consultation we should include for sure. It seems like it's a skill and we can
include it. So we just need to figure out where it makes sense, and let's keep it simple. […] Maybe
goes together with office hours. Is that what the recommendation is? […] And the shotgun, you're
saying that the way it works is that it goes to OpenAI […] So maybe what we should do is just look
at the skill and create our own version so that you can run it yourself. Does that make sense? And
also think where in the flow it should go." Then "ok go" to this spec, and: "i will not touch the
devshop UI tooling strategy, from now you to take care of it right?" (the session of 2026-10-26
whose proposal is now this session's to carry).

Today TARGET § L3 Intent 8 and the `intent` skill § 2 say only "too big? propose a split, one spec
each": nothing says where the split is recorded, how the next slice is picked, or how the slices
stay one product. The devshop builds itself that way by hand (milestone, epic, task lines in the
workstreams); a project has only `ROADMAP.md` and `specs/`.

## Decisions

- **A split step between sharpening and the spec, in a skill of its own, `devshop:split`.** A
  request too big for one change (a whole app, or a feature no one PR could show working) stops
  before any spec: `intent` § 2 hands over to `split`, as it hands set-up to `new-project`. The
  seam is forced by size: `intent` is at 72 lines and 723 words against its one-page cap (60 and
  600, `scripts/skills-check.py`, a warning since D-17 item 4; a skill that outgrows it splits
  along a seam, owner, 2026-10-14, TARGET Shape 2), and a compact rewrite with the split step inside
  came to 71 lines and 780 words. With the step out and § 3–5 tightened (rules the spec template's
  comments already hold are not repeated), `intent` fits the page; `split` is about 25 lines; the
  descriptions stay within their 200-word budget (150 used). Rejected: keep it in `intent` and
  accept the warning (against the owner's seam rule); one big spec with phases (one spec is one
  change, one PR, one reviewer run); specs for every slice up front (the first slice's build
  changes the next spec; rolling wave, PROCESS § 1)
- **The screen, and the approval as a go on shape and order only.** `split` shows one screen: the
  whole in the owner's words; the slices in order, one line each; what the whole leaves out; where
  the block of slices sits among the roadmap's `Open` entries (the slices stay consecutive; the
  owner says where the block goes, and may reorder). The owner's approval is a go on the shape and
  the order; each slice still gets its own spec and its own go. Nothing is specced before it
- **Recorded as ordinary roadmap entries, nothing new in the template's shape** (owner,
  2026-10-28). On approval, one PR adds one `R-<n>` entry per slice, in the approved order, where
  the owner said, and nothing else but the plan document below: its body says the split's screen
  was approved. Each entry's section quotes the owner's original request and their approval of the
  split, word for word, and names the other slices' IDs; the roadmap template's comment carries
  this slice rule. That quoted approval is the owner's go for the entry: the reviewer's `intent`
  lens fails a choice recorded without a spec, and a slice line is Claude's wording, so the PR body
  and each section name the approval. Whether the reviewer accepts that is shown by the first real
  split, not here; if it doesn't, the reviewer's prompt gets a sentence in its own change (with the
  eval, CLAUDE.md). Then the first slice's spec starts at once, on its own branch, naming its
  `R-<n>` (the number re-checked against `main` at ship, as the roadmap rule says); the change
  that delivers a slice marks it `Done`; "what's next?" stays the top `Open` entry, so later
  sessions pick the next slice by the existing rule. A slice's detail beyond its line lives under
  its section's "Claude's notes" heading, or in the plan document. Rejected: a parent entry with
  child entries, or `R-<n>.<m>` IDs (owner: the simpler entries as usual); a plan file holding
  status (status lives on the roadmap row only, one source); the entries riding the first slice's
  PR (the owner's order: the roadmap first, then the first spec)
- **The whole, for a whole app only: one plan document under `docs/`,** written by Claude at the
  split step from the office-hours and plan-review results, carried by the roadmap PR, linked from
  each slice's entry and from the project's docs map when it has one (`docs/README.md` is optional
  in the contract): the product in the owner's words, the core flow, the model, the slices and why
  in that order. It carries no status. A big feature on an existing app gets no document: its
  whole is quoted in each slice's entry and spec. Never under `specs/`: the reviewer takes the one
  `specs/**.md` file a change adds as its spec, and a plan there breaks the review
- **How to slice: the walking skeleton first, then vertical slices.** The first slice is the
  thinnest path that deploys and shows one end-to-end step a user can exercise (a page, or a call
  for an app with no UI). In a new repo, `devshop:new-project` comes first and is not a slice: it
  is set-up with no spec, held unmerged until the owner's part 2; the split screen can follow in
  the same session, and the roadmap PR and the first slice follow its merge; the stack's owner
  set-up steps are part of the first slice's go. Later slices thicken the skeleton, each shippable
  and visible to a user, each one PR the owner can judge in a sitting, never a layer ("the
  schema", "the API", "the UI"). After each slice ships, the next is re-read against what the
  build taught and the merged specs; only the next one or two carry detail. A change to the slices
  after the approval is the owner's decision, recorded on the entries it changes with their words
  and date, as a spec change after a go is (Intent 7)
- **A UI with no `DESIGN.md`: the design direction is the second slice,** after the skeleton and
  before any slice that styles a page beyond the baseline. The skeleton ships on the UI baseline
  from `runtime/templates/ui/` (build's design review already skips with no `DESIGN.md`,
  `ui.md` § Design review), which gives the project a preview to publish the direction's pages
  on. The direction runs gstack's `/design-consultation` under an override list in a new
  `runtime/guidelines/ui.md` § Design direction, as § Design review has one: no `CLAUDE.md` write
  (the project's own); product questions answered from the plan document, the owner answers the
  memorable-thing question and the picks; no Codex or other outside voice and no learnings from
  other projects; its HTML preview (the fallback path with no design binary, which writes one
  self-contained page with the real faces and palette and then runs `open`) published as a page
  the owner can open instead; then two or three hand-built HTML variants with the real tokens on
  one published page, the owner picks, the pick is recorded in `DESIGN.md`'s decisions log;
  `DESIGN.md` in the format the consultation writes, its tokens and the theme CSS under the
  baseline's names (`tokens-check.mjs` and the reviewer read those); fonts self-hosted as the
  stack home says. `DESIGN.md` and the theme CSS land in that slice's PR; its spec records
  `DESIGN.md` as the decision, since the reviewer judges a change that adds it against the head's.
  Not with `/office-hours`: the consultation reads the settled product as its input and produces
  `DESIGN.md`, which the build's design review and the reviewer judge against. A big feature on an
  app with `DESIGN.md` skips it. F-NEW-79 gets a sighting note (the route now exists; the row
  closes when the guideline is proven on a real project)
- **No devshop skill for `/design-shotgun` beyond the variants step above.** What gstack needs
  OpenAI for (image variants, a vision check) is replaced by what worked on the website
  (F-NEW-87): hand-built HTML variants, a published page, the owner's pick. It sits in the design
  direction slice, before build, as input to `DESIGN.md`, never per change by default (the UI
  tooling strategy's proposal, for the touchpoint budget: waiting on the owner is most of a
  change's elapsed time, REVIEW-3 § 5); the owner can ask for variants of one screen while a UI
  slice is sharpened, and the pick then feeds that spec's core flow and states. The strategy's
  fuller guideline (the surface rule, the UI definition of done, the forced `DESIGN.md` read in
  `build`) is its own change after this one
- **The gstack planning reviews, named where they fit** (TARGET Intent 1 already says "the
  planning reviews that fit"): `/office-hours` first when the why, who or problem isn't settled, as
  now; `/plan-ceo-review` on the whole before slicing, since it questions scope and premise, which
  is what decides the slices; `/plan-eng-review` on the split and its order, since the skeleton is
  an architecture call. Each is proposed by Claude and run on a copy of the repo outside it:
  office-hours writes its document to `docs/designs/` and both plan reviews append their report
  to the plan file they are given, so nothing they write lands in the project; their results are
  inputs to the screen and the plan document. Rejected on the default route: `/plan-design-review`
  (it edits the plan in its own voice, and its mockup path wants gstack's OpenAI image binary and a
  board on 127.0.0.1; its text-only mode runs); the owner can ask for it
- **The `/spec` interview goes to features only** (REVIEW-3 § 4 via D-19, 2026-10-20; F-NEW-122):
  a feature gets gstack's `/spec --file-only --no-gate` interview; a small change (one screen or
  one rule, no new model) gets a one-paragraph spec and the go, no interview; a slice the plan
  document already details gets no interview either, since the questions are answered there.
  Folded in because it edits the same lines of `intent` § 2 and shortens them
- **Proof: a dry run on a made-up app in this session,** since the devshop's next whole app is not
  yet asked for; the real check is the first whole app through v2, watched there. A read-only
  helper gets a scratch project (a `ROADMAP.md` from the template holding two `Open` entries, no
  `DESIGN.md`, `example.com` only) and a synthetic request (a small web app for a made-up
  household, three or four features), once with the current `intent` § 2 line as the control and
  once with the new `split` skill. The grading is committed before the outputs, in that order:
  the first slice deploys and shows one user-visible step; every slice is vertical and one PR; the
  design direction is the second slice; the entries parse as the template says (consecutive IDs,
  each naming the others, the approved order, the quotes); the screen says what the whole leaves
  out and where the block sits; nothing is specced before the approval. Pass: the `split` run
  meets every line and the control misses at least one. A spike record holds the request, both
  outputs, the grading and the result; no spec files in it (the spec check and the reviewer glob
  `specs/**`)
- **TARGET is rewritten where it describes the old limitation** (Shape 9): Intent 1's "the
  `intent` skill still interviews every change until that is changed" and Intent 8's one line,
  each with the date and this spec

## Acceptance items

- **AC-1** `runtime/skills/split/SKILL.md` exists with the step: stop before any spec, the planning
  reviews run on a copy outside the repo, the screen's contents, the approval as a go on shape and
  order, the roadmap PR with one entry per slice in the approved order and the plan document for a
  whole app, the slicing rule (skeleton first, vertical, one PR each, the design direction second
  for a UI with no `DESIGN.md`, re-read after each slice), then the first slice's spec; and
  `runtime/skills/intent/SKILL.md` hands over to it from § 2, gives the interview to features only
  with the small-change and plan-document exceptions, and keeps its kinds, spec, review and go
  steps — verified by review: the diff
- **AC-2** `python3 scripts/skills-check.py runtime` prints no warning for `intent` or `split` and
  no problem, and `tests/skills-check.test.sh` passes
- **AC-3** `runtime/templates/roadmap.md`'s comment has the slice rule (an ordinary `R-<n>` row;
  its section quoting the request and the approval of the split and naming the other slices; the
  block consecutive, where the owner said), and `runtime/templates/spec.md` gains an Intent
  comment saying a slice's spec names its `R-<n>` and links the plan document when there is one
  — verified by review: the diff
- **AC-4** `runtime/guidelines/ui.md` gains § Design direction with the override list in Decisions
  (no `CLAUDE.md` write, which questions the builder answers, no outside voices or cross-project
  learnings, the preview and the variants published as a page, the pick recorded, the tokens and
  theme CSS under the baseline's names, fonts as the stack home says, `DESIGN.md` as the slice's
  recorded decision) — verified by review: the diff
- **AC-5** The spike record under `kit/notes/revamp/spikes/` holds the dry run (the request, the
  control and `split` outputs, the grading committed before them, the result), and the `split` run
  passes every grading line while the control misses at least one — verified by review: the
  record and its commits' order
- **AC-6** `docs/README.md` links the `split` skill and the spike record and passes
  `scripts/docs-map-check.py`; `kit/notes/revamp/TARGET.md` Intent 1 and 8 carry the dated change;
  `FINDINGS.md` has no F-NEW-122 row and F-NEW-79 has the sighting note; `kit/notes/revamp/LOG.md`
  has an entry — verified by review: the diff and CI on the PR's head

## Out of scope

- The rest of the UI tooling strategy: the fuller design guideline (the surface rule, the UI
  definition of done, the forced `DESIGN.md` read in `build`, the `CLAUDE.md` starter line),
  impeccable's detector engine in the bootstrap, a `DESIGN.md` shape check in the fast tier, the
  Next.js home at M3, and its three open owner decisions (the engine, the surface rule, shadcn/ui
  as the React default)
- A change to the reviewer's prompt for the split's roadmap PR; made only if the first real split
  shows the need
- Parallel builders for slices (TARGET Build 1: one central agent; slices ship one at a time)
- Any change to `ROADMAP.md`'s table format, `spec-check.py`, `pr-body-check.py` or
  `skills-check.py`
- The `pr` skill's size (also over its page); a separate change
