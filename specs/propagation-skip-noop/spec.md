<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: propagation-skip-noop -->
<!-- date: 2026-05-31 -->

# Spec: propagation-skip-noop

**Sources:**

- Operator request (this session) — PROPAGATION.md v1.37.0 carried ~11 bullets, every one a no-op ("none / no migration / picks up on sync"); the doc's stated purpose is "manual steps for existing projects."
- `kit/scripts/propagation-entry.sh` — the generator (copies every `**Existing projects:**` block verbatim, including no-ops; only collapses to `(no manual steps)` when zero blocks exist).
- `kit/scripts/adversarial-review.sh § prTextHygieneReason` (squash surface, dimension (d)) — the propagation-block presence gate (edit target for tag validation).
- `kit/docs/guide/conventions.md § Existing-Project Migration Block` — the block authoring convention (edit target for the tag).
- `.claude/skills/devshop/merge-devshop/SKILL.md § 0.3` — squash-message authoring guidance that names the `**Existing projects:**` block (edit target).
- `kit/tests/propagation-entry.bats` — existing test surface to extend.
- `kit/docs/PROPAGATION.md` — header + the already-shipped v1.37.0 section to backfill.

Make `PROPAGATION.md` list only the propagation steps an operator must actually
take, by reading a deterministic disposition tag (`[auto]`/`[manual]`/
`[conditional]`) at the head of each commit's `**Existing projects:**` block
rather than trying to classify free-form prose (empirically proven unreliable —
the CSP "no migration forced [+conditional step]" and gitignore "no manual step"
blocks are textually indistinguishable to any regex).

---

## Product update

Both blurbs as approved at Phase 0.2. Single source-of-truth — Phase 4.0 copies
Headline into BUILD-LOG `Headline:` and Detail into `Summary:`.

### Headline (user-facing)

Release propagation logs now list only the steps you actually need to take,
instead of a wall of "nothing to do" entries.

### Detail (team-facing)

`propagation-entry.sh` now reads a `[auto]`/`[manual]`/`[conditional]`
disposition tag at the head of each commit's `**Existing projects:**` block and
emits only the actionable (`manual`/`conditional`) ones into `PROPAGATION.md`; a
version whose changes all auto-propagate collapses to a single `(no manual
steps)` line. The audit trail stays in the commit messages. The squash-surface
hygiene gate now requires a recognized tag, and the v1.37.0 section is
backfilled clean.

---

## Decisions (resolved at spec time)

Resolved in Phase 0 with the operator, informed by an empirical Phase-0.2.5 test
that ran a candidate prose-classification heuristic against all 21 historical
`**Existing projects:**` blocks (v1.34.0..HEAD): 5 of 6 "keep" verdicts were
false positives, and the CSP-vs-gitignore openers proved no textual rule can
separate no-op from actionable. That flipped the design from auto-classify to a
deterministic author tag.

### D1: Tag vocabulary + placement

**Decision:** The disposition is the first token of the block, in square
brackets: `**Existing projects:** [auto] — <reason>` / `[manual] — <steps>` /
`[conditional] — <trigger + steps>`. The generator **drops `[auto]`** from
`PROPAGATION.md`, keeps `[manual]` + `[conditional]`.

**Rationale:** The author knows the disposition; the prose doesn't reliably
encode it. Three values cover the observed cases (auto-propagate / act-now /
act-on-trigger). Boring + deterministic over a fragile regex.

### D2: Untagged-block fallback

**Decision:** An `**Existing projects:**` block with no recognized tag is
**KEPT** in `PROPAGATION.md` and a warning is emitted to stderr (mirrors the
existing no-block warning).

**Rationale:** Silently dropping a real step is the dangerous failure mode;
bias to keep. The warning is what drives authors to tag (and the hygiene gate
in D4 enforces it going forward).

### D3: Version with all-`[auto]` blocks

**Decision:** When every block in the version is `[auto]` (or there are no
blocks at all), the generator emits the single `(no manual steps)` line for
that version.

