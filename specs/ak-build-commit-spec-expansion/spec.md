<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: ak-build-commit-spec-expansion -->
<!-- date: 2026-05-29 -->

# Spec: ak-build-commit-spec-expansion

**Sources:**

- `PLAN.md` § `ak-build-commit-spec-expansion` row — scope summary + source pointer
- `kit/TODOS.md` § `/ak-build` Phase 1 doesn't commit the expanded `spec.md` — primary scope (problem + fix shape)
- Prior shipped spec `specs/ak-build-phase-decomposition/spec.md` — style/structure reference (devshop-self-mode SKILL.md change)

Make `/ak-build` commit the expanded `spec.md` at the end of Phase 1 so a crash
between Phase 1 and the next sweeping commit can't silently lose the spec
expansion or trigger an unnecessary re-spec on resume.

---

## Product update

Both blurbs as approved at Phase 0.2. Single source-of-truth — routed to
BUILD-LOG (`Headline:` ← Headline, `Summary:` ← Detail) and the
`/ak-merge-devshop` squash commit body (reads `spec.md § Product update`).

### Headline (user-facing)

Infrastructure update — no user-visible change in this PR.

### Detail (team-facing)

`/ak-build` now commits the expanded `spec.md` at the end of Phase 1, so a
crash between Phase 1 and the next sweeping commit can't silently lose the
spec expansion or trigger an unnecessary re-spec on resume. The Phase-exit
artifact check for Phase 1 and Step 0's resume rungs are tightened to read
committed state, closing the loop so a torn-down worktree, clean-tree guard,
or stray stash can't drop the work.

---

## Decisions (resolved at spec time)

4 `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below
so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking.

### D1: Where to add the commit step

**Decision:** In the shared **Phase 1** section of `.claude/skills/ak-build/SKILL.md`,
after the spec subagent returns — an orchestrator-side `git add $FEATURE_DIR/spec.md
&& git commit`. Applies to both devshop and project mode (Phase 1 is the shared
section; the devshop note is only an addendum).

**Rationale:** Matches the TODOS "Fix shape" primary recommendation; keeps Phase
1 owning its artifact; mirrors the existing Phase 0.3 skeleton-commit pattern
(`chore($FEATURE): Phase 0 spec skeleton`).

### D2: Commit message shape

**Decision:** `docs(<feature>): expand spec (Phase 1)` — verbatim from the TODOS
fix shape.

**Rationale:** Conventional `docs` type; parallels the Phase 0.3 skeleton commit
subject; "expand spec (Phase 1)" makes the commit's role self-describing in
`git log`.

### D3: Tighten the Phase-exit artifact check + resume rungs to committed state

**Decision:** Yes. Change the **Phase exit artifact registry** row 1 (Phase 1)
check shape so it asserts `## Task order` is present in a *commit*, not just the
working tree, and reword Step 0's resume rungs (4/5) so they read consistently
against committed state.

**Rationale:** This is the actual robustness goal — committed work survives a
worktree teardown / clean-tree guard / stray stash that uncommitted work would
not. The TODOS marks it "Optionally"; cost is near-zero and it closes the loop.

### D4: Idempotence guard on the new commit

**Decision:** Yes. Guard the new commit so it skips when `spec.md` is unchanged
vs HEAD (e.g. `git diff --quiet -- $FEATURE_DIR/spec.md`), then no-op rather
than erroring.

**Rationale:** Phase 1 is an atomic re-run on resume (same inputs → same
output). A blind commit would fail with "nothing to commit" on a re-entry where
the spec is already committed; the guard makes the step safe to re-run.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Files to
     create/modify, Tests, Dependencies, Task order, Gotchas, Acceptance /
     rollout / rollback. The Product update + Decisions sections above stay
     verbatim. -->

## In scope

A single-file SKILL.md prose change with two tightly-coupled edits, plus the
matching bats regression coverage:

1. **A new Phase 1 commit step.** After the spec subagent returns in
   `.claude/skills/ak-build/SKILL.md § Phase 1: Spec`, the orchestrator stages
   and commits the expanded `spec.md` — `docs($FEATURE): expand spec (Phase 1)`
   — guarded so it no-ops when `spec.md` is unchanged vs HEAD (resume / re-run
   safety). No push (the feature-branch push stays in Phase 4 / 4.5). Mirrors
   the existing Phase 0.3 skeleton-commit pattern (D1 / D2 / D4).

2. **Tighten the resume discriminator to committed state.** The Phase-exit
   artifact registry row for Phase 1 and Step 0's resume rungs 4 + 5 currently
   read `## Task order` from the working tree (`grep -q`). With the new commit
   step, the durable signal is the *committed* `spec.md`, so the registry check
   and the two rungs are reworded to read committed state
   (`git show HEAD:$FEATURE_DIR/spec.md | grep -q '## Task order'`) (D3).

**Explicitly out of scope** (devshop-self-mode — none of these surfaces exist
for a SKILL.md prose change):

- No METRICS.md events — devshop-self-mode has no METRICS.md (the spec subagent
  was told to skip the metrics-confirmation step).
- No screens, data-model changes, API contracts, or offline behavior.
- No push in Phase 1 — the feature-branch push remains owned by Phase 4 / 4.5,
  unchanged.
- No change to the Phase 0.3 skeleton commit, to `devshop-mode.md`, or to any
  other phase. `devshop-mode.md § Phase 1 note` only appends the
  devshop-self-mode metrics-skip line to the spec subagent prompt; it does NOT
  duplicate the Phase 1 commit step or the registry, so it needs no edit (see
  Gotchas + the verification finding below).

## Files to create/modify

Single file modified: **`.claude/skills/ak-build/SKILL.md`** (worktree copy is
editable; the canonical `/devshop/.claude/...` is the same logical file, edited
here in the worktree). Three edit regions:

### Edit region A — Phase 1 commit step (Task 1; D1 / D2 / D4)

`§ Phase 1: Spec`, currently lines ~753–777. Today the section ends with the
Agent prompt, the METRICS-fallback note (lines 769–773), and the `(Devshop
mode)` addendum (lines 775–777). **Insert a new subsection AFTER the
`(Devshop mode)` addendum (after line 777), before `## Phase 2: Implement`
(line 779).** Insertion text — verbatim:

> ### 1.1: Commit the expanded spec
>
> When the spec subagent returns, the expanded `spec.md` is sitting uncommitted
> in the working tree — only the Phase 0.3 skeleton commit and (later)
> `tasks.md` have landed. Commit the expansion now so a crash between here and
> the next sweeping commit can't silently lose it (and so Step 0's resume
> check, which reads committed state, sees a complete spec rather than
> re-running Phase 1):
>
> ```bash
> git add "$FEATURE_DIR/spec.md"
> # Idempotence guard: skip the commit if spec.md is already committed at HEAD
> # (Phase 1 is an atomic re-run on resume — same inputs, same output, so a
> # re-entry where the spec is already committed must no-op, not error with
> # "nothing to commit").
> if ! git diff --cached --quiet -- "$FEATURE_DIR/spec.md"; then
>   git commit -m "docs($FEATURE): expand spec (Phase 1)"
> fi
> ```
>
> No push yet — the feature-branch push happens in Phase 4 / 4.5 along with the
> rest of the implementation. This commit just needs to exist locally so a
> session crash + restart finds the full spec via Step 0's resume check
> (rung 4). This step applies to **both modes** — Phase 1 is the shared
> section; the `(Devshop mode)` note above is only a prompt addendum, not a
> separate Phase 1. Mirrors the Phase 0.3 skeleton commit
> (`chore($FEATURE): Phase 0 spec skeleton`).

