# Build runs a design review on every UI change before it ships

**Go:** "1. A 2. A 3. A", the answers to the three open calls on the go screen (owner, 2026-10-17)

## Intent

R-5 on the roadmap (owner, 2026-10-16), task W10.10.8: "Build runs gstack's `/design-review` on the
preview for every UI change, judged against `DESIGN.md`, before `ship`; findings it reports are fixed
or go to the owner like the reviewer's". REVIEW-2 § M2, which the task comes from: "The build skill
tries gstack's `/design-review` on the preview for UI changes, and its value is judged by whether the
owner's look-and-feel comments on PRs drop." Today gstack's quality tools are installed by the
bootstrap and no skill uses them except `/spec` (REVIEW-2 § 2); the reviewer reviews UI by reading.

## Decisions

- **Where it runs: a local run of the change's branch** ("1. A", owner, 2026-10-17). The
  project's preview deploys from its PR workflow, and `ship.sh` is the only way to a PR, so before
  the first `ship` there is no preview: "on the preview" and "before `ship`" can't both hold. A local
  run keeps "before `ship`": the PR is created ready, so the owner is notified only after design
  review, and a design fix doesn't cost a second full reviewer round (about 10 minutes each). It is
  the builder's own check; R-6 (W10.10.4) is the independent reviewer browsing, a different actor.
  Rejected: the preview after the first `ship`, before telling the owner (the owner gets GitHub's
  notice of a ready PR first, and every fix is a full review round); a preview on every branch push
  (a workflow change in every project)
- **The browser:** gstack's browser doesn't start in a cloud session as installed (F-NEW-87): the
  bootstrap installs gstack with `--no-browser`, and the Chromium its pinned Playwright wants isn't
  in the image, whose network blocks the download. Probed in this session: its own check prints
  `BROWSER_UNAVAILABLE` (wants `chromium_headless_shell-1234`; the image has `-1194`); with
  `GSTACK_CHROMIUM_PATH=/opt/pw-browsers/chromium`, `browse goto` loads a local page. So the
  bootstrap's gstack step, when the image has that Chromium, sets that variable for the session's
  shells; without it, design review can't run and says so. Rejected: downloading gstack's Chromium
  (blocked, ~115 MiB per session) (proposed, 2026-10-17)
- **What counts as a UI change:** one that changes what a page renders (markup, styles, scripts a
  page loads, its assets), whether or not the spec has a Core flow. Anything else skips it, and the
  PR says nothing about it. A project with no `DESIGN.md` doesn't run it either: the Evidence line
  says so (F-NEW-79 is the route to one)
- **How it runs** (the step in `build` § 3, the detail in `runtime/guidelines/ui.md` § Design
  review): after the change is built and its tests pass, with the tree committed, start the app
  locally as the project's `CLAUDE.md` or stack home says, and run `/design-review` with that URL
  and its scope set to the pages the change touches. Not gstack's diff-aware mode: that needs no URL
  and looks only on ports 3000, 4000 and 8080. gstack's questions don't go to the owner; they are
  answered as the guideline lists: no test framework bootstrap and no `CLAUDE.md` or `TESTING.md`
  edits (the project's CI is its tests), no `DESIGN.md` written, no `TODOS.md` step, no Codex or
  other outside voice (the project's code stays in the session), no cross-project learnings. The
  bootstrap sets the gstack preferences it can (`cross_project_learnings false`)
  Found by the proof's first round, after the go, and within this decision (its questions don't go
  to the owner): gstack's browser check ignores `GSTACK_CHROMIUM_PATH` and prints `NEEDS_SETUP`,
  whose wording asks to run gstack's setup; the guideline says to drive `$B` directly and never run
  the setup or ask. A mitigation; the cause is that check in the pinned gstack (F-NEW-100)
- **Its fixes: only what the change built** ("2. A", owner, 2026-10-17). Findings on the
  pages and lines the change touches are fixed under `build` § 3's rules (commit subjects that
  describe the change, tests edited when behaviour changes), not gstack's own commit format. The
  rest is logged, not fixed, as `build` § 3 says for anything the change doesn't need. A fix that
  would change a spec decision or acceptance item goes to the owner (`intent` step 5). After its
  fixes, the new and affected tests and the fast checks run again. Rejected: gstack's whole fix
  loop (it fixes every finding, polish and other pages included, which the reviewer's spec lens
  would fail as added scope)
- **Its findings, like the reviewer's:** gstack's High is a blocker like the reviewer's med and high:
  fixed before `ship`, or, when it can't be (outside the change, or a spec change), a `med` row
  raised with the owner. Its Medium left unfixed is a `med` row and Polish a `low` row in the
  project's `FINDINGS.md` (or a sighting on the row it matches). The rows are committed before
  `ship`, so the reviewer sees them; `devshop:pr` § 3 asks "roadmap or keep watching?" for the
  `med` ones, as it does today
