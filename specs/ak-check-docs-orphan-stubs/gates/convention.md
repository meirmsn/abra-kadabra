## Gate 11: convention

- Result: pass

Devshop convention check (self-mode, adapted — no supabase/UI/metrics surface).
All four sub-checks pass; no violations, no fixes needed.

### (a) SKILL.md frontmatter intact

`.claude/skills/devshop/check-docs-and-tests/SKILL.md` frontmatter block is
well-formed: opening `---` at line 1, closing `---` at line 25, with
`name: ak-check-docs-and-tests`, `version: 2.0.0`, and a `description:` block
present. The Step 1 edit is in the body, below the frontmatter — untouched.

### (b) New shell script: header + `set -euo pipefail` + tracked 644

`kit/scripts/preship/audit-tracker-only.sh`:

- 3-line What/Why/Does NOT header present (lines 2-9): `# What:` (classify a
  git range tracker-only vs source-surface), `# Why:` (orphan review.md stub
  avoidance), `# Does NOT:` (no audit / no scaffold / no sub-skill call — only
  an exit-code verdict). Shebang `#!/usr/bin/env bash` on line 1.
- `set -euo pipefail` present (line 33).
- Tracked mode: `git ls-files -s` reports `100644` — NOT 755. Matches every
  peer in `kit/scripts/preship/` (all 16 are 100644), consistent with the
  devshop script-lock convention. The branch's commit `34c7d55`
  (`fix(preship): track audit-tracker-only.sh as 644`) already corrected this.

### (c) Bats test file exists for the new script

`kit/tests/util-audit-tracker-only.bats` exists (2589 bytes, 9 tests) and
covers the full D2 matrix: tracker-only → 0, mixed/pure-source → 1,
guide-doc-only → 1, test-only → 1, friction-log-only → 0, empty diff → 0,
usage error → 64, and unresolvable-range → 1 (no false short-circuit).

### (d) workflow.md note linked/placed sensibly

The note lives in two sensible locations in `kit/docs/guide/workflow.md`:

- the **Phase 5.8** prose paragraph (where `/ak-check-docs-and-tests` is
  described in the pipeline flow), and
- the **Devshop Skill Map** table row for `/ak-check-docs-and-tests`.
  Both name the helper by path and describe the short-circuit contract. Placement
  is co-located with the skill they document — correct.

### Reuse posture (no duplication)

`kit/scripts/preship/path-classifier.sh` answers a different question (does the
diff need the local Supabase stack — stack-needing vs not), with a different
classification set. The new helper's tracker-only-vs-source-surface concern
does not overlap it, so a separate helper is correct, not a duplication.

bats not re-run (no code change made by this gate); the green baseline (1621
tests, exit 0) established at gate-suite start stands.

## Dismissals

None
