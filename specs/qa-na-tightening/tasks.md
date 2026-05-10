<!-- generated-by: /ak-implement -->
<!-- feature: qa-na-tightening -->

# Tasks: qa-na-tightening

Spec: `specs/qa-na-tightening/spec.md` § Task order. Decisions D0-D6 are
locked in the spec; this file tracks per-task implementation status plus any
implementation-time judgment calls that didn't appear in the spec.

## Task status

| #     | Task                                                                                                                | Status      |
| ----- | ------------------------------------------------------------------------------------------------------------------- | ----------- |
| 1     | Add `coreUserStoryNaReason` check-type to `kit/scripts/adversarial-review.sh` (+ `kit/docs/guide/hooks.md` doc row) | in_progress |
| 2     | Wire `verify-story.sh`'s N/A branch (+ `pre-ship/SKILL.md` Gate 9 § N/A note)                                       | pending     |
| 3     | BATS suite at `kit/tests/util-adversarial-review-coreUserStoryNaReason.bats`                                        | pending     |
| ~~4~~ | ~~Doc updates~~ — split across Tasks 1 + 2 to satisfy commit-time docs-coverage hook (see § Decisions)              | folded      |

## Decisions

(Implementation-time judgment calls. Decisions made during /ak-implement that
weren't pre-resolved in the spec land here.)

### Task ordering — fold Task 4 into Tasks 1 + 2 to satisfy the commit-time docs-coverage hook

**Background.** The spec § Task order specifies four atomic commits, with
Task 4 ("Doc updates: `hooks.md` + `pre-ship/SKILL.md`") landing as a single
trailing commit. At implementation time, Task 1's commit (touching only
`kit/scripts/adversarial-review.sh`) tripped `check-docs-coverage-devshop.sh`
which requires a paired guide-doc edit when `kit/scripts/**` files change.
Same constraint applies to Task 2 (`kit/scripts/preship/**` requires
`pre-ship/SKILL.md` OR a guide doc).

The auto-mode classifier blocks `git -c devshop.docsCoverageReason="…"` as a
safety-check bypass — the correct response is to address the hook by
staging the relevant doc, not to route around it.

**Decision.** Split Task 4 by surface:

- `kit/docs/guide/hooks.md` (the new row in the adversarial-reviewed surface
  enumeration) lands with Task 1, since it documents the new check-type
  alongside the script change that introduces it.
- `.claude/skills/devshop/pre-ship/SKILL.md` (the Gate 9 § N/A subsection
  addendum) lands with Task 2, since it documents the gate-side wiring
  alongside the `verify-story.sh` change that invokes the check.

**Atomicity preserved.** The spec's stated atomicity rationale for Task 4 was
"they describe the same shipped behavior; splitting risks mid-PR doc-drift."
That rationale is honored by landing each doc edit alongside the code change
it describes — the doc and code now ship together rather than in a trailing
catch-up commit. Bisect history stays clean (every commit is a self-contained
behavior + its docs). Task 4 itself becomes a no-op marker (`folded` row in
the status table above).

**Alternative considered.** Use the docs-coverage bypass flag once for Task 1
and once for Task 2, with a per-doc enumeration in the bypass reason. Rejected
because (a) the auto-mode classifier correctly flags this as a safety-check
bypass — the bypass exists for genuinely unfixable cases, not for routine
ordering preferences, and (b) the trailing-commit ordering offers no benefit
that the per-task colocation doesn't already give.

### Task 1 — `extract_bold_section()` helper for workflow.md inlining

The spec's D4 + Gotchas note that `workflow.md § Core user story requirement`
is the inlining target, but `## Core user story requirement` is **not** a
literal `##` markdown heading in the file — it lives as a bolded sub-section
(`**New (Phase 1-B landing — Core user story requirement)**: …`) under
`## Step 4: /ak-build`. The existing `extract_convention_section()` helper
(line 341) only resolves `## <heading>` slices, so re-using it would silently
yield empty.

**Decision:** Add a sibling helper `extract_bold_section()` that anchors on
`index($0, h) > 0` (substring match, not strict equality), reads from the
match line forward, and stops at either the next `## ` heading or the next
blank-line-followed-by-bold-prefix. Pair it with a single-purpose
`get_workflow_to_inline()` that returns a `relpath|heading` tuple and a new
inlining loop right after the existing `CONVENTIONS_FILE` block. Empirically
verified the helper extracts the canonical 11-line body when fed `Core user
story requirement` against `kit/docs/guide/workflow.md`.

Alternative considered: extend `extract_convention_section()` to fall back to
substring-on-bold when strict-equality fails. Rejected because it widens the
existing helper's contract for one caller — every other caller would have to
prove the substring fallback doesn't false-match on their headings.

### Task 1 — bare `N/A` (no rationale) handling

The spec § Gotchas says "If the body is just `N/A` with no rationale, the
rationale text is empty; pass empty string to `adversarial-review.sh` (the
reviewer will then judge 'no rationale at all' as automatically REJECT under
Rule #11's 'missing rationale' sub-criterion — same shape as `dismissalLog`'s
'missing rationale field entirely' rule)."

**Decision:** Rule #11 sub-criterion (d) makes the missing-rationale path an
explicit automatic FAIL — codified verbatim in the prompt rather than left
to the Sonnet reviewer's judgment. Tightens the contract: a bare `N/A` body
cannot squeak through with a charitable interpretation.
