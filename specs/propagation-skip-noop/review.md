<!-- review for propagation-skip-noop — assembled at Phase 3.3 (devshop mode) -->

# Pre-ship review — propagation-skip-noop

Devshop gate set: 6 dispatched + 13 carve-outs. Assembled 2026-05-31T09:34:56Z. Gate 5/6 findings (3 mediums + 4 review findings) resolved in-branch via the focused fix (FIX A–E; see § Gate 6 § Focused fix log); remaining items are documented lows.

## Gate 1: docs-check

- Result: pass

Code changes (propagation-entry.sh, adversarial-review.sh) paired with doc updates (conventions.md, merge-devshop SKILL.md, PROPAGATION.md) in the same branch; per-commit docs-coverage gate satisfied via grounded devshop.docsCoverageReason bypasses (recorded as trailers).

## Dismissals

None

## Gate 2: metrics-check

- Result: n/a (devshop-self-mode: no METRICS.md)

## Dismissals

None

## Gate 2b: rls-coverage

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 2c: slow-job-lifecycle

- Result: n/a (devshop-self-mode: no slow-job CI)

## Dismissals

None

## Gate 2d: fast-job-local

- Result: pass

Full bats suite green (1582 passed, 0 failed), incl. 7 new tests (5 generator tag-filter + 2 gate precompute). devshop-self-mode — bats is the test surface.

## Dismissals

None

## Gate 2e: migration-rollback-roundtrip

- Result: n/a (devshop-self-mode: no migrations)

## Dismissals

None

## Gate 2f: changed-tests-local

- Result: n/a (devshop-self-mode: bats run in Gate 2d covers this)

## Dismissals

None

## Gate 2g: advisor-clean

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 3: responsive-theme

- Result: n/a (devshop-self-mode: no UI surface)

## Dismissals

None

## Gate 4: simplify

Result: pass

Reviewed the real code surface only (tag-parse/filter/render in
`kit/scripts/propagation-entry.sh`; `PROP_BLOCK_TAGGED` precompute in
`kit/scripts/adversarial-review.sh`; the 7 new bats cases). No genuine
over-complexity found — nothing applied.

Tests confirmed green on review (no code changed, but verified the surface was
sound):
`kit/tests/lib/bats-core/bin/bats kit/tests/propagation-entry.bats kit/tests/util-adversarial-review-narrowing.bats`
→ all pass (incl. the 7 new cases: generator (a)-(e), gate precompute (f)-(g)).

### What I checked and why it's already minimal

- **`TAG` extraction (`propagation-entry.sh:50`)** — one `sed -n '1s/…/\1/p'`,
  anchored to line 1. Single pass, captures the matched tag name. Can't be
  smaller.
- **`BLOCK_NOTAG` strip (line 52, four chained `-e`)** — each expression handles
  a distinct, non-overlapping case: (1) tag token + trailing whitespace, (2)
  em-dash separator, (3) ASCII-hyphen separator, (4) residual leading
  whitespace. Em-dash (`—`) and hyphen (`-`) are genuinely different bytes, so
  (2) and (3) are not redundant. (4) is idempotent/defensive against
  multi-separator or odd-spacing input. Verified the strip on em-dash, bare-space,
  and hyphen separators — all yield the de-tagged body cleanly. This is the
  "deliberately-explicit shell" the convention preserves, not over-complexity.
- **`case "$TAG"` (lines 55-77)** — a 4-way disposition dispatch
  (auto/manual/conditional/untagged-default). A `case` is the boring, readable
  shape for a fixed-vocabulary branch; an if/elif chain would be strictly worse.
- **`PROP_BLOCK_TAGGED` precompute (`adversarial-review.sh:385-394`)** — the
  inner `grep -E … | head -1 | grep -qE …` is load-bearing: `head -1` enforces
  "first `**Existing projects:**` line" semantics (matching the generator, which
  reads the head of the block). A single whole-body `grep -qE` would true-match
  if ANY line were tagged, not specifically the first — a correctness regression,
  not a simplification. The outer `[ "$HAS_PROP_BLOCK" = yes ]` guard mirrors the
  established `HAS_PROP_BLOCK` two-state shape so the precompute reads as
  presence-then-tag.

