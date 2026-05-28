# Audit 2 — Tests review (re-audit after Audit 1 fixes)

**Range**: `8a4869afa882c4f8a9358e789e9473208e607492..b1cc8d775eba8e5185a36d7126c86cd990575c83` (10 files, 3 commits)
**Skill**: `/ak-tests-review`
**Verdict**: high=0 medium=0 low=0

Tests look solid — no findings.

---

## Audit 1 → 2 closure

Audit 1 flagged ONE low (test gap): the squash-surface `HAS_PROP_BLOCK=yes`
branch in `adversarial-review.sh` was unasserted.

**CLOSED.** A third narrowing case now exists:

- `kit/tests/util-adversarial-review-narrowing.bats:277` —
  `prTextHygieneReason squash-surface: dimension d reports block: yes when surface touched AND block present`
  - Builds a squash diff touching `kit/scripts/foo.sh` AND a body carrying a
    real `**Existing projects:**` block.
  - Asserts `contains an **Existing projects:** block: yes` is injected into
    the precompute prompt (proves the marker regex `^\*\*Existing projects:\*\*`
    matches a real block on the squash path).
  - Passes as test 17 in its file.

This completes the dimension-(d) precompute branch matrix:
block:no (`:217`) / N/A-empty-surface (`:254`) / block:yes (`:277`).

---

## Section A — Coverage of new behavior

Two source changes in range; both have matching behavioral `.bats` coverage:

1. **`kit/scripts/propagation-entry.sh`** (missing-block WARN, release-time layer)
   — covered by 3 new behavioral tests in `kit/tests/propagation-entry.bats:284-322`:
   warns on propagation-surface commit with no block / no-warn when block present /
   no-warn on docs-only commit. Assertions check exact stderr strings
   (`WARN`, `kit/scripts/foo.sh`, `no **Existing projects:** block`) AND the
   non-fatal contract (`(no manual steps)` still written). Devshop rubric
   (`kit/scripts/**.sh` → matching `.bats`) satisfied.

2. **`kit/scripts/adversarial-review.sh`** (dimension-d precompute + NOTE 3)
   — covered by 3 narrowing tests in `kit/tests/util-adversarial-review-narrowing.bats:217,254,277`:
   block:no when surface touched + no block / N/A when no surface touched /
   block:yes when surface touched + block present. All assert against
   prompt-injected data (`-qF` exact-string), not shape.

Doc/skill changes (`SKILL.md`, `CLAUDE.md`, `conventions.md`) carry no test
requirement under the rubric (covered by `/ak-docs-review`).

## Section B — Test quality

No weak assertions. All new tests use exact-string `grep -qF` / `[[ == *...* ]]`
on prompt-injected data or stderr output — no `toBeDefined`/`toBeTruthy`-style
weakness, no shape-only assertions, no implementation-detail coupling. The
WARN-path tests assert both the loud-failure signal AND the non-fatal contract
(entry still written). Marker-regex alignment between the precompute
(`adversarial-review.sh`) and the extractor (`propagation-entry.sh`) is pinned
by the block:yes case — a regression breaking the marker would mis-report 'no'
and the test would catch it. No skipped tests / `.only` introduced.

## Section C — Bypass trailer audit

Zero `Tests-Coverage-Bypass:` trailers in range. Nothing to judge.

---

## Suite health

Full bats suite green: `kit/tests/lib/bats-core/bin/bats kit/tests/` →
**0 `not ok`** out of 1519 tests. The two touched files
(`util-adversarial-review-narrowing.bats` + `propagation-entry.bats`) → 46/46 pass.