**Rationale:** Extends the generator's existing zero-block behavior to
zero-_actionable_-block — the core payoff (v1.37.0 → one line).

### D4: Hygiene-gate enforcement

**Decision:** Extend `adversarial-review.sh`'s squash-surface propagation-block
check (dimension (d)) to FAIL when a `**Existing projects:**` block is present
but carries no recognized `[auto]`/`[manual]`/`[conditional]` tag, with guidance
on the tag.

**Rationale:** Makes the tag reliably present going forward (without it the
generator falls back to keep-and-warn, re-admitting noise). **Workflow impact:**
future devshop commits touching a propagation surface must tag their block —
operator-approved at Phase 0.

### D5: Backfill already-shipped v1.37.0

**Decision:** Manually edit the v1.37.0 section of `PROPAGATION.md` down to the
one `[conditional]` CSP entry plus a one-line "all other v1.37.0 changes
auto-propagate — no manual steps" note. Pre-tag versions (v1.36.0 and older)
are left as historical.

**Rationale:** Commit history can't be retroactively tagged; `PROPAGATION.md`
is a living doc, so the shipped section is edited directly. Demonstrates the
end state.

### D6: Output rendering

**Decision:** Strip the bracket tag from emitted bullets. Prefix `[conditional]`
entries with a `(conditional)` label; `[manual]` rendered plain.

**Rationale:** The reader sees the actionable text without the machine tag;
conditional/triggered steps are visually flagged so they're not mistaken for
do-now steps.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Files to
     create/modify, Tests, Dependencies, Task order, Gotchas, Acceptance /
     rollout / rollback. Product update + Decisions stay verbatim. This is
     devshop-self-mode: no METRICS.md, no DESIGN.md; the test surface is bats
     (kit/tests/), not vitest/Playwright. -->

## Core user story

N/A — devshop-internal release tooling + docs + bats. No project user-facing
flow added or modified. (`PROPAGATION.md` is an operator-facing doc, not a
product surface; verified by bats + a synthetic generator run, per Acceptance.)

## In scope

1. **Generator tag parse + filter + render** (`kit/scripts/propagation-entry.sh`):
   read the disposition tag at the head of each extracted `**Existing projects:**`
   block; drop `[auto]` blocks from the emitted entry; keep `[manual]` +
   `[conditional]`; strip the bracket tag from rendered text; prefix
   `[conditional]` entries with a `(conditional)` label; keep + warn on an
   untagged block (D1, D2, D6).
2. **All-`[auto]` collapse** (same script): when every block in the version is
   `[auto]` — or there are no blocks at all — emit the single `(no manual steps)`
   line for that version (D3).
3. **Hygiene-gate tag requirement** (`kit/scripts/adversarial-review.sh`,
   `prTextHygieneReason` surface=squash dimension (d)): when a `**Existing
projects:**` block IS present, additionally require a recognized
   `[auto]`/`[manual]`/`[conditional]` tag; FAIL (via the LLM NOTE-3 directive,
   fed a deterministic precompute) when the block is present but untagged (D4).
4. **bats coverage**: new `@test` cases in `kit/tests/propagation-entry.bats`
   (generator behavior) + `kit/tests/util-adversarial-review-narrowing.bats`
   (gate precompute) — see § Tests.
5. **Docs**: tag vocabulary in `kit/docs/guide/conventions.md § Existing-Project
Migration Block`; tag mention in `.claude/skills/devshop/merge-devshop/SKILL.md
§ 0.3`; `PROPAGATION.md` header note about tag-driven filtering.
6. **v1.37.0 backfill** (`kit/docs/PROPAGATION.md`): collapse the shipped
   v1.37.0 section to the one CSP `[conditional]` entry + a one-line auto-propagate
   note (D5).

## Out of scope