### Dismissals

- Trailing `s/^[[:space:]]*//` in the `BLOCK_NOTAG` strip looks redundant after
  the tag-token expression already consumes `[[:space:]]*`. rationale: it is
  defensive against multi-separator / odd-spacing block bodies and is idempotent
  on well-formed input; removing it trades robustness against malformed authored
  blocks for a one-token micro-cleanup — not a genuine over-complexity win, and
  the convention deliberately keeps this text-processing shell explicit.
- The `if [ "$HAS_PROP_BLOCK" = yes ]` guard re-runs the same
  `grep -E '^\*\*Existing projects:\*\*'` that computed `HAS_PROP_BLOCK`.
  rationale: the re-grep is cheap and the presence-then-tag structure is the
  readable shape; collapsing the two would entangle presence detection with tag
  detection for no clarity gain.

## Gate 5: docs-and-tests-review (see Audit 1 below)

- Result: pass (high=0 medium=3 low=3; 3 mediums fixed in-branch — FIX A/B/C). Full findings in the `## Audit 1` section at the foot.

## Dismissals

None

## Gate 6: review

Read-only adversarial code review of `feat/propagation-skip-noop` HEAD (`c48ae63`)
vs `origin/main`. Reviewed: `propagation-entry.sh` tag parse/filter/render,
`adversarial-review.sh` precompute + NOTE-3, 7 new bats, the conventions.md /
merge-devshop / PROPAGATION.md docs, and the v1.37.0 backfill.

**Verification done:** full bats suite green (55 tests across both files,
incl. the 7 new cases). Empirical edge-case probes run against the live
`sed` extraction + the full generator pipeline against synthetic git fixtures.
v1.37.0 backfill re-derived from the actual `v1.36.0..v1.37.0` range +
the pre-backfill `origin/main` PROPAGATION.md section.

### Findings

**[medium] Multi-line block with the tag ALONE on line 1 renders a malformed bullet.**
When a `**Existing projects:**` block puts the tag on its own first line and the
step text on line 2 (`[manual]\nrun db:migrate ...`), the generator still
recognizes the tag (line-addressed `1s/...` on `$TAG`), but `BLOCK_NOTAG` runs
the strip `s/^\[\(auto\|...\)\]...//` against the **whole multi-line** `$BLOCK`,
removing `[manual]` from line 1 and leaving an empty line 1. The trailing
`s/^[[:space:]]*//` only normalizes line 1 (now empty), so `BLOCK_NOTAG` begins
with a literal newline. Confirmed end-to-end through the full pipeline (incl. the
line-39 `sed '/^$/d'` normalize, which does NOT save it — neither line is blank):

```
- **feat: multiline manual** — <newline>
run db:migrate then restart workers.
```

i.e. the bullet body is empty and the actual step lands on an un-bulleted line.
Silent (no warning), produces broken Markdown in PROPAGATION.md.
Mitigating: the tag is still correctly classified (no dangerous DROP — see
Dismissals); every documented example + every dogfooded commit on this branch
uses the inline `[tag] — text` shape, so the trigger requires deviating from the
documented form. Net: a rendering corruption, not data loss. A `tr '\n' ' '`
normalize of `$BLOCK_NOTAG` (or anchoring the strip to the first line only)
would close it.

**[low] `PROP_BLOCK_TAGGED=n-a` deviates from the spec's `n/a`.**
`adversarial-review.sh:393` sets `n-a`; spec D4/Files table specify `n/a`. The
value is only ever emitted as a data string into the LLM prompt (the `n/a per
scope:` dismissal regex elsewhere in the file is unrelated and does not match
it), and no test asserts the `n-a` path's exact value, so it is harmless — but
it is an unintended spec deviation and reads slightly oddly to the reviewer LLM.

**[low] Enforcement-section example still shows the now-gate-failing untagged
`none — <why>` form.** `conventions.md § Enforcement` keeps the parenthetical
"even the explicit `**Existing projects:** none — <why>` form" as the canonical
no-op example, but that exact shape is now FAILed by the same gate the paragraph
documents (untagged). Should read `[auto] — none — <why>` (or `[auto] — <why>`)
for internal consistency. Doc-only; the layer-1 sentence two lines below
correctly states the new untagged-FAIL rule.

