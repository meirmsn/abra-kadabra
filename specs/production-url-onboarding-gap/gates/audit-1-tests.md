### [domain: tests] [section: A] [severity: medium]

**File**: `.claude/skills/devshop/go-live/SKILL.md:56` (+ `:116` for the Step 3.5 escape-hatch copy)
**What**: The canonical strict DNS-label regex (`^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$`) now lives in FOUR places — `template/.devcontainer/init-prod-url.sh:77`, `template/.devcontainer/refresh-allowed-ips.sh:71`, `go-live/SKILL.md` Step 1.5 main probe (line 56), and `go-live/SKILL.md` Step 3.5 in-session escape hatch (line 116). The new `kit/tests/template-production-url-firewall.bats` asserts identity between the TWO template-side copies (test 19: `canonical: DOMAIN_REGEX is identical in init-prod-url.sh and refresh-allowed-ips.sh`), but does NOT extend that invariant to the two SKILL.md inline copies. The skill prose is the only source for the operator-facing CLAUDE.md extractor — the bats file does not prove the skill's extractor stays in sync.
**Why**: A future tightening of `DOMAIN_REGEX` in the template scripts (e.g., narrowing the per-label cap, disallowing leading digits, anchoring stricter on TLD) could land in `init-prod-url.sh` + `refresh-allowed-ips.sh` (test 19 stays green because they drift together) without propagating to the two SKILL.md copies. The skill's extractor would then accept hostnames the template scripts reject — operator pastes a value the skill's Step 1.5 validator passes, runs `/ak-go-live`, the in-session escape hatch writes to `/etc/refresh-allowed-ips/production_url`, then `refresh-allowed-ips.sh`'s defense-in-depth re-validation rejects the value, and the canary lands in a "I just configured this — why is it failing?" loop. The new commit `5f6a08b` ("adopt canonical DNS-label regex (per-label rigor)") already shows this drift is a live concern — that commit's purpose was retroactively syncing the skill's regex with the template's; nothing in the test suite would catch the next drift.
**Fix**: Extend the cross-script invariant in `kit/tests/template-production-url-firewall.bats` (or add a sibling `util-go-live-prod-url-extractor.bats`) with a fourth assertion that grep-extracts the canonical regex from BOTH SKILL.md inline-bash blocks and asserts it matches `DOMAIN_REGEX` from the template scripts. Concretely:

```bash
@test "canonical: DOMAIN_REGEX in go-live SKILL.md matches template scripts" {
  local template_re skill_re_a skill_re_b
  template_re=$(grep -oE "'\^\[a-zA-Z0-9\][^']+\$'" "$INIT_PROD_URL" | head -1)
  skill_re_a=$(grep -oE "'\^\[a-zA-Z0-9\][^']+\\\$'" \
    "$DEVSHOP/.claude/skills/devshop/go-live/SKILL.md" | sed -n '1p')
  skill_re_b=$(grep -oE "'\^\[a-zA-Z0-9\][^']+\\\$'" \
    "$DEVSHOP/.claude/skills/devshop/go-live/SKILL.md" | sed -n '2p')
  [ -n "$template_re" ] && [ -n "$skill_re_a" ] && [ -n "$skill_re_b" ]
  [ "$skill_re_a" = "$skill_re_b" ]   # Step 1.5 ≡ Step 3.5
  # The skill copies are inside a markdown grep -qE so the closing $ is shell-escaped
  # differently — normalize before comparing template ↔ skill, or pin the distinctive
  # `[a-zA-Z0-9-]{0,61}[a-zA-Z0-9]` substring across all four sites the way test 14 does
  # for refresh-allowed-ips. Pick the form that resists future-spaghetti the least.
}
```

Or, lower-cost: add the same `grep -qF '[a-zA-Z0-9-]{0,61}[a-zA-Z0-9]'` distinctive-substring check (already used in tests 5 and 14) against both SKILL.md files. That doesn't catch drift WITHIN the per-label cap but catches the most common loosening modes (dropping the cap entirely, replacing with `\w`, etc.) — which matches the bar test 14 sets for `refresh-allowed-ips.sh`.

### [domain: tests] [section: A] [severity: low]

