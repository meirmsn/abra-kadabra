## Gate 6: /review

**Surface**: devshop-self docs + one shell hook + adversarial reviewer prompt + bats test + ak-build skill file. No app runtime, no SQL, no auth, no trust-boundary surface.

**Verdict: PASS** — no findings.

### Shell correctness

- `bash -n kit/scripts/adversarial-review.sh` → clean.
- `bash -n kit/scripts/commit-hooks/check-claude-md-classification.sh` → clean.
- The hook's three added `echo` lines (the skill-operational guidance block + the two appended clauses) are plain double-quoted strings with no embedded `"`, `` ` ``, `$`, or `\`; the BLOCK guidance still renders and the `exit 1` path is untouched. The existing `\"` escapes in the `Usage:` line are unchanged.
- `adversarial-review.sh` rule-15 edits sit entirely inside the large `PROMPT="..."` double-quoted string (opens L1047, closes on the `...what was missed>"` line ~L1306). Added prose uses single quotes (`'when you do X, always Y'`, skill names) which are literal inside a double-quoted string, and contains no unescaped `"`, backtick, or `$`. `bash -n` (the authoritative parse check) confirms the heredoc/string boundaries are intact — no stray char broke the gate.

### Logical soundness — rule 15(c)/(f)

- **15(f) skill-operational sub-test** correctly targets the failure mode: a "trap" whose body is operational logic for a NAMED skill fails the reachability test by construction (can't bite before the skill is opened), even when phrased as an ambient directive. The near-tell ("entry names a specific skill / phase / gate") is a concrete, non-circular discriminator. It does NOT false-positive on legitimate ambient traps (symptom + first-action) because those bite before any skill is opened and name no owning skill as the locus of behavior.
- **15(c)/(f) coherence**: the two clauses compose without contradiction. 15(f) forces a misfiled inline trap to be reclassified as reference→relocate; 15(c) then enforces that the named skill destination file is staged in the same commit. The "or a file in the skill's dir, e.g. `.claude/skills/devshop/build/devshop-mode.md`" clause is coherent with how this very PR relocated the root-cause mechanic (into devshop-mode.md, not SKILL.md) — the relaxation is intentional and self-consistent with the worked example cited in claude-md.md.

### bats test quality (Test 3c)

- Test 3c has no skip guard and runs in devshop-self mode. It asserts `assert_failure` plus the two exact substrings the new hook `echo` lines emit (`Skill-operational`, `SKILL.md`), so dropping the guidance from the gate reds the test — a genuine LOUD pin on the routing destination.
- Scope note (not a finding): the bats layer pins the BLOCK-message _guidance text_, not the reviewer's semantic _judgment_ that skill-operational content gets rejected. That is correct by design — the adversarial reviewer is mocked in this suite, so the semantic judgment lives in rule 15(f) prose and is not unit-testable here. The pin is meaningful for what it can pin.
- Full suite (`guard-claude-md-classification.bats`) → exit 0.

### Doc coherence

- Symlink path `.claude/skills/ak-build/devshop-mode.md` and real path `.claude/skills/devshop/build/devshop-mode.md` BOTH resolve (`ak-build` → `devshop/build` symlink confirmed). The pointers in CLAUDE.md / conventions.md (symlink form) and the routing-table row + reviewer prompt (real form) all point at the same live file.
- Cross-reference anchors all resolve: `§ Reachability split` (claude-md.md L17), `§ Phase 0 fix-assessment` heading (devshop-mode.md L67), the **skill-operational** routing-table row (claude-md.md L99), `§ Root-cause over bandaid` (conventions.md).
- CLAUDE.md § Implementation Approach now correctly keeps only the one-line ambient value + pointer; the mechanic prose was removed and relocated to devshop-mode.md — consistent with the new routing rule the same PR introduces (eats its own dog food).

### Trust-boundary / SQL / auth

NONE, as expected. Diff grep for SQL verbs / `getUser` / service-role / `eval`/`exec` returns only doc-prose substring matches ("Delete from CLAUDE.md…", existing guard-table text quoting `posthog.capture`), no added code.

## Dismissals

None.