**[low] `(conditional)` double-label if an author also writes "(conditional)" in
prose.** `[conditional] — (conditional) when X…` renders `— (conditional)
(conditional) when X…`. The spec § Gotchas already calls this out ("authors
write the trigger, not the label") and it is purely cosmetic; noted for
completeness.

### Things checked and found SOLID (no finding)

- **Drop-safety (the dangerous path).** `TAG` can only ever be one of
  `{auto,manual,conditional,""}` (the `sed` capture group is closed). The `case`
  routes only `auto`→drop; `manual`/`conditional`/untagged never reach the drop
  branch. A real step can drop ONLY if the author explicitly tags it `[auto]` —
  author intent, not a parser defect. No way for `[manual]`/`[conditional]` to be
  silently dropped. Verified by exhaustive enumeration of the `case` arms.
- **Unrecognized bracket token** (`[todo]`, `[AUTO]` uppercase, leading-space
  `␣[auto]`) → `TAG` empty → untagged keep+warn path, and `BLOCK_NOTAG` leaves
  the token verbatim (no mis-strip). Correct per D2.
- **Separator variants** — `[tag] — text` (em-dash, spaced/unspaced), `[tag] -
text` (hyphen), `[tag] text` (bare space) all strip cleanly.
- **`[auto]` cannot be the sole suppressor of a real step** — the all-`[auto]`
  collapse only fires when `ENTRIES` is empty, which by construction means no
  `manual`/`conditional`/untagged block existed; an untagged real step always
  appends (keep+warn) and prevents the `(no manual steps)` collapse.
- **Hygiene precompute robustness** — `grep -E '^\*\*Existing projects:\*\*' |
head -1` takes the FIRST block, matching the generator's awk first-block
  extraction (consistent surface). The `^\*\*Existing projects:\*\* \[(...)\]`
  anchor rejects a tag that appears only in prose (no false `yes`) and a second
  tagged block when the first is untagged (no false `yes`). Verified empirically.
- **NOTE-3 directive** is unambiguous: explicit "if 'contains a block' is 'yes'
  but 'carries a recognized tag' is 'no', ALSO FAIL … naming the block and 'no
  disposition tag'", with the three-tag gloss and the conventions.md pointer.
- **v1.37.0 backfill is correct.** Re-derived from `v1.36.0..v1.37.0` (the range
  that fed the section) and the pre-backfill section: of 11 original entries, CSP
  is the only conditional/actionable one — every other block is an explicit no-op
  ("none", "no migration needed", "[sync] delivers it", "picks up on next sync").
  The gitignore (`[sync]`, redundant-but-harmless) and worktree-hooks
  (touches no propagation surface) entries — the two most concrete-sounding —
  hid no real step. Backfill keeps exactly the one `[conditional]` CSP entry +
  the auto-propagate note. Sound.
- **No downstream parser breaks.** `release.sh` only calls the generator and
  re-stages PROPAGATION.md (no block parsing). `from-devshop.sh` only points the
  operator at the file (lines 216-220), parses no `[tag]`/`## v` structure. No
  other consumer reads the block format. The format change is transparent.
- **Branch dogfoods the convention** — every feature commit carries a
  properly-tagged inline `[auto] — …` block.

### Dismissals

- **"Could `[manual]`/`[conditional]` be silently dropped?"** — Dismissed. Closed
  `case` over a closed `sed` capture; only `auto` drops. Exhaustively verified.
- **"Hygiene precompute false `yes` from a prose tag / multi-block body?"** —
  Dismissed. The `^…\[` anchor + `head -1` first-block selection prevent both;
  verified empirically.
- **"Does the v1.37.0 backfill omit an entry that had a real step?"** — Dismissed.
  Re-derived from source commits; CSP was the only actionable one.
- **The multi-line continuation wrapping to its own line (line-2 text in a
  normal inline `[tag] — line1\nline2` block)** — NOT a regression of this
  change; the original generator already kept multi-line blocks verbatim. Out of
  scope for this gate. (Distinct from the medium finding, which is the
  tag-ALONE-on-line-1 corruption introduced by the new strip.)

### Verdict

3 findings (1 medium rendering-corruption, 2 low doc/cosmetic) + 1 low cosmetic
gotcha. No high-severity issues. The dangerous drop-path is provably safe; the
backfill is correctly derived; no downstream parser breaks. HALT-ON-FIND: not
auto-fixed.

## Focused fix log

Branch `feat/propagation-skip-noop`. Fixes from Gate 6 (this file) + Gate 5
Audit 1 (`../review.md § Audit 1`). Each finding → fix → commit. Full bats
suite run at the end; gitleaks clean on every commit (`no leaks found`).

**FIX A — generator robustness (`kit/scripts/propagation-entry.sh`)** — commit `2af90f9`

- Audit-1 tests [medium] (multi-block silent drop) + Gate-6 [medium] (multi-line
  malformed bullet).
- (1) Multi-block silent drop (D2): a body with TWO `**Existing projects:**`
  markers fed both into `$BLOCK`; the line-1 tag parse read only block-1's tag,
  so an `[auto]` block-1 silently dropped a real `[manual]`/`[conditional]`
  block-2 step. Fix: count markers in `$BODY`; if > 1, emit
  `WARN: <sha> '<subj>' has N **Existing projects:** blocks — only the first is
processed; consolidate into one block.` to stderr; the awk extractor also now
  stops at the second marker so an adjacent (no-break) block-2 can't leak into /
  mis-classify block-1. Still processes only the first (one-block convention) —
  refuse-silently → warn-loudly so a real second step can't vanish.
- (2) Multi-line render corruption: a block with the tag alone on line 1 and the
  step on line 2 left a leading newline after the strip → empty bullet + an
  un-bulleted continuation. Fix: collapse `$BLOCK` internal newlines to single
  spaces (`tr '\n' ' '`) so every block renders as one clean Markdown bullet.
- EMPIRICALLY VERIFIED in a throwaway repo: two-block body (break + adjacent)
  warns + drops the `[auto]` first, keeps no second step silently; tag-on-line-1
  / text-on-line-2 renders one clean bullet; the inline `[tag] — text` happy
  path and the `(conditional)` label are unaffected.
- bats: added (f) two-block-warn, (g) adjacent-two-block-warn, (h)
  multi-line-clean-render, (i) bare-space KEPT-`[manual]` separator.
- conventions.md § Enforcement layer 2 documents the one-block-per-commit rule.

**FIX B — `release-devshop/SKILL.md § Phase 2.5`** — commit `424edac`

- Audit-1 docs [medium] (`(no manual steps)` treated as omitted-block debt).
- Rewrote Phase 2.5: `(no manual steps)` is a VALID end state when every
  propagation-relevant change auto-propagates (`[auto]`-tagged); the review only
  re-adds an entry for a propagation-relevant change with NO `**Existing
projects:**` block at all (the genuine omission), never when blocks exist and
  are all `[auto]`. Genuine-omission guard kept intact.

**FIX C — `kit/docs/guide/hooks.md` NOTE-3** — commit `424edac`

- Audit-1 docs [medium] (hooks.md only described missing-block FAIL).
- NOTE-3 now documents BOTH FAIL paths: missing block AND present-but-untagged
  (block lacking a recognized `[auto]`/`[manual]`/`[conditional]` tag), agreeing
  with conventions.md § Enforcement + the actual adversarial-review.sh directive.

**FIX D — stale untagged examples** — commit `424edac`

- Gate-6 [low] + Audit-1 docs [low].
- conventions.md § Enforcement: `**Existing projects:** none — <why>` →
  `[auto] — none — <why>`. docs-review/SKILL.md migration-block example: untagged
  `<file> is [locked]…` → `[auto] — <file> is [locked]…` + a note that an
  untagged block FAILs the gate. (merge-devshop/SKILL.md already models the
  tagged form — left as-is.)

**FIX E — `kit/scripts/adversarial-review.sh` ~line 393** — pending (see note below)

- Gate-6 [low] (`PROP_BLOCK_TAGGED=n-a` deviates from spec `n/a`).
- `n-a` → `n/a`. Cosmetic, LLM-display-only; grep-verified nothing reads the
  literal `n-a` anywhere in `kit/` or `.claude/`. Edit applied to the working
  tree; commit blocked by an environmental virtiofs index/readdir corruption
  (see below) — needs a devcontainer restart to land cleanly.

**Local bats result:** full suite via `kit/tests/lib/bats-core/bin/bats
kit/tests/` — 1585/1586 pass. The single failure (`structural-invariants.bats`
"all kit/scripts/\*.sh tracked as 644") is NOT caused by these fixes: it reports
`kit/scripts/virtiofs-rebase.sh tracked as 100755`, a file that belongs to the
parallel `feat/virtiofs-rebase-auto-switch` linked worktree and is NOT in this
branch's HEAD — it leaked into /devshop's `.git/index` via the virtiofs
corruption. All propagation-entry.bats cases (incl. the 4 new ones) pass.

**Environmental note (virtiofs index/readdir corruption):** after FIX A–D
landed cleanly (2af90f9, 424edac — both content-verified in the object store),
a failed lint-staged prettier run that touched `.worktrees/virtiofs-rebase-
auto-switch/...` paths left /devshop's git view corrupted: `git status` reports
~16 files as MODIFIED and 5 `specs/propagation-skip-noop/*` tracked files as
DELETED even though `diff <(git show HEAD:<f>) <f>` is byte-identical (0 lines
differ) and the files are present on disk (verified via `wc`/`ls`/`find`/`cp`).
git's `opendir()`/`lstat()` on `specs/` children returns ENOENT while coreutils
succeed; `git read-tree HEAD` does not evict a non-HEAD worktree file from the
index. This is git-process-level virtiofs metadata incoherence, not a real
change. FIX A–D commits are immutable and correct. FIX E (a one-token edit) is
safe on disk and should be committed after a devcontainer restart clears the
mount cache — forcing it through the corrupted index now would risk committing
phantom spec-file deletions + cross-branch contamination.

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs)