(The blockquote above is presentation-only; the implementer transcribes its
contents as plain SKILL.md text, keeping the inner ```bash fence as a real
fenced block.)

### Edit region B — Phase-exit artifact registry row 1 (Task 2; D3)

Registry table, line 146. Current:

```
| 1 | `$FEATURE_DIR/spec.md` contains `## Task order` | Phase 1 (spec agent) | Step 0 resume check | `grep -q '## Task order'` |
```

Replace with (Producer = the new commit step; Check shape asserts committed
state):

```
| 1 | `$FEATURE_DIR/spec.md` committed with `## Task order` | Phase 1.1 (commit step) | Step 0 resume check | `git show HEAD:$FEATURE_DIR/spec.md \| grep -q '## Task order'` |
```

(The `\|` escapes the pipe inside the markdown table cell so the `grep` pipe
doesn't break the column. Producer flips from "Phase 1 (spec agent)" to
"Phase 1.1 (commit step)" because the committed artifact — not the working-tree
expansion — is now what the check reads.)

### Edit region C — Step 0 resume rungs 4 + 5 (Task 2; D3)

`### Resume check`, lines 306–307. Current:

```
4. **`$FEATURE_DIR/spec.md` exists and contains `## Task order`?** → full spec written by Phase 1 → skip to Phase 2 (implement)
5. **`$FEATURE_DIR/spec.md` exists but lacks `## Task order`?** → Phase 0 wrote the skeleton (provenance + Decisions only); Phase 1 hasn't completed → re-run Phase 1. Spec agent reads the existing file, preserves its Decisions section verbatim, and expands into the full spec. Do NOT re-prompt the user.
```

Replace with (both rungs read committed state via `git show HEAD:`):

```
4. **`$FEATURE_DIR/spec.md` committed at HEAD with `## Task order`?** (`git show HEAD:$FEATURE_DIR/spec.md | grep -q '## Task order'`) → full spec written AND committed by Phase 1 → skip to Phase 2 (implement)
5. **`$FEATURE_DIR/spec.md` committed at HEAD but lacks `## Task order`?** → Phase 0.3 committed the skeleton (provenance + Decisions only); Phase 1 hasn't completed (or crashed before its 1.1 commit) → re-run Phase 1. Spec agent reads the existing file, preserves its Decisions section verbatim, and expands into the full spec; Phase 1.1 commits it. Do NOT re-prompt the user.
```

**Consistency note for the implementer:** the narrative paragraph at lines
325–328 ("The `## Task order` header is the discriminator between a Phase 0
skeleton and a Phase 1 completed spec … Phase 0 never writes it; Phase 1 always
does.") stays accurate after the change, but should be lightly reworded so
"discriminator" reads against committed state to match rungs 4/5 — e.g. append
"… and Phase 1.1 commits it, so Step 0 reads the discriminator from the
committed `spec.md` (`git show HEAD:…`), not the working tree." Keep it to a
one-clause addition; do not rewrite the paragraph.

## Tests

bats regression only. There is **no new behavior script** to unit-test — the
change is SKILL.md prose that an LLM orchestrator follows at runtime, so the
test surface is structural assertions against the SKILL.md text, exactly like
the existing ak-build structural tests.

**Existing test to extend:** `kit/tests/util-ak-build-skill.bats`. It already
asserts SKILL.md structure (Phase 0.4 convention, Step 0 branch heuristic,
Phase 4.0/5.6 wiring, and a **Section F — resume-reconcile gate wiring** block
that uses `awk '/^### Resume check/,/^## Phase 0/'` to scope assertions to the
resume region, and asserts registry rows via `grep -qE '\| 2 \|...'`). Add a
new section (e.g. **Section G — Phase 1 spec-commit + committed-state resume**)
with assertions:

- **G1 — Phase 1.1 commit subsection present:** `grep -qE '^### 1\.1: Commit
  the expanded spec' "$SKILL_FILE"`.
- **G2 — commit step uses the canonical message + idempotence guard:** scope to
  the Phase 1 region (e.g. `awk '/^## Phase 1: Spec/,/^## Phase 2:/'`), then
  assert `git add "$FEATURE_DIR/spec.md"`, `git diff --cached --quiet`, and
  `docs($FEATURE): expand spec (Phase 1)` all appear; and assert NO `git push`
  in that region (`! grep -q 'git push'`).
- **G3 — registry row 1 asserts committed state:** `grep -qE '\| 1 \|.*committed.*## Task order.*git show HEAD:'` against `$SKILL_FILE` (one row-1 line, pipe-escaped).
- **G4 — resume rungs 4 + 5 read committed state:** scope to the resume region
  (`awk '/^### Resume check/,/^## Phase 0/'`), assert both rungs reference
  `git show HEAD:` / "committed at HEAD" (e.g. `grep -c 'committed at HEAD'`
  ≥ 2, or assert each rung line individually).

Run the suite from the worktree:
`kit/tests/lib/bats-core/bin/bats kit/tests/util-ak-build-skill.bats` for the
targeted file, and `kit/tests/lib/bats-core/bin/bats kit/tests/` for the full
sweep before marking done. `util-ak-build-devshop-mode.bats` does NOT assert
the Phase 1 commit / registry / rungs, so it needs no change — but confirm it
stays green (the registry-row reword must not break any existing assertion).

## Dependencies

None. No other in-flight feature touches `§ Phase 1`, the registry row 1, or
resume rungs 4/5 of `.claude/skills/ak-build/SKILL.md`. No package, schema, or
script dependency. The two tasks are sequenced (Task 1 introduces Phase 1.1,
which Task 2's registry/rung rewording references by name) but both land in the
same file and can be one or two commits.

## Task order

Two implementation tasks, matching the tracker decomposition.

1. **Add the commit-expanded-spec step to Phase 1 (shared, both modes, with
   idempotence guard).** Edit region A — insert the `### 1.1: Commit the
   expanded spec` subsection (with `git add` + `git diff --cached --quiet`
   guard + `docs($FEATURE): expand spec (Phase 1)` commit, no push) after the
   `(Devshop mode)` addendum and before `## Phase 2`. Add bats assertions G1 +
   G2 to `util-ak-build-skill.bats` in the same commit.

2. **Extend the Phase-exit registry row 1 + resume rungs 4/5 to assert
   committed `## Task order`.** Edit regions B + C — reword registry row 1 to
   `git show HEAD:$FEATURE_DIR/spec.md | grep -q '## Task order'` (Producer →
   Phase 1.1), reword rungs 4 + 5 to read committed state, and lightly amend
   the lines 325–328 discriminator paragraph for consistency. Add bats
   assertions G3 + G4 in the same commit.

## Gotchas

- **The running `/ak-build` instance won't re-read the edited SKILL.md
  mid-run.** This change only affects *future* `/ak-build` invocations. The
  current build pipeline (this very run) executes from the SKILL.md text loaded
  at its start, so the spec-commit fix it describes will NOT apply to the commit
  of *this* spec. That is fine and expected — the orchestrator that launched
  this `/ak-spec` agent handles committing this spec.md per its instructions; do
  NOT attempt to "self-apply" the new step here.

- **Project-mode and devshop-mode share Phase 1.** The edit is in the shared
  `§ Phase 1` section, so it applies to both. `devshop-mode.md § Phase 1 note`
  only appends a prompt line; it must NOT gain a duplicate commit step. Verified
  (see below): no file under `.claude/skills/ak-build/` references the Phase 1
  commit behavior, so SKILL.md is the only file to edit.

- **The new commit must not trip pre-commit guards.** Phase 0.3 already commits
  `spec.md` alone (`chore($FEATURE): Phase 0 spec skeleton`) without issue, so a
  `docs(...)` commit of the same single file clears the clean-tree guard,
  docs-coverage, and mixed-commit checks the same way. The idempotence guard
  (`git diff --cached --quiet`) prevents an empty-commit failure on resume
  re-entry. The commit subject is conventional (`docs` type), matching the
  Phase 0.3 precedent.

- **Pipe-escaping in the registry table.** Row 1's new check shape contains a
  shell pipe (`git show … | grep`). Inside a markdown table cell it MUST be
  written `\|` so the column delimiter isn't broken — and the bats G3 assertion
  must match the escaped form. The rung text (region C) is prose, not a table,
  so its `|` needs no escaping there.

- **Nested fenced code block in edit region A.** The inserted subsection
  contains its own ```bash fence. When the implementer transcribes it into
  SKILL.md, the bash block must remain a real fenced block in the final file
  (the spec's outer blockquote is just for presentation here).

- **Keep rungs 4/5 numbering + the `awk` scope intact.** The existing Section F
  bats assertions scope the resume region with
  `awk '/^### Resume check/,/^## Phase 0/'` and assert rung 2 by `| 2 |` /
  prose. Don't renumber rungs or move the `### Resume check` / `## Phase 0`
  boundary headers, or those assertions (and the new G4) break.

## Acceptance / rollout / rollback

**Acceptance:**

- `### 1.1: Commit the expanded spec` exists in `§ Phase 1`, after the
  `(Devshop mode)` addendum, before `## Phase 2`, with the `git add` +
  `git diff --cached --quiet` guard + `docs($FEATURE): expand spec (Phase 1)`
  commit and an explicit "no push" note.
- Registry row 1 reads committed state (`git show HEAD:… | grep -q '## Task
  order'`), Producer = Phase 1.1.
- Resume rungs 4 + 5 read committed state (`git show HEAD:` / "committed at
  HEAD").
- The lines 325–328 discriminator paragraph is consistent with committed-state
  reading.
- `kit/tests/lib/bats-core/bin/bats kit/tests/util-ak-build-skill.bats` passes,
  including new assertions G1–G4.
- Full sweep `kit/tests/lib/bats-core/bin/bats kit/tests/` is green
  (`util-ak-build-devshop-mode.bats` and all others unaffected).

**Rollout:** Lands via the standard devshop flow — feature branch
`feat/ak-build-commit-spec-expansion`, `/ak-build` devshop-mode pipeline, squash
via `/ak-merge-devshop`. The change is documentation/prose; it takes effect for
the *next* `/ak-build` run after merge. No migration, no propagation block
(the edit touches `.claude/skills/**`, not `template/**` / `kit/scripts/**` /
`kit/hooks/**` / `.devcontainer/**` / `manifest.txt`, so no
`**Existing projects:**` block is required).

**Rollback:** Revert the single SKILL.md commit (and its bats commit if
separate). Zero runtime state, zero schema, zero data — reverting fully restores
prior behavior (uncommitted spec swept by a later commit; working-tree resume
check). No coordinated rollback needed.

---

<!-- Phase 1 verification finding (per the /ak-spec instruction to VERIFY
     whether devshop-mode.md or any other ak-build skill file references the
     Phase 1 commit behavior):

     Searched .claude/skills/ak-build/ (SKILL.md + devshop-mode.md — the only
     two files in the dir) for "expand spec", "Phase 1 ... commit",
     "docs(...): expand", "Task order", "Phase exit artifact", "resume rung".
     Result: ONLY SKILL.md owns the Phase 1 section, the Phase-exit artifact
     registry, and Step 0's resume rungs. devshop-mode.md § Phase 1 note (lines
     95-100) only appends the devshop-self-mode metrics-skip line to the spec
     subagent prompt and explicitly defers to project mode for the resume rungs
     ("Rungs 2-6 ... are identical to project mode — no adaptation needed",
     lines 43-45). It does NOT duplicate the commit step or the registry.
     Conclusion: SKILL.md is the only file to edit. devshop-mode.md needs no
     change. -->
