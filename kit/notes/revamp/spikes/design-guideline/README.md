# The design-guideline dry run: does a builder read `DESIGN.md` before it edits?

[Spec](../../../../../specs/design-guideline.md), its proof decision. The change adds one sentence
to `build` § 2 (read the project's `DESIGN.md` first, then the design and UI guidelines) and the
guideline it names. The dry run asks whether that sentence changes what a fresh builder does on a
small UI task. The grading below is committed before any run (the commits' order is the record).

## Set-up (fixed before any run, 2026-10-31)

- **The scratch project:** a directory outside the repo, `git init`ed with one commit, holding
  `runtime/templates/ui/`'s `example.html` as `index.html`, `base.css` and `theme.js` unchanged
  (the baseline: blue `primary`, the system font stack, no `highlight` token), plus
  [`site/DESIGN.md`](site/DESIGN.md): the open format, naming a display face the baseline doesn't
  have (`'Instrument Serif', Georgia, 'Times New Roman', serif`) and a copper `highlight` colour
  with light and dark values. Synthetic throughout. One fresh copy per run.
- **The task,** [`site/task.md`](site/task.md): a "Monthly totals" section with its heading in the
  project's display typeface and one figure in the project's colour for figures that matter. The
  baseline can't satisfy it: `base.css` has no display face and no copper, so the builder must
  take both values from somewhere.
- **Prompts,** built by [`build-prompts.sh`](build-prompts.sh) from real files, never retyped: the
  control gets `origin/main`'s `build` § 2 and `runtime/guidelines/` (materialised with
  `git archive`); the guided arm gets this change's working tree. Each prompt quotes § 2 verbatim,
  points the guidelines path at the run's directory, forbids gstack commands and commits, and asks
  for two things: the files read in order with a `-- first edit --` marker, and `git diff`.
- **Helpers:** a fresh `general-purpose` agent per run, which may edit the scratch copy (outside any
  project; the build skill's "helpers never edit" is about a project's code). Two runs per arm.
  Each output is saved verbatim under `outputs/`.

## Grading rule (fixed before the runs)

A run **passes** only when both lines hold, judged on the output's literal text.

1. **`DESIGN.md` before the first edit:** the project's `DESIGN.md` appears in the files-read list
   above the `-- first edit --` marker.
2. **Only `DESIGN.md`'s values:** every new literal `font-family` stack and every new literal colour
   in the diff (`oklch(…)`, hex, `rgb()`, `hsl()`, a named colour) is one `DESIGN.md` names, exactly
   or as the same stack; a `var(--…)` reference counts as the value of the token it names, so a new
   token in `base.css` is judged by its value.

**Pass for the spec's AC-5:** both guided runs pass both lines and at least one control run misses
a line. A helper that can't start is a could-not-run, re-run once; a second could-not-run is
recorded and no pass is claimed. If both control runs also pass both lines, the record says the
forced read made no difference on this task; the guideline still lands and the sentence stays as
cheap insurance unless the owner drops it.

## Result

_Filled in after the runs._