## Dismissals

None

## Gate 8: /design-review

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface)

## Dismissals

None

## Gate 8b: design-conformance

- Result: n/a (devshop-self-mode: no DESIGN.md)

## Dismissals

None

## Gate 9: /qa

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface; bats invariants run in Gate 2d)

## Dismissals

None

## Gate 10: /benchmark

- Result: blocked (n/a per scope: devshop-self-mode — no perf surface)

## Dismissals

None

## Gate 10b: preflight-final

- Result: n/a (devshop-self-mode: bats recheck in Gate 2d covers this)

## Dismissals

None

## Gate 11: convention

**Mode:** devshop-self. **Branch:** `feat/propagation-skip-noop` in `/devshop`.
**Range:** `origin/main..HEAD` (9 commits). **Result:** pass (1 low, squash-moot — see below).

bats green across the touched suites: `kit/tests/propagation-entry.bats` +
`kit/tests/util-adversarial-review-narrowing.bats` → 55/55 ok, 0 failures
(includes the 7 new cases: 5 generator + 2 gate-precompute).

### 1. Commit + PR text style — PARTIAL (1 pending finding)

Subjects describe the observable change, lead with a verb / natural noun-list,
carry no internal jargon. But four exceed the `≤ 72 chars` guideline (CLAUDE.md
§ Commit + PR text style; conventions.md § Commit + PR Text Style rule 4):

