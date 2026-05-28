# Audit 1 — Tests Review

**Range**: `be84c95..a02932e` (single commit `a02932e` — `fix(ak-go-live): robust prod-URL extraction from CLAUDE.md (mid-sentence URLs)`)
**Feature dir**: `specs/go-live-prod-url-extraction`
**Files in scope**: `kit/scripts/lib/extract-prod-url.sh` (new, sourceable `extract_prod_url()`), `kit/tests/extract-prod-url.bats` (new, 12 cases), `.claude/skills/devshop/go-live/SKILL.md` (rewired to source the helper at both call sites)
**Suite status**: `kit/tests/extract-prod-url.bats` — 12/12 passing locally.

**Summary: high=0 medium=2 low=1**

Section A (coverage): new `kit/scripts/lib/extract-prod-url.sh` is paired with `kit/tests/extract-prod-url.bats` (devshop rubric: new `kit/scripts/**.sh` → matching `.bats`). The `.claude/skills/devshop/go-live/SKILL.md` rewire is proven-by the guard assertion (case 12) verifying both call sites are wired. All 12 cases pass. Coverage requirement met. No `[section: A]` findings; the gaps below are quality findings against the new behavior the helper claims to support.

Section C (bypass trailers): no `Tests-Coverage-Bypass:` trailers in range — zero rows (legitimate).

No skipped tests, no `.only`, no `test.skip` in the diff (the lone `skip` grep hit is the word "skip" inside the bats header comment at `:14`, not a directive).

---

### [domain: tests] [section: B] [severity: medium]

**File**: `kit/tests/extract-prod-url.bats:55` (helper at `kit/scripts/lib/extract-prod-url.sh:55-57`)
**What**: No test for an UPPERCASE / mixed-case scheme (`HTTPS://`, `Https://`). The preferred-path pipeline matches the URL token case-insensitively (`grep -oiE 'https?://...'`) but strips the scheme case-sensitively (`sed -E 's|^https?://||'`). The two disagree on case, so the scheme survives. Confirmed live: `Production URL: HTTPS://home.vercel.app` returns the literal `HTTPS://home.vercel.app` (and `Https://...` returns `Https://home.vercel.app`) instead of the bare host.
**Why**: A scheme-bearing return value fails the call-site DNS-label validation regex (`SKILL.md:57` and `:116`), so `/ak-go-live` prints "PROD_URL not configured (or malformed)" and **silently skips the health probe** — the exact silent-skip failure mode this commit exists to eliminate (home-os PR #39), just triggered by a capitalized scheme instead of a mid-sentence URL. The fallback branch never fires because `host` is non-empty. The `grep -oiE` already accepts the uppercase token, so this is a reachable, half-handled input. Case 6 ("http (non-tls) scheme is tolerated") only exercises lowercase, so the case divergence is invisible. CLAUDE.md is hand-edited Markdown; a capitalized scheme is plausible.
**Fix**: Make the scheme-strip case-insensitive in `extract-prod-url.sh:57` — `sed -E 's|^[hH][tT][tT][pP][sS]?://||; s/[.]+$//'` (or add the `I` flag where the local `sed` supports it) — and add a regression case:

```bash
@test "uppercase scheme is stripped" {
  extract 'Production URL: HTTPS://app.vercel.app'
  assert_success
  assert_output "app.vercel.app"
}
```

---

### [domain: tests] [section: B] [severity: medium]

**File**: `kit/tests/extract-prod-url.bats:79` (helper at `kit/scripts/lib/extract-prod-url.sh:47`)
**What**: No test for the hazard where a NON-canonical line containing the words "production url" appears BEFORE the canonical `Production URL:` line. The line selector `grep -i 'production.*url' "$claude_md" | head -1` matches those words anywhere on a line, not the line whose LABEL is `Production URL:`. A prose mention wins. Confirmed live: with
```
See the production url docs for setup instructions before deploying.
Production URL: https://canonical.vercel.app
```
the helper returns **empty** (the prose line has no URL token, and the fallback finds no hostname-shaped token on it), so the canonical line is never inspected and the probe is silently skipped. If the earlier prose line instead carries a stale/staging URL, the helper would return that wrong host and probe it as if it were prod (false health signal). Existing case 10 ("first match wins when multiple production-url lines exist") only covers the benign two-canonical-lines case and entrenches first-line-wins without probing the prose-precedes-canonical hazard.
**Why**: A CLAUDE.md that discusses prod/staging URLs in prose above the Deploy Configuration line is realistic (this session's own home-os CLAUDE.md footgun prose contains "prod URL" mentions). Result is either a silent probe-skip or a probe against the wrong host — both defeat the fix's stated goal. This is a correctness gap in the new behavior, not pre-existing.
**Fix**: Anchor the line selector on the canonical label, e.g. `grep -iE '^[[:space:]>*_-]*\**production url\**[[:space:]]*:'` in `extract-prod-url.sh:47` (label at line start, allowing Markdown bullet/bold wrappers). If instead the intended contract is "first matching line wins, operators must keep the canonical line first", document that constraint in the helper header and pin it with a deliberate test. Add the regression case:

```bash
@test "prose mention of 'production url' above the canonical line is ignored" {
  printf '%s\n%s\n' 'See the production url docs before deploying.' \
    'Production URL: https://canonical.vercel.app' > "$CLAUDE_MD"
  run extract_prod_url "$CLAUDE_MD"
  assert_success
  assert_output "canonical.vercel.app"
}
```

---

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/extract-prod-url.bats:92`
**What**: The wiring guard (case 12) asserts `grep -c 'source ...' == "2"` — an exact-count match on a documentation-prone string. It only proves the `source` line text is present twice, not that `extract_prod_url` is actually invoked at each site. A future SKILL.md edit adding a third mention of the path (comment, shellcheck directive, prose) flips the count to 3 and fails the test for a non-regression; conversely, a refactor that sources once at top-of-file and calls twice would fail at "2" despite being correct.
**Why**: Brittle assertion coupled to an incidental textual count rather than the contract ("both call sites resolve and invoke the helper"). Risk is a future false-fail / maintenance friction, not a missed bug today — hence low.
**Fix**: Assert the contract more directly: `grep -c 'extract_prod_url CLAUDE.md'` equals 2 (proves both call sites invoke), and assert `source .../extract-prod-url.sh` appears `>= 1` rather than `== 2`. Optionally combine both greps so the test reads as "helper is sourced AND called at both sites."
