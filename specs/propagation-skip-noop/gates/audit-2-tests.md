high=0 medium=0 low=0

### Tests findings

- (none)

### Coverage verification (Audit-1 test findings re-checked)

- Audit-1 medium (multi-block body untested — first `[auto]` + second `[manual]` silently drops the second step) — RESOLVED by 2af90f9 + bats. The generator now (a) counts markers and WARNs loudly on >1, (b) stops the awk extractor at the second marker so block-2 can't concatenate into block-1. Two new cases pin it: propagation-entry.bats (f) "two-block body warns + processes only the first" asserts the WARN string `2 **Existing projects:** blocks` + `only the first is processed`, and (g) "two ADJACENT blocks (no section break)" asserts the second `[manual]` does NOT leak via concatenation. The reachable D2 silent-drop is now both fixed and tested. Verified green (59/59 ok across both files).
- Audit-1 low (recognized-tag regex case-sensitivity not pinned on either side) — RESOLVED. util-adversarial-review-narrowing.bats (g) "present + tagged block → precompute reports tag: yes" pins the gate-side regex; propagation-entry.bats (b)/(c)/(i) pin the generator-side parse. The gate↔generator contract now has a failing test on either side if one drifts. (f) "present + untagged → tag: no + NOTE-3 untagged-FAIL directive inlined" pins the FAIL path.
- Audit-1 low (bare-space separator only exercised on dropped `[auto]` path) — RESOLVED by propagation-entry.bats (i) "bare-space separator on a KEPT [manual] path strips cleanly" — exercises the `[tag] text` (no em-dash) strip on a rendered/kept path, closing the render-path gap.
- New coverage this range also includes (h) "multi-line block renders ONE clean bullet" — pins the newline-collapse fix from 2af90f9 (tag on line 1, step on line 2 → single bullet, no empty-bullet + orphaned-continuation artifact). Asserts the exact rendered bullet string. Good coverage of the render edge the collapse logic exists for.
- Test↔behavior alignment confirmed by running both touched files: `./kit/tests/lib/bats-core/bin/bats kit/tests/propagation-entry.bats kit/tests/util-adversarial-review-narrowing.bats` → 59 ok, 0 fail.

### Bypass trailer audit

- (no Tests-Coverage-Bypass trailers in range)
