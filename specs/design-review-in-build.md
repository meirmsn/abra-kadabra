# Build runs a design review on every UI change before it ships

**Go:** pending

## Intent

R-5 on the roadmap (owner, 2026-10-16), task W10.10.8: "Build runs gstack's `/design-review` on the
preview for every UI change, judged against `DESIGN.md`, before `ship`; findings it reports are fixed
or go to the owner like the reviewer's". REVIEW-2 § M2, which the task comes from: "The build skill
tries gstack's `/design-review` on the preview for UI changes, and its value is judged by whether the
owner's look-and-feel comments on PRs drop." Today gstack's quality tools are installed by the
bootstrap and no skill uses them except `/spec` (REVIEW-2 § 2); the reviewer reviews UI by reading.

## Decisions

- **Where it runs: a local run of the change's branch, not the preview.** The project's preview is
  deployed by its PR workflow, and `ship.sh` is the only way to a PR, so before `ship` there is no
  preview to review: "on the preview" and "before `ship`" can't both hold. A local run keeps "before
  `ship`", so the owner never sees a PR that design review hasn't passed, and needs no preview host
  in the session's network allowlist. `/design-review`'s diff-aware mode is built for it (a feature
  branch, the app on a local port, only the pages the diff touches). Rejected: the preview after the
  first `ship` (the owner is told about a PR that a second round then changes); a preview deployed
  on every branch push (a workflow change in every project, and the preview token on pushes that are
  not PRs). The preview stays the owner's to look at (proposed, 2026-10-17; the owner's call)
- **What counts as a UI change:** a change whose spec has a Core flow (the spec template asks UI
  changes for one), or a bug fix that changes what a page renders. A change to code no page renders
  skips it, and the PR body says nothing about it
- **How it runs:** after the change is built and its tests pass, before `devshop:pr`: start the app
  locally the way the project's `CLAUDE.md` or stack home says, then `/design-review` on that URL,
  which reads the project's `DESIGN.md` itself and calibrates to it. Its fix loop runs: its fixes
  are commits on the change's branch by the same session, the only writer. A fix that would change a
  spec decision or acceptance item is not made: it goes to the owner as a spec change (`intent`
  step 5)
- **Its findings, like the reviewer's:** each one it fixes is fixed in the branch; each one it defers
  becomes a row in the project's `FINDINGS.md` (its severity mapped to the template's high, med,
  low) or a sighting on the row it matches, in the same records-only commit as the reviewer's low
  findings; `devshop:pr` § 3 then asks the owner "roadmap or keep watching?" for the med and high
  ones, as it already does. Its `TODOS.md` step (Phase 11) is skipped: `FINDINGS.md` is the record
- **What the owner sees:** one line under the PR's Evidence: the design score before and after, how
  many findings it fixed and how many it logged, for the commit it reviewed. The template marks the
  line as for UI changes only, and `pr-body-check.py` doesn't require it; rejected: a required label
  (every PR without UI would carry it, and a check change needs its own failing tests and mutants
  for a line the reviewer already reads). The reviewer's design/QA lens stays as it is (W10.10.4
  gives it a browser later)
- **When it can't run** (no browser, the app won't start locally, the skill errors): build doesn't
  skip it in silence. The Evidence line says "could not run" and why, and the owner is told in chat
  with the PR's link. It is feedback, not a wall (CLAUDE.md, Walls vs feedback): it doesn't block
  `ship`, CI and the owner's approval do
- **The proof, before the merge:** in this session, a scratch site made from the devshop's UI
  baseline (`runtime/templates/ui/`) with a `DESIGN.md`, served on a local port, on a scratch
  feature branch. Two runs of `/design-review` as the build skill words it: a page with three
  planted breaks of its `DESIGN.md` (a font it doesn't name, a spacing value off its scale, a layout
  that overflows at 375 px), and the honest page. Pass: the planted run reports all three and its
  fix loop fixes them; the honest run reports no departure from `DESIGN.md`. Prompts, reports and
  grading go in `kit/notes/revamp/spikes/w10-10-8-design-review/`. Grading is fixed before the runs
  and not changed after. Rejected: proving it on the website repo (out of this session's scope) and
  a CI test (CI stays plain, no agentic jobs; TARGET Verify 3)
- **After the merge:** its value is judged as REVIEW-2 said: whether the owner's look-and-feel
  comments on the website's PRs drop. That is watched on the next UI changes, not an item here
- The build skill is at 54 lines and 508 words of its one-page cap (60 and 600, a warning only,
  `scripts/skills-check.py`): the step is one bullet of at most four lines

## Acceptance items

- **AC-1** `runtime/skills/build/SKILL.md` has the step: for a UI change, after the tests pass and
  before `devshop:pr`, `/design-review` on a local run against `DESIGN.md`; its fixes in the branch,
  a fix that changes the spec raised with the owner, its deferred findings in `FINDINGS.md` like the
  reviewer's, its `TODOS.md` step skipped, and a run that can't happen reported, not skipped —
  verified by review: the diff
- **AC-2** `runtime/skills/pr/SKILL.md` and `runtime/templates/pr-body.md` carry the design review's
  Evidence line for UI changes only (score before and after, fixed, logged, the commit; or "could
  not run" and why), `runtime/scripts/pr-body-check.py` is unchanged, and `devshop:pr` § 3 counts
  design-review findings with the reviewer's — verified by review: the diff
- **AC-3** `tests/skills-check.test.sh` and `tests/pr-body-check.test.sh` pass with the change —
  verified by review: CI on the PR's head
- **AC-4** The spike record holds both runs (prompt, report verbatim, the grading fixed before the
  runs), and they pass it: the planted run reports and fixes all three breaks, the honest run reports
  no departure from `DESIGN.md` — verified by review: the spike record
- **AC-5** `kit/notes/revamp/workstreams/W10-v2.md` marks W10.10.8 `[x]` with this PR, `ROADMAP.md`
  marks R-5 `Done`, and `kit/notes/revamp/LOG.md` has an entry for it — verified by review: the diff

## Out of scope

- The reviewer's browser and its design/QA lens (W10.10.4, R-6)
- A design review on the deployed preview, and any change to a project's preview workflow
- Native apps: gstack's on-device design review comes with the iOS stack (M4)
- `/design-consultation` and `/design-shotgun` (a project's first design direction, W10.10.1)
- A CI job or check script for design quality: the quality bar (Lighthouse, axe-core, the render
  and token checks) is already the deterministic part
