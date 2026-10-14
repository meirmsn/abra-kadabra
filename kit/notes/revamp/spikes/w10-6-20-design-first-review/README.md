# W10.6.20 replay: does the spec review ask whether the design is right?

[Spec](../../../../../specs/design-first-spec-review.md). The `intent` skill's § 4 review, old
wording (`main` before this change) against new, replayed on one spec whose first design was too
big and two honest ones.

## Set-up (fixed before any run, 2026-10-14)

- **Specs**, each from a `git archive` export with no `.git`, so later history can't be read:
  - `pinned`: the first pinned-tools draft, `specs/pinned-tools-on-path.md` at `59dbdb7` (on its
    branch, before the owner's "seems like a huge solution" message and the redesign)
  - `tiers`: `specs/ci-fast-slow-tiers.md` from `a0a55e4`, in an export of `a0a55e4^`
  - `ui`: `specs/ui-baseline.md` from `960a834`, in an export of `960a834^`
  - `tiers` and `ui` are final, approved versions (no honest first draft is on record); their Go
    line is set back to `pending` so the helper can't defer to a recorded go
- **Prompts** ([pinned old](prompts/pinned-old.md), [new](prompts/pinned-new.md);
  [tiers old](prompts/tiers-old.md), [new](prompts/tiers-new.md); [ui old](prompts/ui-old.md),
  [new](prompts/ui-new.md)): the § 4 text of each wording quoted as written, the spec's path, the owner's words (the spec's own Intent section) and an instruction to read only the
  export and not use git. `<replay>` stands for the scratch directory holding the exports. Built by
  a script from `origin/main` and the working tree, not retyped
- **Helper**: a fresh `Plan` agent per run, as § 4 says. 3 runs per spec per wording: 18 runs
- **Contamination check**: each run's transcript is searched for tool calls that touch a path
  outside its export or run git; such a run is discarded and re-run

## Grading rule

A run **flags** a spec only when its design answer calls the spec's core design a workaround of a
deeper cause, or out of proportion to the problem. Naming an alternative in passing is not a flag.
For `pinned`, a flag counts only if it names the off-PATH install (or linking the tools onto PATH,
e.g. into `/usr/local/bin`) as the cause or the better design.

Pass (spec AC-4, AC-5): new wording flags `pinned` 3/3; old wording flags `pinned` ≤ 1/3; new
wording flags `tiers` 0/3 and `ui` 0/3. If old flags `pinned` ≥ 2/3, the build stops and the result
goes to the owner; this rule is not changed after the runs.

## Results

_Filled in after the runs._