- **What the owner sees:** one line under the PR's Evidence, for UI changes only: design score and
  AI-slop score before → after, findings fixed and logged, and the commit it reviewed; or why it
  didn't run. It runs again on any later round that changes what a page renders, and the line is
  rewritten for the new head. `pr-body-check.py` doesn't require it; rejected: a required label (a
  check change with its own failing tests and mutants, for a line the reviewer already reads)
- **When it can't run** (no browser, the app won't start locally, the skill errors): not skipped in
  silence: the Evidence line says why, and the owner hears it with the PR's link. It is feedback,
  not a wall (CLAUDE.md, Walls vs feedback): CI and the owner's approval stay the walls
- **The proof: a scratch site in this session, and the website's next UI change after the merge**
  ("3. A", owner, 2026-10-17). A local git repo made from `runtime/templates/ui/` with a
  `DESIGN.md` in gstack's spec format, served on a local port, on a feature branch. Two runs of
  `/design-review` as the guideline words them, in a shell started fresh with the bootstrap's
  setting: a change with three planted breaks of `DESIGN.md` (a font it doesn't name, a spacing
  value off its scale, a colour outside its palette; not a 375 px overflow, which the render check
  already catches), and an honest change. Pass, fixed before the runs: the planted run names all
  three as departures from `DESIGN.md` and fixes them in the branch; the honest run reports no
  departure from `DESIGN.md` and commits no fix to its values; neither run asks a question or
  writes a file the guideline rules out. Prompts, reports verbatim and grading go in
  [the spike record](../kit/notes/revamp/spikes/w10-10-8-design-review/README.md). The gap, stated: this is not the website's own
  environment; its first UI change after the merge is the live check, and its PR's Evidence line is
  recorded on W10.10.8. Rejected: a CI test (CI stays plain, no agentic jobs; TARGET Verify 3)
- **After the merge:** its value is judged as REVIEW-2 said: whether the owner's look-and-feel
  comments on the website's PRs drop. Watched on the next UI changes, not an item here
- Size: the build skill is at 54 lines and 508 words of its one-page cap (60 and 600, a warning
  only); its step is one bullet, the detail goes in the UI guideline. The pr skill is already over
  its cap (72 lines, 771 words): its change is a few words in an existing bullet

## Acceptance items

- **AC-1** `runtime/skills/build/SKILL.md` § 3 has the step, pointing at the guideline: for a change
  that changes what a page renders, after its tests pass and before `devshop:pr` — verified by
  review: the diff
- **AC-2** `runtime/guidelines/ui.md` § Design review says: the local run, the URL and scope, no run
  without `DESIGN.md`, each gstack override listed in Decisions, fixes limited to what the change
  built under `build` § 3's rules, the tests and fast checks run again, the severity mapping, rows
  committed before `ship`, the re-run on later rounds, and "could not run" reported — verified by
  review: the diff
- **AC-3** `runtime/templates/pr-body.md` and `runtime/skills/pr/SKILL.md` carry the Evidence line
  (UI changes only), `runtime/scripts/pr-body-check.py` is unchanged, and
  `tests/pr-body-check.test.sh` still passes — verified by review: the diff and CI on the PR's head
- **AC-4** `install/bootstrap.sh` sets `GSTACK_CHROMIUM_PATH` for the session's shells when the
  image has `/opt/pw-browsers/chromium`, sets `cross_project_learnings` to false, and does neither
  when it can't; `tests/bootstrap.test.sh` fails without the change and passes with it
- **AC-5** The spike record holds both runs (prompt, report verbatim, the grading fixed before the
  runs), and they pass it — verified by review: the spike record
- **AC-6** `kit/notes/revamp/workstreams/W10-v2.md` W10.10.8 and `ROADMAP.md` R-5 carry the owner's
  answer on where it runs; W10.10.8 is `[x]` with the post-merge check named and R-5 `Done`;
  F-NEW-87's browser part is updated; `kit/notes/revamp/LOG.md` has an entry — verified by review:
  the diff

## Out of scope

- The reviewer's browser and its design/QA lens (W10.10.4, R-6)
- A design review on the deployed preview, and any change to a project's preview workflow
- Native apps: gstack's on-device design review comes with the iOS stack (M4)
- `/design-consultation` and `/design-shotgun`, and the rest of F-NEW-87 (the OpenAI key, the
  comparison board on 127.0.0.1)
- A CI job or check script for design quality: the quality bar (Lighthouse, axe-core, the render
  and token checks) is the deterministic part
