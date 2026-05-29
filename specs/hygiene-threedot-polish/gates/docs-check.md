## Gate 1: docs-check

- Result: pass

The diff IS documentation (kit/docs/guide/workflow.md cross-ref clause +
kit/docs/guide/hooks.md NOTE 3) plus a paired test change. No script/tooling
change (adversarial-review.sh untouched), so the "every tooling change ships
doc updates" rule is N/A here — there is no behavior to document beyond the
docs themselves. Cross-ref target (hooks.md § Dual-surface check-types) exists
and resolves. Doc coverage adequate.

## Dismissals

None
