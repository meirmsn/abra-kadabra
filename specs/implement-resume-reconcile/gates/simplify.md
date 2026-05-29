## Gate 4: /simplify

- Result: pass
- No simplifications warranted — helper is already minimal and idiomatic. `reconcile-task-commits.sh` is a faithful clone of the established `kit/scripts/preship/check-llm-mediated-na.sh` precedent (same `# What/Why/Does NOT` + Usage + Exit-codes header shape, same runtime AWK_BIN selection block, same mawk-portability discipline — `($|[^...])` anchors instead of `\b`). The script body is POSIX/dash-clean (no `[[ ]]`, `=~`, arrays, `local`, here-strings). The two awk programs are tight; the four `IMPL_AWK` `/.../ { next }` bookkeeping exclusions are kept as separate rules deliberately so each carries its inline rationale comment (collapsing into one alternation would lose the per-exclusion documentation the spec calls out). No dead code, no unused vars, no unclear naming. The two bats files and the SKILL.md / workflow.md prose edits are precise and consistent with existing structure.

## Dismissals

- **Extract the shared AWK_BIN-selection block into a sourced helper** — dismissed. The ~8-line block is duplicated in exactly two scripts (`reconcile-task-commits.sh` + `check-llm-mediated-na.sh`). Extracting it would add a sourced-dependency for marginal savings and break the "each kit/script is a self-contained, independently testable surface" pattern the codebase deliberately follows. Two copies of a small idiom is the boring, correct choice here.
- **Change shebang `#!/usr/bin/env bash` → `#!/bin/sh`** — dismissed. The body is POSIX-clean so `sh` would work, but both call sites (bats `run bash "$SCRIPT"` and SKILL.md `bash kit/scripts/...`) invoke it explicitly via `bash`, so the shebang is never consulted in practice; it also matches the precedent script's shebang verbatim. Changing it is churn with zero behavioral effect and a small portability-surprise risk.
- **Collapse the four `IMPL_AWK` exclusion rules into one alternation** — dismissed. See Result bullet: the per-rule comments are the documentation value.
