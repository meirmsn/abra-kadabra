# Audit 1 — Tests Review

Range: `c6be31effd6f416dc44542d432dd6e3b486855b7..440f408fc8d95e8fee67471c6cd6f6b4a27244e6`
Feature dir: `/devshop/specs/firewall-extras-test-stale`

Tests look solid — no findings.

## Verification performed (not findings; recorded for audit trail)

- **(a) Correct, non-tautological static pin.** The new assertion in
  `kit/tests/firewall-extras-overlay.bats:155` greps for
  `[ -e "$FWE_DST" ] && [ "$(stat -c '%U:%G %a' "$FWE_DST")" != "root:root 644" ]`.
  Confirmed it matches the shipped guarded form at
  `kit/scripts/init-devshop.sh:225` (line uniquely matched — does NOT
  spuriously hit the manifest-loop stat sites at lines 70/208/269/277).
  Confirmed the pre-440f408 assertion (the unconditional
  `... && chown root:root ... && chmod 644 ...` form) does NOT match the
  shipped script — i.e. the test was genuinely RED on main, and the new
  assertion would fail if the guard were reverted to unconditional. Full
  suite runs green (16/16, incl. renamed test #14) via the vendored bats.

- **(b) Mirrors sibling drift-guard rigor.** The assertion and its
  comment mirror the two c6be31e-shipped sibling pins in
  `kit/tests/manifest-lifecycle.bats:521` ("gates chown/chmod on a stat
  ownership tuple") and `:504` (the `cmp -s` guard pin): same
  static-grep-against-script style, same "revert-to-unconditional is a
  churn regression not a correctness one" framing, same explicit
  "pin the guarded form statically" rationale.

- **(c) No under-assertion / loose-regex risk.** The two `.` metachars in
  `stat -c .%U:%G %a.` stand in for the literal single-quotes around the
  stat format and are the same convention used verbatim by the sibling
  test at `manifest-lifecycle.bats:532` (avoids quoting `'` inside the
  `grep -qE` single-quoted ERE). The literal `root:root 644` tail and the
  full `[ -e "$FWE_DST" ] && [ ... != ... ]` skeleton are pinned exactly,
  so the regex cannot match the unconditional form or a degenerate
  always-true guard. Looseness is negligible and matches established style.

## Section C — Bypass trailer audit

No `Tests-Coverage-Bypass:` or `Docs-Coverage-Bypass:` trailers in range
(0 rows harvested — as expected for a single test-only fix commit).
