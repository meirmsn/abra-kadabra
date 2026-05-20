<!-- audited-at: e236ae01cbcfd6d236698876415213e4a76172bd -->
<!-- range: 900c572d29c79a1be873ab02d5007dc5f17d889c..HEAD -->
<!-- mode: devshop self-mode (GIT_ROOT=/devshop) -->

Clean — no docs findings.

### Audit-1 closure verification

This audit window contains the polish commit (`9796b71`) addressing all three
Audit-1 findings plus the trail commits (`eb68bb6` docs + `e236ae0` SHA typo fix).
Closure verified per-finding:

- **Audit-1 [high]** `SKILL.md` Phase 4.2 DCG rationale — **CLOSED**.
  Prose rewritten (lines 934-957). Now names `core.git:push-force-short`
  specifically, identifies the empirically-verified false-positive shape (compound
  command with `git push` + separate `-f` elsewhere triggers BLOCKED even when
  no `git push -f` exists), and adds independent operability rationale
  (per-step Bash calls preserve partial-success state for operator recovery).
  Re-verified via `dcg test`: `git push origin main && submodule deinit -f --all`
  → `BLOCKED: core.git:push-force-short`. Empirical claim now matches the
  installed dcg 0.4.0 behavior. The bats assertion at
  `kit/tests/util-ak-merge-devshop.bats:431-448` was updated in lockstep
  (greps `false-positive` + `push-force-short` instead of stale `pattern-match`).

- **Audit-1 [medium]** `workflow.md` skill-map staleness — **CLOSED**.
  Row at line 477 now describes `$ANCHOR` anchor-selection between
  `origin/main` and local `main`, Phase 1's interactive medium-halt with
  `DEVSHOP_AUDIT_MEDIUM_POLICY=proceed` env-hatch, and Phase 4.2's
  separate-Bash-calls teardown. Cross-doc coherence restored — discovery
  doc no longer contradicts implementation doc.

- **Audit-1 [low]** `DEVSHOP_AUDIT_MEDIUM_POLICY` not registered in canonical
  bypass inventory — **CLOSED**. Added to `kit/docs/guide/hooks.md` table at
  line 450 with full description, scope (`/ak-merge-devshop` Phase 1 audit,
  medium-only), and Source pointer back to the SKILL.

### Section A — Coverage

Surface touched in this audit window:
- `.claude/skills/devshop/merge-devshop/SKILL.md` — rubric expects
  `workflow.md` OR `CLAUDE.md`. `workflow.md` was staged. ✓
- `kit/docs/guide/hooks.md` — touched as doc-side update, not as covered surface. ✓
- `kit/docs/guide/workflow.md` — touched as doc-side update. ✓
- `kit/tests/util-ak-merge-devshop.bats` — `kit/tests/**` carve-out (no firing). ✓
- `specs/ak-merge-devshop-hardening/{review.md,gates/audit-1-*.md}` — audit
  artifacts, not subject to coverage rubric. ✓

Coverage clean.

### Section B — Adequacy

Each touched doc edit carries a substantive new claim, none are stub edits.
Verified named-section claims by grep:

- `kit/docs/guide/hooks.md § Bypass flags + env hatches` — section exists at
  `hooks.md` line 425+ (table format); new row inserted at line 450 fits the
  established schema (env var | description | scope).
- `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 1` — referenced in the
  hooks.md new row as Source; phase header confirmed at SKILL.md:548.
- `"verified via dcg test"` — empirically verified by this auditor:
  `dcg test "git push origin main && submodule deinit -f --all"` →
  `BLOCKED: core.git:push-force-short`. Claim is true.
- `"home-os-skill-polish-batch teardown (2026-05-20)"` — corroborated by
  audit-1-docs.md context + the operator memory in SKILL.md Phase 1's
  "Codified from" footer at lines 650-657.
- `$ANCHOR auto-flips between origin/main and local main when local carries
  an unpushed release commit` — matches Phase 2 SKILL.md prose semantics
  (anchor-selection logic landed in the prior audit window, before this range).

Adequacy clean.

### Section C — Cross-doc coherence

The polish *reconciles* the prior coherence gap (workflow.md skill-map vs.
SKILL.md implementation) — no new contradictions introduced. No renamed or
deleted files in range (`RENAMED_DELETED` empty). The DCG-rationale rewrite
inside SKILL.md does not create downstream stale references — no other doc
asserted the prior (wrong) `pattern-match` rationale; grep across all reference
docs returns only the corrected text + the inline rationale in the
Audit-1-docs sink (which is an audit artifact, not a load-bearing reference).

Coherence clean.

### Section D — Bypass trailer audit

`git log --format='%H%n%B%n---' 900c572d29c79a1be873ab02d5007dc5f17d889c..HEAD
| awk '/^Docs-Coverage-Bypass:/'` → empty. No `Docs-Coverage-Bypass:` trailers
in range. No `CLAUDE-MD-Bypass:` trailers in range.

### Section E — CLAUDE.md hygiene

Skipped — devshop self-mode (Section E is project-mode-only).

### Summary

- **Coverage (Section A)**: clean
- **Adequacy (Section B)**: clean — Audit-1 [high] empirical-claim defect closed by the polish
- **Coherence (Section C)**: clean — Audit-1 [medium] discovery-vs-implementation gap closed by the polish
- **Bypass trailers (Section D)**: no trailers in range
- **CLAUDE.md hygiene (Section E)**: skipped (devshop self-mode)

Totals: high=0 medium=0 low=0
