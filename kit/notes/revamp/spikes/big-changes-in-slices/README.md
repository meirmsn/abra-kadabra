# The split dry run: a made-up app through the old wording and the new `split` skill

[Spec](../../../../../specs/big-changes-in-slices.md), its proof decision. The devshop's next whole
app is not yet asked for, so the new skill is tried on a synthetic request before the first real
one, which is the real check. One run per wording, a read-only helper each; the grading below is
committed before either output (the commits' order is the record).

## Set-up (fixed before any run, 2026-10-30)

- **The scratch project** at `<scratch>` (a directory outside the repo, no git): `README.md` (a new
  project, first PR up, no app), `specs/` empty, and [`scratch-ROADMAP.md`](scratch-ROADMAP.md)
  as its `ROADMAP.md`: the roadmap template's comment plus two `Open` entries, R-1 and R-2. No
  `DESIGN.md`. Synthetic throughout (`example.com`, the Example family).
- **The request:** a small household web app with four features (a shared shopping list, a weekly
  meal plan that feeds it, a pantry, sign-in for four members), responsive, light and dark; the
  repo just set up, two roadmap entries open. Quoted in full in both prompts.
- **Prompts,** built by a script from `origin/main` and the working tree, never retyped:
  [control](prompts/control.md) carries `intent` § 2 as it is on `main` before this change ("Too
  big for one change? Propose a split, one spec each"); [split](prompts/split.md) carries the new
  `split` skill's body. Both ask for (1) what the helper would say to the owner now and (2) any
  file it would write before the owner answers, and the roadmap entries it would write after the
  approval, in full.
- **Helper:** a fresh `Plan` agent per run (read-only; it can't edit), given one prompt file and
  the scratch path. Each output is saved verbatim under `outputs/`.

## Grading rule (fixed before the runs)

A run **passes** only when every line holds; each line is judged on the output's literal text.

1. **Nothing specced before the approval:** no spec file content is proposed before the owner
   answers; the owner is asked to approve a split.
2. **The skeleton first:** the first slice deploys and shows one end-to-end step a user can
   exercise (a page a member can open on the deployed app), not a layer.
3. **Vertical, one PR each:** every slice is named as one change or PR and shows something a user
   can see or do; none is "the schema", "the API", "the data model" or "the UI" alone.
4. **The design direction is the second slice,** before any slice that styles a page.
5. **The screen says what the whole leaves out** and **where the block sits** among R-1 and R-2.
6. **The entries follow the template:** `R-3` onward, consecutive, in the approved order; each
   section quotes the request and names the other slices; the approval is quoted or its place is
   marked for the owner's words.

**Pass for the spec's AC-5:** the `split` run meets every line and the control misses at least
one. The lines a capable model would meet from general sense alone (2, 3) are the weakest
evidence; 1, 4, 5 and 6 are the ones the skill adds.

## Result

- **Set-up flaw, found after the first control run:** `scratch-ROADMAP.md`'s comment is the
  roadmap template as this PR changes it, so the control could read the new slice rule; its
  entries' shape (line 6) is not evidence. The control is run again on
  [`scratch-ROADMAP-main.md`](scratch-ROADMAP-main.md), the template's comment as on `main`; the
  `split` run keeps the new comment, which is what a real project would have.
- [Control run 1](outputs/control-1.md), verbatim. Graded with the other runs below.

_The second control run, the `split` run and the grading follow in the next commit._
