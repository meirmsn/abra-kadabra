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

2026-10-14, graded by the rule above. Raw reports: one file per run in `outputs/`, linked below. Contamination check: no run read outside its own export or ran
git (the only hits were `find … -not -path './.git/*'` inside the export).

| Spec               | Old wording flags | New wording flags | Bar           |
| ------------------ | ----------------- | ----------------- | ------------- |
| `pinned` (too big) | 0/3               | **0/3**           | new 3/3: fail |
| `tiers` (honest)   | 0/3               | **1/3**           | new 0/3: fail |
| `ui` (honest)      | 0/3               | **3/3**           | new 0/3: fail |

**The replay fails AC-4 and AC-5.** Per run:

- `pinned-old-1..3` ([1](outputs/pinned-old-1.md), [2](outputs/pinned-old-2.md), [3](outputs/pinned-old-3.md)): detail findings only (test breakage, the dcg rule, AC numbering). No design
  verdict. Not flags
- [`pinned-new-1`](outputs/pinned-new-1.md): "Putting a line in `CLAUDE_ENV_FILE` from the dispatcher fixes the cause and is
  about the right size"; its unlisted option is a fallback in the project scripts. Not a flag
- [`pinned-new-2`](outputs/pinned-new-2.md): "the spec has it right, but leaves one option out" (a line in `~/.bashrc`). Not a
  flag
- [`pinned-new-3`](outputs/pinned-new-3.md): "Root cause and design are right"; unlisted option: script fallback. Not a flag
- `tiers-old-1..3` ([1](outputs/tiers-old-1.md), [2](outputs/tiers-old-2.md), [3](outputs/tiers-old-3.md)), `ui-old-1..3` ([1](outputs/ui-old-1.md), [2](outputs/ui-old-2.md),
  [3](outputs/ui-old-3.md)): no design verdict. Not flags
- [`tiers-new-1`](outputs/tiers-new-1.md): the checker is beyond the ask ("ask the owner whether the checker belongs"), the
  tiers are justified. Part, not core: not a flag
- [`tiers-new-2`](outputs/tiers-new-2.md): "The design doesn't save what the owner asked about … The cause of the waste is
  that duplicated job setup": calls the core design not a fix for the cause. **Flag**
- [`tiers-new-3`](outputs/tiers-new-3.md): tiers justified; "What isn't proportionate is the extra machinery" (the checker).
  Part, not core: not a flag
- [`ui-new-1`](outputs/ui-new-1.md): "The design is far bigger than the problem." **Flag**
- [`ui-new-2`](outputs/ui-new-2.md): "The checks are much bigger than the problem." **Flag**
- [`ui-new-3`](outputs/ui-new-3.md): "The two checks are much bigger than the problem." **Flag**

## What it shows

- The new wording changes what the helper says: 9 of 9 new runs gave a design verdict before the
  details, 0 of 9 old runs did. The old wording never once questioned a design.
- It did not find the pinned-tools root cause. All three new runs named the cause correctly (the
  tools are installed off PATH) and then judged the env-file hook a fix for it. The draft argued
  against linking into `/usr/local/bin` ("rests on the image keeping that directory on PATH … shares
  it with other installers"), and no run challenged that rejection: "rejected options included"
  made them list new options, not re-weigh the author's.
- On the honest specs it flags size, mostly the extra checkers both specs added beyond the owner's
  words. Whether those are false alarms is the owner's call: the owner approved both specs, and the
  same points (the CI checker, the two UI checkers) were also raised as "scope beyond the ask" by the
  old wording.

Per the owner's rule (spec, "3. A"), the build stopped here and the result went to the owner; the
grading rule was not changed after the runs.

## Round 2 (owner, 2026-10-14, "B"; set-up fixed before its runs)

The § 4 design questions now also ask the helper to argue for the strongest option the author
rejected or didn't list, and whether the change fixes where the problem starts or only where it
shows. Only the new wording runs again: 3 runs per spec, the same exports, prompts built by the same
script ([pinned](prompts/pinned-new-r2.md), [tiers](prompts/tiers-new-r2.md),
[ui](prompts/ui-new-r2.md)). Same bars and the same grading rule as above. The pinned-tools draft is
no longer held out: this wording was shaped after seeing why round 1 missed it. If either bar
fails, § 4 goes back to its old wording and only the § 2 clause ships (option C).

### Round 2 results

2026-10-14, graded by the same rule. Contamination check: no run read outside its own export or ran
git.

| Spec               | Round 1 new | Round 2 new | Bar                     |
| ------------------ | ----------- | ----------- | ----------------------- |
| `pinned` (too big) | 0/3         | **0/3**     | 3/3: fail               |
| `tiers` (honest)   | 1/3         | **2/3**     | 0/3: fail               |
| `ui` (honest)      | 3/3         | **3/3**     | 0/3: fail               |

- [`pinned-new-r2-1`](outputs/pinned-new-r2-1.md): "The spec fixes where the problem starts … The
  fix is in the right layer"; strongest unlisted option: a PATH line in the shell profile. Not a flag
- [`pinned-new-r2-2`](outputs/pinned-new-r2-2.md): "the fix lands where it should"; the env-file
  approach is better than a script fallback. Not a flag
- [`pinned-new-r2-3`](outputs/pinned-new-r2-3.md): "Size is in proportion"; strongest unlisted
  option: a fallback in the project scripts. Not a flag
- [`tiers-new-r2-1`](outputs/tiers-new-r2-1.md): "Cause versus symptom; the saving is smaller than
  claimed … a lot for a question about duplicated lint". **Flag**
- [`tiers-new-r2-2`](outputs/tiers-new-r2-2.md): "The cause is fixed, but the claimed saving isn't
  stated correctly"; one job with two steps as an alternative. Not a flag
- [`tiers-new-r2-3`](outputs/tiers-new-r2-3.md): "the waste is fixed by merging jobs and the tiers are
  a separate goal … The tier design goes well beyond the question". **Flag**
- [`ui-new-r2-1`](outputs/ui-new-r2-1.md): "most of the spec is two checkers, and the owner never
  asked for them". **Flag**
- [`ui-new-r2-2`](outputs/ui-new-r2-2.md): "Size is out of proportion." **Flag**
- [`ui-new-r2-3`](outputs/ui-new-r2-3.md): "The size is out of proportion to 'a design baseline'."
  **Flag**

Asked to argue for rejected options, the helpers argued for new ones (a shell-profile line, a script
fallback); none argued for the draft's own rejected option, linking into `/usr/local/bin`. **Round 2
failed both bars, so option C applies:** § 4 keeps its old wording, the § 2 clause ships, and the
finding is F-NEW-65 in [FINDINGS](../../FINDINGS.md).

