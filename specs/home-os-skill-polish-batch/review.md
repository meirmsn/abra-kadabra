# Review — home-os-skill-polish-batch

## Audit 1: manual (2026-05-20)

<!-- audited-at: 937a678521a3a0967cfad6ca7346ea0d671f3583 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=2 low=6

### Docs findings

- [medium] `kit/docs/guide/hooks.md:198` — B3 short-circuit not in the canonical pre-push contract's § 3 "Short-circuits" list; operator reading hooks.md today can't predict the new fast-path behavior. **Fix**: add a fourth bullet under § 3 enumerating the SHA-enumeration fast-path (project-mode; non-trivial push; PR body contains every `origin/main..HEAD` commit SHA as full or ≥7-char abbreviation; PASS without invoking the LLM reviewer). Cross-ref `kit/tests/util-pre-push.bats § B3`. Full text in `gates/audit-1-docs.md`.
- [low] `specs/home-os-skill-polish-batch/spec.md:48,97,99,202,243,256,269` — spec.md uses "Step 12.5" throughout but implementation landed at "Step 12.6" (commit `8b7c2b3` body explains: Step 12.5 already existed for Supabase SSR boilerplate). The 4 sibling-doc cross-refs (CLAUDE.md, FAQ.md, architecture.md, conventions.md) correctly point at 12.6; only spec.md was not back-patched. **Fix**: `sed -i 's/Step 12.5/Step 12.6/g' specs/home-os-skill-polish-batch/spec.md`.
- [low] (range-level) — no `Docs-Coverage-Bypass:` trailers in range; harvest legitimately returns zero rows. Informational.

### Tests findings

- [medium] `kit/tests/structural-invariants.bats` — E5 `PROJECT_NAME_PLACEHOLDER` grep assertion the spec promised was not added. Regression-protection guard the spec explicitly named is missing. **Fix**: add `@test "template: packages/core/ contains no PROJECT_NAME_PLACEHOLDER hits"` with `grep -r 'PROJECT_NAME_PLACEHOLDER' "$DEVSHOP/template/packages/core/"` returning non-zero exit.
- [low] `kit/tests/util-pre-push.bats:259-280` — all 4 new B3 cases use single-commit fixtures; the partial-match fall-through codepath at `kit/hooks/pre-push.sh:133-142` is dead in current tests. A regression flipping the loop logic would pass all four. **Fix**: add a fifth case with 2+ commits where the PR body names only the first SHA → reviewer fires.
- [low] `kit/tests/structural-invariants.bats` — E10 `[OPERATOR-ONLY]` grep assertion the spec promised was not added. **Fix**: add `@test "ak-new-project: Step 6 + Step 7 carry [OPERATOR-ONLY] marker"` with `grep -qE '^### Step 6.*\[OPERATOR-ONLY\]'` + same for Step 7.
- [low] `kit/tests/` — A5 `~/.claude/skills/gstack` symlink grep assertion the spec promised was not added (full integration test deferred to fresh scaffold per spec; the grep-based shape guard was in-scope). **Fix**: add `@test "ak-new-project: Step 9 documents ~/.claude/skills/gstack symlink"` with prose-or-command shape grep against the SKILL.md.
- [low] `kit/tests/util-pre-push.bats:244-256` — `gh_stub_with_pr_body` helper uses nested-heredoc with unquoted outer; future tests passing a PR body containing literal `$` would silently interpolate at stub-creation time. Footgun for future contributors. **Fix**: either document the constraint in a comment on the helper, or quote the outer heredoc and pass `$pr_body` via env. Option (a) is the lower-effort fix.
- [low] (range-level) — no `Tests-Coverage-Bypass:` trailers in range; harvest returned zero rows. Bypass-trailer mechanic activates with PR-C; this audit moment may legitimately harvest zero rows. Informational.

### Bypass trailer audit

- (none)
