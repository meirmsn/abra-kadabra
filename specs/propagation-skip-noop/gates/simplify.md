## Gate 4: simplify

Result: pass

Reviewed the real code surface only (tag-parse/filter/render in
`kit/scripts/propagation-entry.sh`; `PROP_BLOCK_TAGGED` precompute in
`kit/scripts/adversarial-review.sh`; the 7 new bats cases). No genuine
over-complexity found — nothing applied.

Tests confirmed green on review (no code changed, but verified the surface was
sound):
`kit/tests/lib/bats-core/bin/bats kit/tests/propagation-entry.bats kit/tests/util-adversarial-review-narrowing.bats`
→ all pass (incl. the 7 new cases: generator (a)-(e), gate precompute (f)-(g)).

### What I checked and why it's already minimal

- **`TAG` extraction (`propagation-entry.sh:50`)** — one `sed -n '1s/…/\1/p'`,
  anchored to line 1. Single pass, captures the matched tag name. Can't be
  smaller.
- **`BLOCK_NOTAG` strip (line 52, four chained `-e`)** — each expression handles
  a distinct, non-overlapping case: (1) tag token + trailing whitespace, (2)
  em-dash separator, (3) ASCII-hyphen separator, (4) residual leading
  whitespace. Em-dash (`—`) and hyphen (`-`) are genuinely different bytes, so
  (2) and (3) are not redundant. (4) is idempotent/defensive against
  multi-separator or odd-spacing input. Verified the strip on em-dash, bare-space,
  and hyphen separators — all yield the de-tagged body cleanly. This is the
  "deliberately-explicit shell" the convention preserves, not over-complexity.
- **`case "$TAG"` (lines 55-77)** — a 4-way disposition dispatch
  (auto/manual/conditional/untagged-default). A `case` is the boring, readable
  shape for a fixed-vocabulary branch; an if/elif chain would be strictly worse.
- **`PROP_BLOCK_TAGGED` precompute (`adversarial-review.sh:385-394`)** — the
  inner `grep -E … | head -1 | grep -qE …` is load-bearing: `head -1` enforces
  "first `**Existing projects:**` line" semantics (matching the generator, which
  reads the head of the block). A single whole-body `grep -qE` would true-match
  if ANY line were tagged, not specifically the first — a correctness regression,
  not a simplification. The outer `[ "$HAS_PROP_BLOCK" = yes ]` guard mirrors the
  established `HAS_PROP_BLOCK` two-state shape so the precompute reads as
  presence-then-tag.

### Dismissals

- Trailing `s/^[[:space:]]*//` in the `BLOCK_NOTAG` strip looks redundant after
  the tag-token expression already consumes `[[:space:]]*`. rationale: it is
  defensive against multi-separator / odd-spacing block bodies and is idempotent
  on well-formed input; removing it trades robustness against malformed authored
  blocks for a one-token micro-cleanup — not a genuine over-complexity win, and
  the convention deliberately keeps this text-processing shell explicit.
- The `if [ "$HAS_PROP_BLOCK" = yes ]` guard re-runs the same
  `grep -E '^\*\*Existing projects:\*\*'` that computed `HAS_PROP_BLOCK`.
  rationale: the re-grep is cheap and the presence-then-tag structure is the
  readable shape; collapsing the two would entangle presence detection with tag
  detection for no clarity gain.