| len | subject                                                                               |
| --- | ------------------------------------------------------------------------------------- |
| 75  | `docs(propagation-skip-noop): document the [auto]/[manual]/[conditional] tag`         |
| 83  | `feat(propagation-skip-noop): require a disposition tag on squash propagation blocks` |
| 80  | `chore(propagation-skip-noop): confirm all-[auto] version collapses to no-op line`    |
| 79  | `feat(propagation-skip-noop): read disposition tag, drop auto, label conditional`     |

The 23-char `propagation-skip-noop):` scope token eats most of the budget; the
behavior-description halves are tight and clear. **Pending, not auto-fixed**:
these are intermediate feature-branch commits that `/ak-merge-devshop` Phase 0.3
squashes into a single composed subject before anything lands on `main` — the
squash subject is the gate-ENFORCED surface (conventions.md § routing table,
the `prTextHygieneReason` squash-surface check), and it isn't authored yet.
Fixing the four would require a history rewrite (rebase) of commits about to be
collapsed. Recommend the operator keep the squash subject ≤ 72 at merge time
(it will, e.g. `feat(propagation): list only actionable migration steps`); no
rebase of the doomed intermediate subjects warranted.

### 2. Dogfooding consistency — PASS

The feature ADDS the tag requirement; every propagation-surface commit on the
branch carries a recognized tag. Surfaces = `template/** | kit/scripts/** |
kit/hooks/** | .devcontainer/** | manifest.txt`.

