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
  [control](prompts/control.md) gets `origin/main`'s `build` § 2 and `runtime/guidelines/`
  (materialised with `git archive`); the [guided](prompts/guided.md) arm gets this change's
  working tree. Each prompt quotes § 2 verbatim,
  points the guidelines path at the run's directory, forbids gstack commands and commits, and asks
  for two things: the files read in order with a `-- first edit --` marker, and `git diff`.
- **Helpers:** a fresh `general-purpose` agent per run, which may edit the scratch copy (outside any
  project; the build skill's "helpers never edit" is about a project's code). Two runs per arm.
  Each output is saved verbatim under `outputs/`: [control 1](outputs/control-1.md),
  [control 2](outputs/control-2.md), [guided 1](outputs/guided-1.md),
  [guided 2](outputs/guided-2.md).

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

## Result (2026-10-31, one fresh copy and one fresh helper per run)

| Line                              | Control 1 | Control 2 | Guided 1 | Guided 2 |
| --------------------------------- | --------- | --------- | -------- | -------- |
| 1 `DESIGN.md` before the first edit | pass (3rd file read) | pass (1st file read) | pass (2nd, after a directory listing) | pass (2nd, after a missing `CLAUDE.md`) |
| 2 only `DESIGN.md`'s values       | pass      | pass      | pass     | pass     |

**All four runs pass both lines, so the spec's pass rule ("at least one control run misses a
line") is not met, and the pre-registered reading applies:** the forced read made no measurable
difference on this task. Both controls found `DESIGN.md` on their own: `main`'s `ui.md`, which § 2
already loads, names it, and a builder exploring a four-file project opens it. What the guided arm
changed is the order and the reading, not the outcome: both guided helpers read `DESIGN.md` first
or second, then `design.md`, then `ui.md`, before any project file; the controls read the
guidelines README and `ui.md` first (control 1) or `DESIGN.md` then the guidelines (control 2).
Every run took the display stack and the copper values from `DESIGN.md`, through new tokens in
`base.css`, and no run added a literal value outside it. The guideline lands on the owner's go;
the one sentence in `build` § 2 stays as cheap insurance (the spec's decision), and the real check
is the first UI slice of a project with a `DESIGN.md` that is not four files long.

**Also seen, not graded:** all four runs left `highlight-foreground` out of the theme because the
scratch `DESIGN.md`'s light pair is 3.76:1 and `tokens-check` pairs `--X-foreground` on `--X` at
4.5:1 (a flaw in the scratch file, which a real `DESIGN.md` check would catch: the next change);
guided run 2 set the figure at `font-weight: 550` where `DESIGN.md` gives the display face weight
400 (a weight, which line 2 doesn't grade; the reviewer's design lens would); guided run 2's first
render run hit a sibling run's server on the same port and was re-run on a free one; both guided
runs found the repo's pinned Playwright has no Chromium in this image (F-NEW-132).
