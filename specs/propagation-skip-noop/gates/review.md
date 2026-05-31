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