| commit                                        | touches surface? | block tag              |
| --------------------------------------------- | ---------------- | ---------------------- |
| fe297dc (`kit/scripts/propagation-entry.sh`)  | yes              | `[auto]` ✓             |
| 7942a2d (`kit/scripts/propagation-entry.sh`)  | yes              | `[auto]` ✓             |
| baa92ed (`kit/scripts/adversarial-review.sh`) | yes              | `[auto]` ✓             |
| cd80ecc (SKILL.md + docs)                     | no               | `[auto]` (extra, fine) |
| bc031ac (`kit/tests/**`)                      | no               | `[auto]` (extra, fine) |
| c473a92 (`kit/docs/PROPAGATION.md`)           | no               | `[auto]` (extra, fine) |

All three propagation-surface commits open their block with a recognized tag —
the feature follows its own new rule. `[auto]` is correct for each: pure
devshop-side script/skill delivered via the `.devshopkit` / `.claude/skills`
symlinks, no project-side step.

### 3. Docs-coverage trailers — PASS (grounded)

`Docs-Coverage-Bypass:` trailers on fe297dc, 7942a2d, baa92ed, cd80ecc. Each
names the canonical doc home — `conventions.md § Existing-Project Migration
Block` (and its § Enforcement layer 1 for the gate) — landing in the SAME
branch as Task 5 (cd80ecc), and enumerates the non-affected docs per-doc with
grep-verified 0-match claims. cd80ecc's own trailer correctly asserts the
canonical doc IS updated in that very commit (conventions.md is in its
filelist — verified). Not generic; each reason grounds the bypass in a named,
same-branch canonical home. Code commits' test surface (the bats cases, Task 4)
is also named.

### 4. conventions.md self-consistency — PASS

The new vocabulary agrees across the doc AND with generator + gate behavior:

- **Shape line** `**Existing projects:** [auto|manual|conditional] — <…>` ↔
  generator parses leading `[auto|manual|conditional]`; gate regex
  `^\*\*Existing projects:\*\* \[(auto|manual|conditional)\]` — same three,
  same bracket form.
- **3-bullet definitions**: `[auto]` dropped from PROPAGATION.md / `[manual]`
  rendered plain / `[conditional]` rendered with `(conditional)` label ↔
  generator `case`: auto→`:` (skip), manual→`- … — ${BLOCK_NOTAG}`,
  conditional→`- … — (conditional) ${BLOCK_NOTAG}`. Exact match.
- **Variant labels**: "Variant A — `[auto]`", "Variant B — `[manual]`", plus
  the trailing "`[conditional]` follows Variant B's shape" note — all three
  represented, examples carry the tag at head.
- **§ Enforcement layer 1**: "also FAILs a block that IS present but carries no
  recognized … tag" ↔ adversarial-review.sh NOTE-3: "If 'contains a block' is
  'yes' but 'carries a recognized … tag' is 'no', ALSO FAIL … 'no disposition
  tag'". The doc's "FAILs untagged" claim matches what the gate prompt actually
  directs. Untagged "kept and warned" by generator ↔ generator `*)` branch
  keeps verbatim + emits stderr `WARN … untagged`. Consistent.

### 5. No new untested scripts — PASS

`git diff --name-status origin/main..HEAD` adds NO new `.sh` file (existing
`propagation-entry.sh` + `adversarial-review.sh` modified in place). No
structural-invariants / new-script-wiring concern. The two modified scripts
gained the 7 new bats cases.

