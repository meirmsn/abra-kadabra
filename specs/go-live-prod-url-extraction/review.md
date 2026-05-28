# Review — go-live-prod-url-extraction

## Audit 1: manual (2026-05-28)

<!-- audited-at: a02932e -->
<!-- range: be84c95..a02932e -->

findings: high=0 medium=2 low=2

### Docs findings

- [low] kit/docs/guide/workflow.md:319 — the new shared helper `kit/scripts/lib/extract-prod-url.sh` isn't called out in the Step 6 prod-health-probe bullet, unlike its sibling `rewrite-pr-body-urls.sh` (named at § Step 2.5). Behavior-preserving; optional one-clause parallel-treatment fix.

### Tests findings

- [medium] kit/scripts/lib/extract-prod-url.sh:57 — UPPERCASE scheme not stripped: the URL grab is case-insensitive (`grep -oiE`) but the scheme-strip is case-sensitive (`sed -E 's|^https?://||'`), so `HTTPS://host` returns `HTTPS://host`, fails the call-site DNS-label validation, and **silently skips the probe** — the exact failure mode this fix targets. Fix: case-insensitive scheme strip + regression test.
- [medium] kit/scripts/lib/extract-prod-url.sh:47 — greedy line selection: `grep -i 'production.*url' | head -1` matches those words anywhere, so a prose line mentioning a "production url" before the canonical `Production URL:` line wins → empty return (silent skip) or wrong-host probe. Fix: anchor the selector on the canonical label (line-start `Production URL:`), or document + pin a "first-line-wins" contract.
- [low] kit/tests/extract-prod-url.bats:92 — wiring guard asserts an exact `==2` source-line count; brittle to doc drift and only proves sourcing, not invocation. Fix: assert `extract_prod_url CLAUDE.md` invocation count == 2; assert source `>= 1`.

### Bypass trailer audit

- (none)

<!-- NOTE: not surfaced by the docs/tests audit but known: the new
     kit/scripts/lib/extract-prod-url.sh is not registered in
     structural-invariants.bats infra_scripts — Phase 2.5 wiring test
     will flag it until added. Fixed in-branch alongside the mediums. -->

## Audit 2: manual (2026-05-28)

<!-- audited-at: 9f117df -->
<!-- range: a02932e..9f117df -->

findings: high=0 medium=1 low=1

Re-audit after polishing Audit 1. Both Audit 1 mediums verified closed
(mutation-tested: reverting each fix fails exactly its regression case).
Audit 1's docs low + the structural-invariants wiring NOTE are also closed.

### Docs findings

- [medium] commit 9f117df body — touches the propagation-relevant `kit/scripts/**` surface but omits an `**Existing projects:**` block. Squash-message-level, not a code fix: RESOLVED by the `/ak-merge-devshop` squash message, which carries the "no migration needed" block (helper consumed via the live `/devshop/kit/scripts/lib/` path; projects pick up the fix on next `/ak-go-live` run). Practical migration risk is nil.

### Tests findings

- [low] kit/tests/extract-prod-url.bats — case 13 pinned only the silent-skip half of the line-selector hazard; the wrong-host half (a prose line carrying a stale URL) was guarded but not independently witnessed. CLOSED in this audit pass by a new regression case ("prose line carrying a stale URL above the canonical line is ignored").

### Bypass trailer audit

- (none)
