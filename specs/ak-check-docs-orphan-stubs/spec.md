<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: ak-check-docs-orphan-stubs -->
<!-- date: 2026-05-31 -->

# Spec: ak-check-docs-orphan-stubs (devshop)

**Sources:**

- `kit/TODOS.md` (entry at ~line 348) — primary scope: `/ak-check-docs-and-tests`
  Step 1 scaffolds `specs/<feature>/review.md` even for doc-only commits with no
  source surface, leaving orphan stubs. Witnessed twice on doc-only
  `/ak-merge-devshop` runs.
- `.claude/skills/devshop/check-docs-and-tests/SKILL.md § Step 1` — edit target.
- `kit/scripts/commit-hooks/check-docs-coverage-devshop.sh` — existing tracker-path
  carve-out machinery to stay consistent with.
- `.claude/skills/ak-docs-review/SKILL.md § Section A` — existing audit carve-out list.
- Prior shipped spec `specs/worktree-support/spec.md` — style/structure reference.

`/ak-check-docs-and-tests` short-circuits cleanly on tracker-only diffs instead of
scaffolding an orphan `specs/<feature>/review.md` stub that never reaches `main`.

---

## Product update

Single source-of-truth — Phase 4.0 copies Headline → BUILD-LOG `Headline:` and
Detail → BUILD-LOG `Summary:`; `/ak-merge-devshop` reads this section for the squash
commit body.

### Headline + Detail (combined)

Infrastructure update — no user-visible change in this PR. Doc-only / tracker-only
devshop merges no longer leave orphan `specs/<feature>/review.md` stubs behind: the
audit orchestrator (`/ak-check-docs-and-tests`) now classifies the diff up front and
short-circuits cleanly when there is no source surface to review.

---

## Decisions (resolved at spec time)

### D1: Implementation shape — testable helper, not prose-only

**Decision:** Implement the classification as a standalone helper
`kit/scripts/preship/audit-tracker-only.sh` with real bats behavior tests
(`kit/tests/util-audit-tracker-only.bats`), wired into `check-docs-and-tests`
SKILL.md Step 1. Not inline-prose-only.

