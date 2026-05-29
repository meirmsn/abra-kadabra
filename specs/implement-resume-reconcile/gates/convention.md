## Gate 11: convention

- Result: findings (1) pending
- **SKILL frontmatter — pass.** Both `build/SKILL.md` (v2.0.0) and `implement/SKILL.md` (v3.0.0) retain valid `name:`/`version:`/`description:` blocks with properly closing `---` (build closes L38, implement L21). Versions are unchanged from merge-base (4a77f28); these skills version at major.minor.patch granularity and the edits (prose additions to existing phases) don't warrant a bump — consistent with the skill's existing versioning posture. No frontmatter breakage.
- **New script structure — pass.** `kit/scripts/reconcile-task-commits.sh` matches the sibling pattern (`preship/check-llm-mediated-na.sh`): `#!/usr/bin/env bash` shebang, full `What:`/`Why:`/`Does NOT:`/`Usage:`/`Exit codes:` header comment, `set -euo pipefail`, arg-count + file-existence + git-repo + base-ref usage-error handling (exit 64), and the same mawk-portability discipline (no `\b`, runtime AWK_BIN selection with `AWK_BIN=mawk` pinnable for tests). Clean and idiomatic.
- **Bats coverage — pass.** `kit/tests/util-reconcile-task-commits.bats` (204 lines) targets the new script directly; `kit/tests/util-ak-build-skill.bats` (377 lines) asserts the wiring prose in build/SKILL.md. Full suite run: 53/53 pass, 0 failures.
- **Guide doc linkage — pass (confirmed).** No new guide doc added. `workflow.md` was edited only; it is already linked in `kit/docs/guide/README.md` (L117 + L144 table). No action needed.
- **File mode — pass.** `git ls-files -s kit/scripts/reconcile-task-commits.sh` shows `100644` — matches the structural-invariants convention for kit/scripts (sourced/invoked via `bash`, not `chmod +x`). Note: commit `2c14f6b` explicitly corrected an initial 755 to 644, so this was caught and fixed in-branch.
- **FINDING — commit subject length (3 subjects > 72 chars).** The ≤72-char observable-change style is violated on three subjects:
  - `docs(workflow): restore merge-devshop three-dot-precompute note dropped in rebase` — 81 chars
  - `feat(ak-build): reconcile done markers at Step 0 resume before skipping Phase 2` — 79 chars
  - `docs(ak-implement): reaffirm a task is done only when committed + tree clean` — 76 chars
  Conventional-commit type/scope prefixes are all correct and subjects describe observable changes; only the length cap is breached. These are immutable history on the branch, but since this devshop feature lands via `/ak-merge-devshop` (squash-merge), the final main-branch subject is the operator-authored squash subject — these per-commit subjects are compressed into the `## Squashed commits` bullet list and never become a standalone `git log` entry on main. Impact is therefore cosmetic at the per-commit level. Surfacing per the gate spec; operator should ensure the squash subject stays ≤72.

## Dismissals

- SKILL version not bumped: not a finding — edits are prose-level within existing major versions; the skill does not version per-edit.