- **Retroactively re-tagging commit history.** Commit messages are immutable
  (history can't be re-authored without a force-push, which devshop blocks); the
  tag only exists for commits authored after this lands. The v1.37.0 backfill
  (D5) edits the _rendered doc_, not the underlying commits.
- **Pre-v1.37 PROPAGATION sections** (v1.36.0 and older). They stay as historical
  record; only v1.37.0 is backfilled, as the demonstration of the end state.
- **A new manifest lifecycle tag or a `from-devshop.sh` change.** The disposition
  tag lives only in commit-body `**Existing projects:**` blocks; no manifest or
  sync-script surface is touched.
- **Per-commit pre-commit enforcement of the tag.** Consistent with the existing
  block convention (need-vs-no-need isn't mechanically decidable), the squash-time
  gate is the enforcement point; per-commit hooks stay out of it.

## Files to create/modify

| File                                               | Change                                                                       | Exact edit point                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| -------------------------------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kit/scripts/propagation-entry.sh`                 | Parse tag, filter `[auto]`, render `(conditional)` label, keep+warn untagged | After the `BLOCK=$(echo "$BLOCK" \| sed …)` normalize at **line 39** and before the `if [ -n "$BLOCK" ]` at **line 41**: add a tag-parse step. Extract the leading `[tag]` token from `$BLOCK` (e.g. `TAG=$(printf '%s' "$BLOCK" \| sed -n 's/^\[\(auto\|manual\|conditional\)\][[:space:]]*//p')`-style, but capture which tag matched). Compute `BLOCK_NOTAG` = `$BLOCK` with a leading `[auto]`/`[manual]`/`[conditional]` token (and any following `— `/`-`/whitespace separator) stripped. Then restructure the `if [ -n "$BLOCK" ]` body (**lines 41-43**): **`[auto]`** → skip (do not append to `ENTRIES`); **`[manual]`** → append `- **${SUBJECT}** — ${BLOCK_NOTAG}`; **`[conditional]`** → append `- **${SUBJECT}** — (conditional) ${BLOCK_NOTAG}`; **untagged** (non-empty block, no recognized leading tag) → append the original `- **${SUBJECT}** — ${BLOCK}` (keep verbatim, D2) AND emit a `WARN: … untagged **Existing projects:** block — kept; tag it [auto]/[manual]/[conditional]` to stderr. The empty-block `else` branch at **lines 44-59** (surface-touch missing-block WARN) is unchanged.                                                                                                                                                                                                                                       |
| `kit/scripts/propagation-entry.sh`                 | All-`[auto]` collapse                                                        | **Lines 62-66** (`if [ -n "$ENTRIES" ]` … `(no manual steps)`) need no logic change _given the filter above_ — because `[auto]` blocks never append to `ENTRIES`, a version whose blocks are all `[auto]` leaves `ENTRIES` empty and already falls through to the `(no manual steps)` branch at **line 65**. Confirm this holds (it's the D3 payoff) and add a code comment at line 62 noting that `ENTRIES` is now "actionable entries only" so a future reader doesn't reintroduce auto blocks.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `kit/scripts/adversarial-review.sh`                | Deterministic tag precompute + NOTE-3 extension                              | At the **squash precompute block (lines 350-377)**: after the `HAS_PROP_BLOCK=yes/no` computation (**lines 373-377**), add a deterministic tag check — when `HAS_PROP_BLOCK=yes`, grep the first `**Existing projects:**` line of `$SQ_BODY` for a recognized `^\*\*Existing projects:\*\* \[(auto\|manual\|conditional)\]` and set `PROP_BLOCK_TAGGED=yes/no` (when no block, `PROP_BLOCK_TAGGED=n/a`). Inject it into `$CONTEXT` (**lines 378-428**) as a new data line right after the `Squash body contains an **Existing projects:** block:` line (**line 392**): `Existing-projects block carries a recognized [auto]/[manual]/[conditional] tag: $PROP_BLOCK_TAGGED`. Extend the **NOTE 3 directive (lines 417-428)**: after the existing "block present: no → FAIL" sentence, add "If 'contains a block' is 'yes' but 'carries a recognized tag' is 'no', also FAIL with a line naming the block and 'no disposition tag': every `**Existing projects:**` block MUST open with `[auto]` (auto-propagates — dropped from PROPAGATION.md), `[manual]` (act now), or `[conditional]` (act on a named trigger), because `propagation-entry.sh` reads that tag to decide what reaches the migration log; an untagged block falls back to keep-and-warn and re-admits no-op noise. Per `kit/docs/guide/conventions.md § Existing-Project Migration Block`." |
| `kit/tests/propagation-entry.bats`                 | 5 new generator `@test`s                                                     | Append after the existing behavioral block (after **line 188**, the "mixed blocks" test). Reuse `setup_git_fixture` + the `run bash -c "cd '$FIXTURE_DIR' && bash '$PROP_SCRIPT' …"` harness. See § Tests.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `kit/tests/util-adversarial-review-narrowing.bats` | 2 new gate precompute `@test`s                                               | Append after the existing squash dimension-(d) tests (after **line 308**). Reuse the mocked-`claude` + `$CAPTURED_PROMPT` harness and the `DEVSHOP_HYGIENE_SURFACE=squash` invocation. See § Tests.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `kit/docs/guide/conventions.md`                    | Tag vocabulary                                                               | In `§ Existing-Project Migration Block § Required shape` (**lines 534-557**): add a paragraph + 3-bullet list defining `[auto]` / `[manual]` / `[conditional]` — what each means, when to use it, that the generator drops `[auto]` and keeps the others, and that the squash-time gate (§ Enforcement layer 1) now requires one of the three. Update the `**Existing projects:** <one of the two variants below>` line (**line 537**) to show the tag at the head: `**Existing projects:** [auto\|manual\|conditional] — <…>`. In **§ Enforcement (lines 565-571)**, extend layer 1's sentence (**line 567**) to note it now also FAILs a present-but-untagged block.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `.claude/skills/devshop/merge-devshop/SKILL.md`    | Tag in 0.3 block description                                                 | At the `**Existing projects:**` bullet in § 0.3 (**lines 386-391**): add that the block MUST open with a `[auto]`/`[manual]`/`[conditional]` disposition tag, with a one-line gloss of each, and that `[auto]` blocks are dropped from PROPAGATION.md by the generator (so authors should still write them — the audit trail stays in the commit).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `kit/docs/PROPAGATION.md`                          | Header note + v1.37.0 backfill                                               | **Header (lines 1-5)**: extend the "Auto-generated by `release.sh`" sentence to note that only `[manual]`/`[conditional]`-tagged blocks are listed — `[auto]` blocks auto-propagate and are omitted; a version with no manual steps shows `(no manual steps)`. **v1.37.0 section (lines 7-55)**: delete every entry except the CSP one (**lines 19-26**), retag it as `[conditional]` + render with the `(conditional)` label, and add a single trailing line: `- all other v1.37.0 changes auto-propagate — no manual steps`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |

## Tests

All bats, matching the two files' existing fixture/harness style. No vitest, no Playwright.

### `kit/tests/propagation-entry.bats` (append after line 188)

Each uses `setup_git_fixture` then commits a throwaway tagged-range commit and runs the generator over `v1.0.0..HEAD`, exactly like the existing behavioral tests.

- **(a) `[auto]` block dropped** — commit with body `**Existing projects:** [auto] — picks up on next sync, no migration.` Assert the version section is written, the subject does NOT appear in `PROPAGATION.md`, and the section reads `(no manual steps)` (it's the only commit). Grep: `[[ "$output" == *"(no manual steps)"* ]]` and `[[ "$output" != *"<subject>"* ]]`.
- **(b) `[manual]` kept** — commit with `**Existing projects:** [manual] — run db:migrate after sync.` Assert subject appears, `run db:migrate after sync` appears, and the literal `[manual]` token does NOT appear (tag stripped): `[[ "$output" != *"[manual]"* ]]`.
- **(c) `[conditional]` kept + labelled** — commit with `**Existing projects:** [conditional] — when you add a CSP block, derive img-src from the Supabase origin.` Assert subject appears, the trigger text appears, `(conditional)` label appears, and `[conditional]` token does NOT appear.
- **(d) all-`[auto]` version → `(no manual steps)`** — two commits, both `[auto]` blocks (distinct subjects). Assert section reads `(no manual steps)` and neither subject appears.
- **(e) untagged block → kept + stderr warning** — commit with `**Existing projects:** no migration needed — runs on rebuild.` (no tag). Run with `2>&1`. Assert the subject + text are KEPT in the doc, AND stderr carries a warning naming the untagged block (grep for `WARN` + `untagged`). Pair-assert: the existing line-78 test (untagged `no migration needed` block) still passes — it now exercises the keep-and-warn path, so confirm it's not broken by the change (it asserts the block text appears, which keep-and-warn preserves).

### `kit/tests/util-adversarial-review-narrowing.bats` (append after line 308)

Reuse the mocked-`claude` harness (captures `$CAPTURED_PROMPT`) + `DEVSHOP_HYGIENE_SURFACE=squash` invocation from the existing dimension-(d) tests (lines 217-308).

- **(f) present + untagged block → precompute reports `tag: no` + NOTE-3 FAIL directive inlined** — touch `kit/scripts/foo.sh` on a branch, `MSG_FILE` body carries `**Existing projects:** none — devshop-side script.` (block present, NO tag). Assert `$CAPTURED_PROMPT` contains `contains an **Existing projects:** block: yes`, `carries a recognized [auto]/[manual]/[conditional] tag: no`, and the NOTE-3 untagged-FAIL directive phrase (grep `no disposition tag`).
- **(g) present + tagged block → precompute reports `tag: yes`** — same surface, body carries `**Existing projects:** [auto] — devshop-side script, picks up on sync.` Assert `$CAPTURED_PROMPT` contains `carries a recognized [auto]/[manual]/[conditional] tag: yes`. (Pins the recognized-tag regex so a regression that broke it doesn't silently false-FAIL every tagged squash.)

## Dependencies

None external. `git`, `awk`, `sed`, `grep`, `bash`, `bats` — all already in the
devcontainer and used by the existing scripts/tests.

## Task order

Six atomic commits. bats (Task 4) lands **after** the generator (Tasks 1-2) and
the gate (Task 3) so the new tests have their implementation to pass against;
docs (Task 5) and the backfill (Task 6) close out.

1. **Generator: tag parse + filter + render** — `propagation-entry.sh` tag
   extraction, `[auto]`-drop, `[manual]` plain, `[conditional]` `(conditional)`
   label, untagged keep-and-warn (D1, D2, D6). One commit; carries its own
   `**Existing projects:** [auto] — …` block (dogfoods the convention).
2. **Generator: all-`[auto]` collapse confirmation + comment** — confirm
   `ENTRIES`-empty → `(no manual steps)` covers the all-`[auto]` case; add the
   "actionable entries only" comment (D3). (Small; can fold into Task 1 if the
   filter already yields it — keep separate only if a code change is needed.)
3. **Hygiene gate: tag validation** — `adversarial-review.sh` deterministic
   `PROP_BLOCK_TAGGED` precompute + `$CONTEXT` data line + NOTE-3 directive
   extension (D4).
4. **bats** — the 5 generator cases + 2 gate-precompute cases (§ Tests). Lands
   after Tasks 1-3 so they pass.
5. **Docs** — `conventions.md § Existing-Project Migration Block` tag vocabulary;
   `merge-devshop/SKILL.md § 0.3` tag mention; `PROPAGATION.md` header note. (Docs
   for the gate/generator behavior; pairs with Tasks 1-3 to satisfy docs-coverage.)
6. **v1.37.0 backfill** — collapse the shipped v1.37.0 section to the one CSP
   `[conditional]` entry + the one-line auto-propagate note (D5).

## Gotchas

- **Husky hooks run under `sh`/dash, not bash** — any helper logic that the
  pre-commit/pre-push hooks reach must be POSIX-portable. The generator + gate
  scripts themselves are invoked as `bash` (shebang `#!/bin/bash`), so bash-isms
  inside them are fine; just don't add bash-only syntax to anything sourced by a
  `.husky/` hook.
- **The awk block-extraction (lines 31-37) must not break on the new `[tag]`
  token.** The extractor matches `^\*\*Existing projects:\*\*` and `sub()`s off
  the marker — the `[auto]`/`[manual]`/`[conditional]` token sits in the
  _remainder_ it prints, so the extractor is tag-agnostic and needs no change.
  The tag parse happens _after_ extraction, on `$BLOCK`. Verify the leading-token
  strip handles both `[tag] — text` and `[tag] text` separators (the `— ` em-dash
  and a bare space).
- **`[conditional]` render label** — prefix is `(conditional) ` (with trailing
  space), inserted between the `— ` and the de-tagged block text. Don't double it
  if the author already wrote "(conditional)" in prose — but per D6 the tag drives
  the label, so just always prefix; authors write the trigger, not the label.
- **Untagged-keep is the safe default (D2)** — never let the filter drop an
  untagged block. The dangerous failure mode is silently dropping a real manual
  step; the warning (not a drop) is what drives authors to tag.
- **Editing CLAUDE.md is NOT in scope** — no `/devshop/CLAUDE.md` edit here, so
  the CLAUDE.md classification gate does not fire. (If a future change adds a
  CLAUDE.md `§ Known Footguns` pointer, that's a separate commit subject to the
  gate.)
- **`conventions.md` + `merge-devshop/SKILL.md` doc edits may trip
  docs-coverage** — the docs-coverage check pairs code changes with doc updates.
  Land the docs (Task 5) in the same feature branch as the generator + gate
  (Tasks 1-3) so the branch's net diff carries both. The bats files count as the
  test surface for the code changes.
- **The v1.37.0 backfill is a hand-edit of a `release.sh`-generated section** —
  it won't be regenerated (v1.37.0 already shipped). Edit it directly; don't
  re-run the generator over the v1.36.0..v1.37.0 range (that would re-derive the
  noisy entries from the untagged historical commits).
- **The gate's tag-validation is LLM-prompt-driven, not a hard bash exit** — the
  deterministic part is the `PROP_BLOCK_TAGGED` precompute (bash); the FAIL
  decision is rendered by the Sonnet reviewer via the NOTE-3 directive, matching
  exactly how dimension (d)'s block-presence FAIL already works. Don't add a
  separate `exit 1` for untagged blocks — that would diverge from the established
  one-verdict-per-invocation contract and double-FAIL.

## Acceptance / rollout / rollback

**Acceptance:**

1. `pnpm turbo run test` (or `bats kit/tests/propagation-entry.bats
kit/tests/util-adversarial-review-narrowing.bats`) is fully green — all
   pre-existing tests plus the 7 new cases.
2. Running the generator over a synthetic tagged-commit range containing one
   `[auto]`, one `[manual]`, one `[conditional]`, and one untagged block produces:
   the `[manual]` + `[conditional]` (labelled) entries, the untagged entry (kept,
   with a stderr warning), and NO `[auto]` entry. A range of only `[auto]` blocks
   produces `(no manual steps)`.
3. `kit/docs/PROPAGATION.md` v1.37.0 reads clean: one `(conditional)` CSP entry +
   the one-line auto-propagate note; the header explains the tag-driven filtering.

**Rollout:** Pure devshop-side. The generator + gate are consumed via the
`.devshopkit` symlink + the symlinked `/ak-merge-devshop` skill; projects pick
them up on next sync with no per-project step. The disposition-tag convention
applies to devshop commits authored after this lands (its own
`**Existing projects:**` block is `[auto]`).

**Rollback:** Revert the feature branch. The generator falls back to copying
every block verbatim (the prior behavior); the gate stops requiring a tag; the
v1.37.0 doc edit is a content revert. No data migration, no irreversible state —
PROPAGATION.md is a living doc and the commit history is untouched.