**File**: `.claude/skills/devshop/go-live/SKILL.md:52,73,112` — sed extractor pipeline + `sudo cat $ETC_FILE` runtime read
**What**: The skill's three new bash idioms — (a) the `grep | sed -E 's/^[^:]*:[[:space:]]*//'` extractor that pulls the `Production URL:` value out of CLAUDE.md, (b) the `sed -E 's/[`<>"'\''[:space:]]+//g; s|^https?://||; s|/.*$||'` normalizer that tolerates the three wild-seen formats (bare / backticked / https-prefixed), and (c) the tri-state classifier's `sudo cat /etc/refresh-allowed-ips/production_url | tr -d '[:space:]'` runtime read — are operator-facing recipes with no structural test. The bats file proves the underlying template scripts but not the skill's parser-side code paths.
**Why**: These extractors interpret CLAUDE.md's `Deploy Configuration` section as a structured field even though the section's actual format isn't enforced by any commit hook. If a future `/setup-deploy` skill change reformats the `Production URL:` line (e.g., adds inline parens for region, switches to YAML frontmatter), the skill's extractor silently fails the regex validation and Step 1.5 logs "PROD_URL not configured" instead of probing — masking the real "section format drifted" bug as a benign skip. A `util-go-live-prod-url-extractor.bats` smoke test that feeds the extractor a fixtures table (bare, backticked, https-prefixed, malformed, empty, `<fill in>` placeholder) would catch this at edit time.
**Fix**: Add a `kit/tests/util-go-live-prod-url-extractor.bats` with ~6 cases that source the extractor logic from the SKILL.md (via a tiny `awk` snippet to lift the code-fenced bash block) and assert the parsed `BARE_HOST` matches expectation for each fixture. Defer if you want — the medium finding above already pins the most load-bearing piece (the regex). This low-severity item is the next layer of robustness.

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/template-production-url-firewall.bats:34-40`
**What**: `setup()` hard-codes `DEVSHOP="/devshop"` — the canonical repo root. When this test runs from a worktree (e.g., `/devshop/.worktrees/production-url-onboarding-gap/`), it asserts against the canonical `/devshop/template/.devcontainer/*.sh` files rather than the worktree's. In this audit's case the worktree didn't modify any `template/` files, so the assertions happen to pass against the right state. But the pattern means a future change that modifies BOTH the template scripts AND this bats file on a feature branch would have the bats run against the OLD template (the one checked out at `/devshop`) — green test, broken-branch reality.
**Why**: Cross-worktree assertions silently cheat. A worktree-aware `setup()` would either compute `DEVSHOP` from `BATS_TEST_DIRNAME` (walking up to the kit/tests parent) or guard with `[ -f "$INIT_PROD_URL" ]` against the resolved path. Today's pattern works because every template-changing PR also runs the bats from the worktree root (via the pre-commit hook), which usually has the right `/devshop/template/.devcontainer/` view too (the main checkout is the source of truth) — but the cross-worktree case is a latent footgun.
**Fix**: Replace `DEVSHOP="/devshop"` with a derived path:

```bash
setup() {
  load helpers/setup
  # Resolve to the repo root of the current worktree, not the canonical /devshop.
  DEVSHOP=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  DC="$DEVSHOP/template/.devcontainer"
  ...
}
```

Worth a 2-line patch even if no current case bites — the cost is near-zero, and the next refactor of the template scripts on a feature branch should test against the branch state, not the main checkout.

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/template-production-url-firewall.bats:200`
**What**: Test 17 (`refresh-allowed-ips: validates each resolved IP before ipset add`) asserts on a `grep -qE` of the IP-validation regex with five levels of backslash escaping (`\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}\\\.\[0-9\]\{1,3\}`). The pattern matches the literal source-code regex bytes — including the literal `\.` between octets — but the multi-layer escaping makes the assertion hard to read and easy to drift.
**Why**: Future maintenance hazard, not a missed-bug risk. Anyone tightening this assertion (e.g., extending to anchor the leading `^` and trailing `$`) is going to have a bad time figuring out how many backslashes they need. The current form passes, and the dotted-quad regex in `refresh-allowed-ips.sh` is unlikely to change in shape.
**Fix**: Use `grep -qF` with the distinctive substring `[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}` (matches the same characters with one level of escaping for the dots, no regex semantics needed since `-F` is fixed-string). Optional polish only — non-blocking.

### Section C — Bypass trailer audit

No `Tests-Coverage-Bypass:` trailers in range `origin/main...HEAD` (5 commits: `c8acf70`, `bfad053`, `3a332e1`, `5f6a08b`, `e71e67a`). Zero rows to verify/defer/escalate.

### Summary

- **Coverage of new code paths**: the new `template-production-url-firewall.bats` is a strong template-side proof — 20 specific structural assertions, all passing, covering both scripts + cross-script regex identity + `init-firewall.sh` wire-up. The two SKILL.md prose changes are not directly proven by any test; the canonical DNS regex is the highest-value drift target and has no cross-file identity check between template and skill.
- **Test quality**: assertions are specific, comments explain the bug each assertion prevents, no skip/only patterns, no weak `toBeDefined`-equivalents, atomic-write + permission + additive-only invariants all pinned by greps that would fail on regression.
- **Severity distribution**: 0 high, 1 medium (skill ↔ template regex drift), 3 low (extractor smoke test, worktree-aware setup, IP-regex assertion readability).
- **Recommendation**: address the medium finding (4-site regex identity) in this PR or open a `kit/TODOS.md` entry so the drift surface closes before the next time someone tightens the canonical regex. The three low findings are non-blocking polish.
