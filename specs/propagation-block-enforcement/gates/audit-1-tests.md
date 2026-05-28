# Tests Review — Audit 1

**Range**: `8a4869afa882c4f8a9358e789e9473208e607492..a7c37aaf362983c1353a1b1d02daefd9f99caf57`
**Feature dir**: `specs/propagation-block-enforcement`

## Summary

- Full bats suite: **1518 ok, 0 not ok** (green).
- Two affected files run clean: `kit/tests/propagation-entry.bats` (tests 22–24) and `kit/tests/util-adversarial-review-narrowing.bats` (tests 38–40).
- Section A (coverage): both new source paths have matching `.bats` coverage that exercises the new behavior, not just file pairing.
- Section C (bypass trailers): zero `Tests-Coverage-Bypass:` rows harvested — legitimate, none expected.
- No `test.skip` / `.only` patterns added.

## Section A — Coverage of new behavior

**`kit/scripts/propagation-entry.sh` (new else-branch: stderr WARN on surface+no-block).** All three branches of the new conditional exercised:
- WARN fires on propagation-surface + no block — `propagation-entry.bats:282` asserts the WARN text, the surface file `kit/scripts/foo.sh`, the `no **Existing projects:** block` phrase, AND that the commit is silently dropped from the generated entry (`(no manual steps)`). Strong assertion on the actual user-visible stderr output + the downstream consequence.
- WARN suppressed when a propagation-surface commit HAS a block — `propagation-entry.bats:300`.
- WARN suppressed on a non-propagation (docs-only) commit lacking a block — `propagation-entry.bats:312`.

**`kit/scripts/adversarial-review.sh` (squash-surface dimension d: precompute touched surfaces + block-presence, NOTE 3).** The dimension-d logic is deterministic precompute (`PROP_SURFACES`, `HAS_PROP_BLOCK`) + a static NOTE 3; the FAIL/N-A verdict is delegated to the LLM. The tests correctly assert on the precomputed data injected into the captured prompt (a contract assertion via the stdin-capturing `claude` mock, not an implementation-detail mock):
- Surface-touched + no block — `util-adversarial-review-narrowing.bats:217` asserts the touched surface `kit/scripts/foo.sh` is injected, `contains an **Existing projects:** block: no`, `NOTE 3` present, and the `Existing-projects propagation block` dimension name present.
- N/A path (no surface) — `util-adversarial-review-narrowing.bats:255` asserts `NOTE 3` present + the `If the list is EMPTY` N/A guidance present.

No missing pairs. Coverage is genuine new-behavior coverage.

## Section B — Test quality

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/util-adversarial-review-narrowing.bats:217`
**What**: The squash-surface dimension-d precompute has a two-way `HAS_PROP_BLOCK` (`yes`/`no`). Only the `no` branch is asserted directly on the squash surface (test 39 checks `block: no`). The `yes` branch — squash diff touches a propagation surface AND the body carries an `**Existing projects:**` block — is never pinned into the injected prompt on the squash path (test 38 "reads from DEVSHOP_HYGIENE_MESSAGE_FILE" uses a body without a block and does not assert on `block:`).
**Why**: A future regression that broke the marker regex (`^\*\*Existing projects:\*\*`) for the present-block case — e.g. a tightened/escaped pattern that no longer matches a real block — would compute `block: no` on a squash that actually carries one, mis-feeding NOTE 3 toward a false FAIL. No squash-surface test would catch it; the equivalent regex is only proven on the separate `propagation-entry.sh` extractor path (test 23), not on the `adversarial-review.sh` precompute.
**Fix**: Add a third narrowing case mirroring test 39 but with a body that includes `**Existing projects:** none — <why>`, asserting `grep -qF "contains an **Existing projects:** block: yes"` on `$CAPTURED_PROMPT`. One-line branch; low risk, hence low severity — noted, not ship-blocking.

## Section C — Bypass trailer audit

Zero `Tests-Coverage-Bypass:` trailers in range. Section legitimately harvests zero rows.

## Severity tally

high=0 medium=0 low=1
