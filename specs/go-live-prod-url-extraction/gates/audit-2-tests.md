# Audit 2 — Tests Review

**Range**: `a02932e..9f117df` (2 commits: `1279deb` docs Audit-1 sinks; `9f117df` `fix(ak-go-live): handle uppercase scheme + anchor prod-URL line match`)
**Feature dir**: `specs/go-live-prod-url-extraction`
**Files in scope (test/source)**: `kit/scripts/lib/extract-prod-url.sh` (2 robustness fixes), `kit/tests/extract-prod-url.bats` (2 new regression cases, now 14 total), `kit/tests/structural-invariants.bats` (registers `extract-prod-url.sh` in `infra_scripts`)
**Suite status**: `kit/tests/extract-prod-url.bats` — **14/14 passing** locally (bats `kit/tests/lib/bats-core/bin/bats`). `structural-invariants.bats` test 12 ("every non-exempt kit script is wired into a hook or pre-commit") — passing, confirming the Audit-1 NOTE about the Phase 2.5 wiring gap is now closed.

**Summary: high=0 medium=0 low=1**

This is a re-audit after polishing Audit 1's two medium robustness gaps. Both fixes verified present and correct; both new regression tests verified load-bearing via mutation testing.

---

## Verification of Audit 1's fixes (mutation tested)

Both fixes are in place in `kit/scripts/lib/extract-prod-url.sh` and both new tests genuinely pin them. Method: revert each fix in-place on the (editable) worktree helper, run the real `extract-prod-url.bats` suite, confirm the corresponding new case — and ONLY that case — fails, then restore (helper byte-identical to committed HEAD afterward; `git diff --quiet` → CLEAN).

- **Fix 1 — case-insensitive scheme strip** (`extract-prod-url.sh:62`, `sed -E 's|^[Hh][Tt][Tt][Pp][Ss]?://||'`). Mutation: reverted to `s|^https?://||`. Result: `Production URL: HTTPS://app.vercel.app` returns the literal `HTTPS://app.vercel.app` (scheme survives → fails call-site DNS-label validation → silent probe-skip). Under the mutation **exactly case 12** ("uppercase scheme is stripped") fails; all 13 others pass. Lowercase still works under the mutation (case 6 green), so case 12 is the sole, precise witness for the case-divergence bug. Pinned.

- **Fix 2 — anchored line selector** (`extract-prod-url.sh:52`, `grep -iE '^[[:space:]]*[-*+>_ ]*production url[*_ ]*:'`). Mutation: reverted to `grep -i 'production.*url'`. Result: a prose line mentioning "production url" before the canonical line wins. Under the mutation **exactly case 13** ("prose mention of 'production url' above the canonical line is ignored") fails; all 13 others pass. Pinned.

Test assertions are exact-value contracts (`assert_output "app.vercel.app"` / `"canonical.vercel.app"` + `assert_success`), not weak `toBeDefined`/`toBeTruthy`-style checks — input (synthetic CLAUDE.md) → output (bare host), no implementation-detail coupling.

Section A (coverage): the two source changes are both covered — the helper fixes by cases 12 + 13 (mutation-proven), the `structural-invariants.bats` registration by the existing wiring test 12 (now green). No `[section: A]` findings.

Section C (bypass trailers): no `Tests-Coverage-Bypass:` trailers in range — zero rows (legitimate).

No skipped tests, no `.only`, no `test.skip` in the diff.

---

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/extract-prod-url.bats:98` (case 13; helper at `kit/scripts/lib/extract-prod-url.sh:52`)
**What**: Audit 1's medium finding for the line-selector named TWO hazards from the unanchored `grep -i 'production.*url'`: (a) **silent probe-skip** when the winning prose line has no URL token (empty return), and (b) **wrong-host probe** when the earlier prose line carries a stale/staging URL that then gets probed as if it were prod (false health signal). Case 13's fixture uses a prose line with NO URL (`'See the production url docs before deploying.'`), so the mutation fails case 13 via the **empty-return path only**. The wrong-host path is never independently witnessed by a test.
**Why**: The fix (`grep -iE '^...production url...:'`) correctly guards BOTH hazards — verified live: with the vulnerable selector, fixture `'The old production url was https://stale-staging.vercel.app before we moved.\nProduction URL: https://canonical.vercel.app'` returns `stale-staging.vercel.app` (wrong host), while the fixed helper returns `canonical.vercel.app`. So there is no behavior bug today. But the wrong-host branch — the more dangerous of the two, since it produces a confident probe against the wrong target rather than a no-op — has no regression pin. A future selector refactor that re-broke wrong-host while preserving empty-return (e.g., one that picks the first line with a URL token rather than the first `production url` line) would pass case 13 and ship the regression silently. Low, not medium: same anchor fix covers both; this is a missing-witness gap on an already-fixed path, not a live bug.
**Fix**: Add a sibling regression case whose prose line carries a URL, asserting the canonical host wins:

```bash
@test "prose line carrying a stale URL above the canonical line is ignored" {
  printf '%s\n%s\n' 'The old production url was https://stale-staging.vercel.app before we moved.' \
    'Production URL: https://canonical.vercel.app' > "$CLAUDE_MD"
  run extract_prod_url "$CLAUDE_MD"
  assert_success
  assert_output "canonical.vercel.app"
}
```

This pins the wrong-host half of the same anchor fix; mutation-revert to `grep -i 'production.*url'` would then fail it (returns `stale-staging.vercel.app`), giving the second hazard its own witness.

---

**Verdict**: Audit 1's 2 mediums are genuinely closed — both fixes correct, both regression tests mutation-proven to be the sole, precise witnesses for their respective bugs. Suite is 14/14. The Audit-1 structural-invariants wiring NOTE is also resolved (test 12 green). One low: case 13 pins only the empty-return half of the line-selector hazard; the wrong-host half (also fixed) lacks its own regression witness. No high or medium findings — no halt.