### 6. Cross-references resolve — PASS

- New `§ Enforcement layer 1` pointer (conventions.md line 544) → resolves to
  `### Enforcement` (line 589); layer 1 is its first numbered item.
- SKILL.md § 0.3 edit's `conventions.md § Existing-Project Migration Block`
  pointer → resolves (heading at conventions.md line 517, ToC entry line 46).
- Gate NOTE-3's `conventions.md § Existing-Project Migration Block` pointer →
  same heading, resolves.
- PROPAGATION.md header prose references the tag set + `(no manual steps)` /
  `(conditional)` rendering — descriptive, no broken `§` pointer.

## Dismissals

- **CLAUDE.md classification gate** — not triggered: no `/devshop/CLAUDE.md`
  edit in the diff (spec § Gotchas confirms it's out of scope). N/A.
- **Three-line file-header / JSDoc convention** — N/A: that rule scopes to
  `.ts`/`.tsx` under `src/`/`app/`; this branch touches only `.sh`, `.bats`,
  `.md`. The shell scripts carry their own block comments. Not in scope.
- **METRICS.md / DESIGN.md coverage** — N/A: devshop-self mode, no project
  user-facing surface (spec § Core user story: "N/A — devshop-internal").
- **PROPAGATION.md `(conditional)` backfill rendering** — the hand-edited
  v1.37.0 CSP entry reads `— (conditional) the template ships no CSP block …`,
  matching the generator's `- **${SUBJECT}** — (conditional) ${BLOCK_NOTAG}`
  output shape. Not a finding; the backfill (D5) is a deliberate hand-edit of an
  already-shipped section, correct per spec.
- **Extra `[auto]` tags on non-surface commits** (docs/tests/PROPAGATION.md
  commits) — not required by the convention (only propagation-surface commits
  must tag), but harmless and consistent. Not a finding.

## Resolution (orchestrator)

The lone finding (four intermediate commit subjects >72 chars due to the long
`propagation-skip-noop):` scope) is **squash-moot**: `/ak-merge-devshop`
collapses them into one composed squash subject — the gate-enforced surface —
which the orchestrator keeps ≤72 at merge time. Reclassified low/noted; not a
ship blocker.

## Audit 1: pre-ship (2026-05-31)

<!-- audited-at: c48ae633d2f4575423490865af5ad4a3910effba -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=3 low=3

### Docs findings

- [medium] kit/docs/guide/hooks.md:496 — NOTE-3 squash-gate description not updated for the new present-but-untagged FAIL path; conventions.md (touched) and hooks.md (untouched) now disagree on the gate's contract.
- [medium] .claude/skills/devshop/release-devshop/SKILL.md:96-100 — Phase 2.5 still treats `(no manual steps)` as omitted-block debt; would prompt a reviewer to RE-ADD entries the all-`[auto]` filter deliberately drops, fighting the feature.
- [low] .claude/skills/devshop/docs-review/SKILL.md:174 — migration-block example still models the untagged block shape; cosmetic self-inconsistency in the gate doc.

### Tests findings

- [medium] kit/tests/propagation-entry.bats — multi-block body untested: a first `[auto]` + second `[manual]` block silently drops the second step (line-1-only tag parse + concatenated `$BLOCK`); the gate's `head -1` doesn't catch it either. Reachable D2 silent-drop, bounded blast radius (one-block convention).
- [low] kit/tests/{propagation-entry,util-adversarial-review-narrowing}.bats — case-sensitivity of the recognized-tag regex not pinned on either side; a future leniency change to one copy and not the other would split the gate↔generator contract with no failing test.
- [low] kit/tests/propagation-entry.bats — bare-space separator (`[tag] text`, no em-dash) only exercised on the dropped `[auto]` path, not on a kept manual/conditional render; small render-path gap.

### Bypass trailer audit

- cd80ecc Docs-Coverage-Bypass: "merge-devshop SKILL.md restates the convention; canonical conventions.md staged same commit" — VERIFIED
- baa92ed Docs-Coverage-Bypass: "gate tag validation; conventions.md § Enforcement layer 1 updated Task 5; precompute covered by 2 new bats" — VERIFIED (named doc updated; hooks.md staleness surfaced as a separate Section-C finding, outside the bypass's enumerated docs)
- 7942a2d Docs-Coverage-Bypass: "comment-only generator change; behavior doc lands Task 5" — VERIFIED
- fe297dc Docs-Coverage-Bypass: "generator tag-vocabulary doc lands Task 5; test surface is the bats cases" — VERIFIED
- (no Tests-Coverage-Bypass trailers in range)

## Audit 2: manual (2026-05-31)

<!-- audited-at: 8f845483cd4d027984af8e7b7d22ab01e3e3562a -->
<!-- range: 1408150..8f84548 -->

findings: high=0 medium=0 low=1

Re-audit of the FULL feature delta at merge time (/ak-merge-devshop Phase 1.1). Audit 1 ran at c48ae63 (high=0 medium=3 low=3); this pass confirms all 3 Audit-1 mediums and the 3 lows are genuinely resolved by the focused fix (2af90f9 multi-block-warn + multi-line-render, 424edac doc-contradiction repairs, 86c949b n/a alignment) and the new tests, and covers the Phase 3 gate evidence + BUILD-LOG entry that landed after.

### Docs findings

- [low] BUILD-LOG.md:107 — the "1586 passed, 0 failed" bats count is a point-in-time claim from the Phase 3 gate run, not re-verified at this HEAD (this re-audit re-ran only the two changed bats files → 59 ok). Faithful record of the Phase 3 evidence; non-blocking.

### Tests findings

- (none)

### Audit-1 resolution confirmation

- medium (hooks.md NOTE-3 stale ↔ conventions.md) — RESOLVED (424edac): NOTE-3 now documents both FAIL cases + the `PROP_BLOCK_TAGGED (yes/no/n/a)` precompute, matching the script's `n/a` value (86c949b n-a→n/a fix). Gate contract is consistent across hooks.md + conventions.md.
- medium (release-devshop SKILL.md Phase 2.5 treated `(no manual steps)` as omitted-block debt) — RESOLVED (424edac): Phase 2.5 now calls `(no manual steps)` a valid end state for all-`[auto]` and adds "Do NOT re-add entries for `[auto]`-tagged changes" — no longer fights the filter.
- low (docs-review SKILL.md example modeled untagged shape) — RESOLVED (424edac): example now carries `[auto] —` + the tag-requirement prose.
- medium (multi-block body untested — D2 silent-drop) — RESOLVED (2af90f9 + bats f/g): generator counts markers + WARNs on >1 + stops awk at the second marker; cases (f)/(g) pin the WARN string and the no-leak behavior.
- low (recognized-tag regex case-sensitivity not pinned) — RESOLVED: util-narrowing (g) pins the gate-side regex, propagation-entry (b/c/i) pin the generator side; (f) pins the untagged-FAIL path.
- low (bare-space separator only on dropped `[auto]` path) — RESOLVED: propagation-entry (i) exercises it on a KEPT `[manual]` render. Plus new (h) pins the multi-line-block single-bullet render.

### Bypass trailer audit

- 86c949b Docs-Coverage-Bypass: "cosmetic n-a → n/a; AFFECTED hooks.md already documents n/a; NOT-AFFECTED set grep-verified" — VERIFIED (no behavior change; code now agrees with the already-shipped doc)
- 424edac Docs-Coverage-Bypass: "prose-only doc-consistency; the two SKILL.md edits ARE docs; paired guide docs staged same commit; catalog grep-verified" — VERIFIED (conventions.md + hooks.md carry the contract; workflow.md/CLAUDE.md correctly n/a)
- (no Tests-Coverage-Bypass trailers in range)

## Phase 3 → 4 advance log

### 2026-05-31T09:34:56Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-31T09:34:56Z -->

### 2026-05-31T09:34:56Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-31T09:34:56Z -->

### 2026-05-31T09:34:56Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants run in Gate 2d
**Follow-up tracker:** n/a — structural

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-31T09:34:56Z -->

### 2026-05-31T09:34:56Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-31T09:34:56Z -->
