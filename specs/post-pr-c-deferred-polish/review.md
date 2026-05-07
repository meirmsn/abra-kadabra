# Review — post-pr-c-deferred-polish

## Audit 1: manual (2026-05-07)

<!-- audited-at: 37c1074af7a5ff3af5899fbb797530bc7405de37 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none) — single fix commit closes 2 deferred-low items from
  `specs/ak-check-docs-and-tests/review.md § Audit 1`. The
  `new-project/SKILL.md` rename catch-up substitutes 2 verified strings
  (`check-docs-freshness-project.sh` → `check-docs-coverage-project.sh`
  and `§ Project Docs Hierarchy` → `§ Project Docs Coverage`); both
  rename targets exist on disk + in conventions.md. No new behavior, no
  new structural unit. Cross-doc coherence preserved (post-PR-C names
  used consistently).

### Tests findings

- (none) — the four bats setup() edits convert defensive `|| skip` to
  inline-rationale comments so a SKILL.md rename surfaces as a hard
  assertion failure rather than invisible green-by-skip. Self-covering:
  the existing "SKILL.md exists at the expected path" `@test` in each
  file now actually fires rather than being silently skipped. No new
  tests needed; the change improves the existing tests' fail-shut
  behavior. (PR-A's `/ak-tests-review § Skipped tests audit` lists
  exactly this pattern as the bug class being fixed.)

### Bypass trailer audit

- 37c1074 `Docs-Coverage-Bypass:` — VERIFIED. Bypass body cites the
  prior Audit 1's deferred-low items; both claims verified against
  `specs/ak-check-docs-and-tests/review.md § Audit 1` (lines for both
  classes present). Both named in-diff phrases
  (`check-docs-coverage-project.sh`, `§ Project Docs Coverage`)
  grep-verify in the staged diff. Rename catch-up plus bats hardening
  isn't a new capability — Layer 1's surface→doc rule firing on the
  skill-file edit is the rule's documented over-trigger case for
  rename-only edits, exactly the case bypass trailers exist for.