**Rationale:** A real script gives genuine behavior coverage (honors "no code without
tests") and is reusable; pairs with the existing audit/gate helper
`kit/scripts/preship/check-llm-mediated-na.sh`. The TODO framed it as "a few lines of
prose," but a tested helper is the stronger, recurrence-proof fix.

### D2: Short-circuit path set — trackers only, plus friction-log

**Decision:** A diff is "tracker-only / no source surface" when every changed path
matches the tracker set: `^(PLAN|TODOS|BUILD-LOG|PRODUCT-ROADMAP|DEPS-WATCH)\.md$`,
`^kit/(TODOS|ROADMAP|notes|version)`, `^kit/docs/CHANGELOG\.md$`, and
`^kit/FRICTION-LOG\.md$`. Deliberately **excludes** `kit/docs/guide/**` and
`kit/tests/**`.

**Rationale:** Guide-doc and test-only changes are exactly what `/ak-docs-review` and
`/ak-tests-review` audit — short-circuiting them would suppress real findings. Only
pure trackers (intake/backlog/changelog/version) carry no auditable source surface.
`kit/FRICTION-LOG.md` is a pure tracker (friction intake) and belongs in the set.

### D3: Short-circuit fires BEFORE the stub scaffold

**Decision:** The classification runs before Step 1's stub-scaffold substep — compute
a preliminary range, classify, and exit 0 (short-circuit) if tracker-only; only
scaffold the stub when the diff has a real source surface.

**Rationale:** The orphan stub IS the Step 1.4 scaffold. The gate must precede it or
the orphan is already created.

### D4: Helper script home — kit/scripts/preship/

**Decision:** `kit/scripts/preship/audit-tracker-only.sh`.

**Rationale:** Pairs with the other audit/gate helper (`check-llm-mediated-na.sh`) in
the same directory; the audit runs as pre-ship Gate 5.

### D5: Orphan-dir cleanup — already done

**Decision:** No cleanup commit. `specs/roadmap-supabase-port-registry/` and
`specs/plan-synthesis/` are already absent (removed at the plan-synthesis merge per
the TODO's own Cleanup note). The PR still closes the TODO entry.

**Rationale:** Verified absent during Phase 0.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Files to
     create/modify, Tests, Dependencies, Task order, Gotchas, Acceptance.
     The Product update + Decisions sections above stay verbatim. -->

## In scope

Make `/ak-check-docs-and-tests` short-circuit on tracker-only diffs so a doc-only /
tracker-only devshop merge stops scaffolding an orphan `specs/<feature>/review.md`
stub that never reaches `main`. The fix is a tested classifier helper wired into the
orchestrator's Step 1, ahead of the stub-scaffold substep.

- **New helper** `kit/scripts/preship/audit-tracker-only.sh` — classifies a git range
  as "tracker-only / no source surface" (exit 0, caller short-circuits) vs "has source
  surface to audit" (exit 1). Pairs with the sibling audit/gate helper
  `kit/scripts/preship/check-llm-mediated-na.sh`.
- **New bats** `kit/tests/util-audit-tracker-only.bats` — behavior tests over a temp
  git-repo fixture covering the full tracker / source / guide-doc / test-only /
  friction-log / empty-diff matrix.
- **Edit** `.claude/skills/devshop/check-docs-and-tests/SKILL.md § Step 1` — add the
  short-circuit clause that runs the helper BEFORE the substep-4 stub scaffold, with a
  preliminary range computed consistently with the existing explicit-`--range` /
  `GIT_ROOT_AUDIT` handling. (`.claude/skills/ak-check-docs-and-tests/SKILL.md` is a
  symlink to this same file — one edit covers both.)
- **Edit** `kit/tests/util-check-docs-and-tests.bats` — add a grep test asserting Step 1
  documents the tracker-only short-circuit (names the helper + the exit-0 / no-scaffold
  behavior).
- **Edit** a guide doc — concise entry documenting the new SKILL.md short-circuit +
  helper surfaces (satisfies the Layer 1 docs-coverage pairing for the new `.sh` +
  the touched `SKILL.md`).
- **Close** the `kit/TODOS.md` orphan-stub entry (delete it) + unwind any
  cross-references.

### Out of scope

- **Orphan-dir cleanup** — `specs/roadmap-supabase-port-registry/` and
  `specs/plan-synthesis/` are already absent (D5). No cleanup commit.
- **Project-mode analogue** — the helper's tracker set is devshop-self-shaped (D2). A
  project-repo variant (`apps/`-aware source detection) is not in scope; the
  orchestrator's project-mode path keeps scaffolding as before. If a project-mode
  orphan-stub bite is ever witnessed, file a fresh entry — do not pre-build it here.
- **Changing the per-commit `check-docs-coverage-devshop.sh` carve-out machinery** —
  the new helper reuses the _concept_ (the same tracker-shaped paths the coverage hook
  already ignores) but is a standalone script with its own range-based contract; it does
  NOT call or refactor the commit-hook.

## Helper contract — `kit/scripts/preship/audit-tracker-only.sh`

```
Usage:
  audit-tracker-only.sh <git-range>

Exit codes:
  0 — tracker-only (every changed path matches the tracker set) → caller short-circuits
  1 — has source surface (at least one changed path is NOT a tracker path) → caller audits
 64 — usage error (no range argument)
```

- `$1` is a git RANGE (e.g. `<SHA>..HEAD`, `origin/main..HEAD`). The helper runs
  `git diff --name-only "$RANGE"` and classifies every line.
- **Tracker set (D2)** — a path is a tracker path when it matches ANY of:
  - `^(PLAN|TODOS|BUILD-LOG|PRODUCT-ROADMAP|DEPS-WATCH)\.md$`
  - `^kit/(TODOS|ROADMAP|notes|version)`
  - `^kit/docs/CHANGELOG\.md$`
  - `^kit/FRICTION-LOG\.md$`
- **Deliberately NOT tracker paths** (these DO carry auditable source surface, so a diff
  touching them must NOT short-circuit): `kit/docs/guide/**`, `kit/tests/**`, all
  `kit/scripts/**`, `.claude/skills/**`, `template/**`, `.devcontainer/**`, and any
  project-side `apps/`/`packages/`/`src/`/`app/` path.
- **Verdict rule:** exit 0 iff the diff is non-empty-OR-empty AND every changed path is a
  tracker path. Exit 1 the moment a single non-tracker path appears (short-circuit on
  first miss — no need to scan the rest).
- **Empty-diff behavior:** an empty `git diff --name-only` (no changed paths) exits **0**
  — there is no source surface to audit, so the caller should short-circuit. (See
  Gotchas — this is a deliberate decision point, not an oversight. The orchestrator's
  pre-existing idempotence guard already no-ops the `SHA == HEAD` empty-range case
  upstream, so in practice the helper rarely sees a truly empty diff; exit 0 keeps it
  conservative and consistent with "nothing to audit → don't scaffold.")
- **mawk/dash portability:** the matcher uses POSIX-portable constructs. Two acceptable
  implementations — pick the simpler:
  - a `case "$path" in <glob>) ... esac` per line in the read loop (no regex engine at
    all — pure POSIX shell `case` globbing; mirrors `check-docs-coverage-devshop.sh
is_carveout()`), OR
  - a single `grep -Ev '<tracker-regex>'` over the name-only output — if grep finds ANY
    line that does NOT match the tracker regex, that's a source surface → exit 1. Use
    `grep -E` (ERE, mawk-irrelevant — this is grep not awk) with no `\b`/PCRE
    constructs.
    The `case`-per-line form is preferred (D-style consistency with the existing carve-out
    helper, zero regex-portability surface). Whichever is chosen, NO bash-isms that break
    under `sh`/dash if the script is ever sourced by a dash hook (the helper ships with a
    `#!/usr/bin/env bash` shebang like its siblings, so dash-sourcing is not a live path,
    but keep the body POSIX-clean anyway).
- **Header:** 3-line `# What:` / `# Why:` / `# Does NOT:` block (CLAUDE.md
  Non-Negotiable; verified by `util-file-headers.bats`), then `set -euo pipefail`, then a
  `Usage:` + `Exit codes:` comment block patterned after `check-llm-mediated-na.sh`.
- **Spec back-reference** in the header: `# Spec: specs/ak-check-docs-orphan-stubs/spec.md`.

## SKILL.md Step 1 short-circuit — `check-docs-and-tests/SKILL.md`

Insert the short-circuit as a new substep that runs BEFORE the current substep 4 (stub
scaffold). It is the orphan-stub fix: the scaffold IS the orphan, so the gate must
precede it (D3).

**Preliminary-range computation** (consistent with the explicit-`--range` /
`GIT_ROOT_AUDIT` handling already in Step 1 + Step 2):

1. If `--range` was passed → use it verbatim.
2. Else if `review.md` exists and has a `<!-- audited-at: <SHA> -->` marker → use
   `<SHA>..HEAD` (the same latest-stamp parse Step 2 uses, but computed here for the
   pre-scaffold check).
3. Else → `origin/main..HEAD`.

When Step 1 resolved `$GIT_ROOT_AUDIT` (out-of-cwd / explicit-`--range` path), run the
helper's `git` reads against that root: pass the range through, but ensure the helper
sees the worktree's commit graph. Since the range is resolved SHAs and the helper shells
`git diff --name-only "$RANGE"`, route it as `git -C "$GIT_ROOT_AUDIT"` by invoking the
helper from `$GIT_ROOT_AUDIT` (or, simpler, the orchestrator computes the name-only set
itself via `git -C "$GIT_ROOT_AUDIT" diff --name-only "$RANGE"` and feeds the helper —
but the canonical wiring is to call `bash kit/scripts/preship/audit-tracker-only.sh
"$RANGE"` from the audit git-root). The SKILL.md prose names the helper path explicitly.

**On exit 0 (tracker-only):**

- Print: `✓ audit short-circuited: diff is tracker-only, no source surface to audit.`
- Exit 0 **WITHOUT**: scaffolding the stub (substep 4), invoking the sub-skills (Step 3),
  or appending a `## Audit N` section (Step 4) / committing (Step 5).

**On exit 1 (has source surface):** fall through to the normal Step 1 substep 4 →
Step 2 → … flow unchanged.

**Ordering note for the prose:** the branch=main refusal (substep 5) and the explicit-
`--range` carve-out stay where they are; the short-circuit slots in as the new substep
that runs after dir-resolution (substeps 1-3) and BEFORE the stub scaffold (old substep
4). Renumber substeps if the prose reads cleaner that way, but the load-bearing
invariant is: **short-circuit fires before any scaffold/append/commit side-effect.**

## Files to create / modify

**Create:**

- `kit/scripts/preship/audit-tracker-only.sh` — the classifier helper (contract above).
- `kit/tests/util-audit-tracker-only.bats` — behavior tests (matrix below).

**Modify:**

- `.claude/skills/devshop/check-docs-and-tests/SKILL.md` — Step 1 short-circuit clause
  (symlink `.claude/skills/ak-check-docs-and-tests/SKILL.md` resolves to the same file).
- `kit/tests/util-check-docs-and-tests.bats` — grep test for the short-circuit clause.
- `kit/docs/guide/workflow.md` — concise note in the `/ak-check-docs-and-tests` row of
  the skill-map table (≈ line 480) OR the Phase 5.8 prose (≈ line 302), whichever reads
  cleaner: the orchestrator short-circuits tracker-only diffs via
  `audit-tracker-only.sh` rather than scaffolding an orphan `review.md` stub. This
  doubles as the Layer 1 docs-coverage pairing for the new `.sh` (`kit/scripts/preship/**
→ any guide/*.md`) and the touched `SKILL.md` (`.claude/skills/**/SKILL.md →
guide/workflow.md OR CLAUDE.md`) — staging `workflow.md` satisfies both surfaces in one
  doc. (If on reading it lands better in `conventions.md`, that doc is equally valid for
  both pairings — confirm at implement time against `check-docs-coverage-devshop.sh`'s
  surface map; `workflow.md` is the default.)
- `kit/TODOS.md` — delete the orphan-stub entry (lines ~348-362).

## Tests

`kit/tests/util-audit-tracker-only.bats` — behavior tests over a temp git-repo fixture
(`create_test_repo` + a two-commit helper modeled on `util-path-classifier.bats`'s
`two_commit_diff`, so `HEAD~1..HEAD` is a real range). Cases (D2 matrix):

1. **tracker-only diff → exit 0** — change only `kit/TODOS.md` (and/or `PLAN.md`,
   `kit/version`) between the two commits. Assert `status -eq 0`, output names the
   short-circuit.
2. **mixed tracker + source diff → exit 1** — change `kit/TODOS.md` AND
   `kit/scripts/foo.sh` (or `kit/docs/guide/x.md`). Assert `status -eq 1` (a single
   source path defeats the short-circuit).
3. **pure source diff → exit 1** — change only `kit/scripts/foo.sh`. Assert `status -eq
1`.
4. **guide-doc-only diff → exit 1 (NOT short-circuited)** — change only
   `kit/docs/guide/workflow.md`. Assert `status -eq 1` — guide docs are auditable
   source surface (D2 rationale: `/ak-docs-review` audits them).
5. **test-only diff → exit 1** — change only `kit/tests/util-x.bats`. Assert `status
-eq 1` (tests are auditable; `/ak-tests-review` reviews them).
6. **friction-log-only diff → exit 0** — change only `kit/FRICTION-LOG.md`. Assert
   `status -eq 0` (friction log is a pure tracker, D2).
7. **empty diff → exit 0** — a range with no changed paths (e.g. `HEAD..HEAD`). Assert
   `status -eq 0` (no source surface; Gotchas decision point).
8. **usage error → exit 64** — no range argument. Assert `status -eq 64`, output
   `Usage:`.

`kit/tests/util-check-docs-and-tests.bats` — add one grep test:

- `@test "Step 1 documents the tracker-only short-circuit (helper + exit-0 / no-scaffold)"`
  — assert the SKILL.md grep-matches `audit-tracker-only.sh`, the short-circuit message
  (`audit short-circuited`), and a no-scaffold assertion (e.g. `WITHOUT` + `scaffold`).

No new tests for the guide-doc note (prose) or the TODOS deletion (tracker hygiene).

## Dependencies

- `kit/tests/helpers/setup.bash` — `create_test_repo`, `stage_file` (fixture plumbing;
  no change needed).
- `git` (`diff --name-only`) — already a hard dependency of the test harness.
- mawk/awk — NOT a dependency if the `case`-per-line implementation is chosen (preferred).
  If the grep-`-E` form is chosen, `grep` only (no awk). No new toolchain.
- The orchestrator's existing Step 1 / Step 2 range machinery (`--range`,
  `<!-- audited-at -->` parse, `GIT_ROOT_AUDIT`) — reused, not duplicated.

## Task order

Dependency-ordered, ~3 tasks (matches the Phase 0 tracker). Each task is one atomic
commit with tests written alongside (no code without tests).

### Task 1 — Helper script + bats behavior tests

- Create `kit/scripts/preship/audit-tracker-only.sh` per the Helper contract (3-line
  header, `set -euo pipefail`, usage block, `case`-per-line tracker matcher, exit
  0/1/64 contract, empty-diff → 0, spec back-ref).
- Create `kit/tests/util-audit-tracker-only.bats` with the 8-case matrix above (temp
  git-repo fixture; two-commit helper for real ranges).
- Run `pnpm turbo run test:unit` (or the bats target) — all 8 green.
- **Commit:** `feat(preship): classify tracker-only audit ranges to skip orphan stubs`
  (script + bats only — no SKILL.md yet, so the docs-coverage hook may fire on the new
  `kit/scripts/preship/**` surface; satisfy it by staging the guide note in THIS commit
  OR bypass with a named `devshop.docsCoverageReason` if the implementer prefers to keep
  the guide note in Task 3 — implementer's call, but the cleaner path is to fold the
  guide-doc note into Task 1 so the surface is paired in-commit).

  > Implementation note: `check-docs-coverage-devshop.sh` fires on
  > `kit/scripts/preship/**` and accepts any `guide/*.md` (or the pre-ship SKILL.md). To
  > avoid a bypass trailer, the simplest path is to move the guide-doc note (Task 3's
  > first bullet) INTO Task 1's commit. The task ordering below keeps it in Task 3 for
  > narrative clarity; the implementer may pull it forward — note the choice in the
  > commit body.

### Task 2 — Wire short-circuit into SKILL.md Step 1 + grep test

- Edit `.claude/skills/devshop/check-docs-and-tests/SKILL.md § Step 1`: add the
  short-circuit substep (preliminary-range computation → call
  `audit-tracker-only.sh "$RANGE"` → on exit 0 print the message + exit 0 without
  scaffold/sub-skills/append; on exit 1 fall through). Keep it consistent with the
  explicit-`--range` + `GIT_ROOT_AUDIT` handling already in Step 1.
- Edit `kit/tests/util-check-docs-and-tests.bats`: add the grep test asserting the
  short-circuit is documented (names the helper + exit-0 / no-scaffold).
- Run the bats suite — the new grep test green, all pre-existing
  `util-check-docs-and-tests.bats` tests still green.
- **Commit:** `feat(audit): short-circuit tracker-only diffs before stub scaffold`
  (SKILL.md change pairs with `guide/workflow.md` OR CLAUDE.md per the
  `.claude/skills/**/SKILL.md` surface — if the guide note is still in Task 3, this
  commit needs the doc co-staged or a named bypass; see Task 1's implementation note).

### Task 3 — Guide-doc note + close TODOS entry + cross-ref unwind

- Add the concise note to `kit/docs/guide/workflow.md` (the `/ak-check-docs-and-tests`
  row or Phase 5.8 prose) documenting the tracker-only short-circuit + the helper. (If
  pulled into Task 1 per the implementation note, this bullet is already done — Task 3
  then just closes the tracker.)
- Delete the orphan-stub entry from `kit/TODOS.md` (lines ~348-362), per CLAUDE.md
  "Closing TODO / ROADMAP entries when a fix ships."
- `grep -rn "orphan stub" / "ak-merge-devshop-doc-only-runs-2026-05-15"` across `kit/`,
  `CLAUDE.md`, `.claude/skills/` — confirmed Phase 0 finding: the ONLY references are
  in the `kit/TODOS.md` entry itself (no external cross-refs to unwind). Re-verify at
  implement time; unwind anything new that appears.
- **Commit:** `docs(audit): note tracker-only short-circuit + close orphan-stub TODO`
  (guide doc + TODOS deletion).

## Gotchas

- **The short-circuit MUST precede the scaffold (D3).** The orphan stub IS the Step 1
  substep-4 scaffold. If the classifier runs after it, the orphan is already on disk. The
  grep test in Task 2 guards the documentation; the load-bearing ordering lives in the
  SKILL.md prose — keep the "BEFORE substep 4 / WITHOUT scaffolding" wording explicit.
- **Empty-diff → exit 0 is a deliberate decision point.** An empty `git diff
--name-only` means no changed paths → no source surface → short-circuit (exit 0). The
  alternative (exit 1 on empty, forcing the orchestrator into its normal flow) would
  re-introduce a scaffold for a zero-delta range. Exit 0 is conservative and matches
  "nothing to audit → don't scaffold." In practice the orchestrator's idempotence guard
  (Step 2/7: `SHA == HEAD` → no-op) intercepts the truly-empty case upstream, so this
  branch is belt-and-suspenders — but the helper must define it, and the bats suite
  pins it (case 7).
- **Guide docs and tests are NOT trackers (D2).** The single most likely mis-implementation
  is widening the tracker set to include `kit/docs/guide/**` or `kit/tests/**` — that
  would suppress exactly the changes `/ak-docs-review` and `/ak-tests-review` exist to
  audit. Cases 4 + 5 in the bats suite are the regression guard; do not relax them.
- **`kit/notes/**`IS a tracker,`kit/docs/guide/**` is NOT** — `kit/notes/` is matched as a
  directory prefix (build blueprints / historical notes carry no auditable runtime
  surface), but it sits adjacent to `kit/docs/` which is NOT a tracker. The matcher
  anchors `kit/notes/*` (dir prefix) but `kit/docs/CHANGELOG.md` (exact) — do not loosen
  the CHANGELOG match to `kit/docs/` or guide docs get swept in.
- **File trackers are matched EXACTLY, not by prefix** — `kit/TODOS.md`, `kit/ROADMAP.md`,
  and `kit/version` are individual files, so the `case` arms anchor them exactly
  (`kit/TODOS.md|kit/ROADMAP.md|kit/notes/*|kit/version`). Only `kit/notes/` is a real
  directory prefix. A loose prefix form (`kit/TODOS*|kit/version*`) over-matches: a future
  `kit/versioning.md`, `kit/ROADMAPER`, or `kit/TODOS-archive.md` would falsely
  short-circuit as tracker-only and skip a real audit. Gate 5 + Gate 6 cross-confirmed
  this as a low-severity finding; the exact anchoring closes it. The boundary bats cases
  (`kit/versioning.md`, `kit/ROADMAPER` → exit 1; `kit/notes/**` → exit 0) are the
  regression guard — do not relax them back to prefix globs.
- **Symlinked SKILL.md** — `.claude/skills/ak-check-docs-and-tests/SKILL.md` is a symlink
  to `.claude/skills/devshop/check-docs-and-tests/SKILL.md`. Edit the canonical file;
  the symlink follows. Don't edit "both" — that's one file.
- **Docs-coverage pairing on the helper commit** — `kit/scripts/preship/**` requires a
  paired `guide/*.md` or the pre-ship SKILL.md in the same commit
  (`check-docs-coverage-devshop.sh`). Task 1 ships the helper; either co-stage the guide
  note or use a named `devshop.docsCoverageReason` bypass. The cleanest path is to fold
  the guide note into Task 1 (noted in the task body). Do NOT generic-bypass — the
  Sonnet-routed reviewer rejects generic reasons.
- **Out-of-cwd range (GIT_ROOT_AUDIT)** — when the orchestrator drives the audit from
  `/devshop` on `main` with an explicit `--range` (the `/ak-merge-devshop` Phase 1.1
  path), the helper's `git diff` must read the worktree's graph, not `/devshop`'s. The
  range is resolved SHAs so the diff is cwd-independent — but the SHAs must exist in the
  audited git-root. Invoke the helper from `$GIT_ROOT_AUDIT` (or feed it a
  `git -C "$GIT_ROOT_AUDIT" diff --name-only "$RANGE"` set). The SKILL.md prose must say
  this explicitly so a future reader doesn't assume cwd.
- **bats fixture must produce a real range** — `git diff --name-only HEAD~1..HEAD`
  requires two commits. Use the `two_commit_diff`-style helper from
  `util-path-classifier.bats`; a single-commit repo has no `HEAD~1` and the test would
  error spuriously rather than assert the verdict.

## Acceptance

- [ ] `kit/scripts/preship/audit-tracker-only.sh` exists with a 3-line What/Why/Does NOT
      header, `set -euo pipefail`, and the documented exit-0/1/64 contract.
- [ ] `audit-tracker-only.sh <range>` exits 0 for a tracker-only diff, 1 for any diff
      with a non-tracker (source) path, 1 for guide-doc-only and test-only diffs, 0 for
      friction-log-only and empty diffs, 64 on missing argument.
- [ ] `kit/tests/util-audit-tracker-only.bats` covers all 8 matrix cases and passes
      under the bats suite.
- [ ] `check-docs-and-tests/SKILL.md § Step 1` documents the short-circuit: names
      `audit-tracker-only.sh`, computes a preliminary range (`--range` → audited-at SHA
      → `origin/main..HEAD`), and on tracker-only prints the `✓ audit short-circuited`
      message + exits WITHOUT scaffolding the stub, invoking sub-skills, or appending a
      section. The short-circuit is positioned BEFORE the stub-scaffold substep.
- [ ] `kit/tests/util-check-docs-and-tests.bats` has a passing grep test asserting the
      short-circuit is documented (helper name + exit-0 / no-scaffold).
- [ ] A guide doc (`kit/docs/guide/workflow.md` by default) carries a concise note on
      the tracker-only short-circuit + helper, satisfying the Layer 1 docs-coverage
      pairing for the new `.sh` and the touched `SKILL.md`.
- [ ] The orphan-stub entry is deleted from `kit/TODOS.md`; `grep` confirms no dangling
      `orphan stub` / `ak-merge-devshop-doc-only-runs-2026-05-15` cross-references remain
      outside the deleted entry.
- [ ] Full bats suite green; commits land per-task with tests alongside.
