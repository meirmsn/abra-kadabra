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
