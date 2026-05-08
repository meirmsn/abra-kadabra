# Review — ak-merge-devshop

## Audit 1: manual (2026-05-07)

<!-- audited-at: d31686d5a647cea62684caa0abad7ac01ff9190a -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=5 low=0

### Docs findings

### [domain: docs] [section: C] [severity: medium]

**File**: kit/docs/guide/architecture.md:92,98
**What**: Section "Doing devshop work" still describes ff-merge as the canonical merge flow ("audit-time `/ak-check-docs-and-tests` (fired before each ff-merge) is the outer gate. Land via feature branch + `ff-merge` to main locally"; code block shows `git merge --ff-only feat/<topic>`). The diff repointed CLAUDE.md to `/ak-merge-devshop`; this sibling guide doc was not updated, so the two reference docs now contradict.
**Why**: Cross-doc coherence drift. An operator reading `architecture.md` for the merge convention will get the OLD instructions, run `git merge --ff-only` by hand, and bypass the audit gate (Phase 1) + structured commit message (Phase 0.3) the new convention is meant to enforce.
**Fix**: Update kit/docs/guide/architecture.md:92 to reference `/ak-merge-devshop` ("audit-time review fires automatically inside `/ak-merge-devshop` Phase 1") and lines 96-101 (the bash code block) to either (a) replace the manual sequence with `/ak-merge-devshop`, or (b) keep the manual block as historical with a "now superseded by `/ak-merge-devshop`" note.

### [domain: docs] [section: C] [severity: medium]

**File**: kit/docs/guide/conventions.md:587
**What**: "Per-merge (audit-time)" bullet describes the audit firing "before each ff-merge to main" — uses the legacy "ff-merge" terminology that the new convention replaced.
**Why**: Same drift as architecture.md. The `/ak-tests-review` description references the wrong merge flow; readers piecing together "when does my test review actually fire" hit a stale answer.
**Fix**: Change "before each ff-merge to main, fired by `/ak-check-docs-and-tests`" to "before each merge to main (fires automatically inside `/ak-merge-devshop` Phase 1, which delegates to `/ak-check-docs-and-tests`)".

### [domain: docs] [section: B] [severity: medium]

**File**: CLAUDE.md:69
**What**: `Devshop shipping flow` step 2 describes the structured commit message as "prose summary + key details + verbatim per-commit history under a `## Squashed commits` section". The format refactor in commit `d31686d` changed this to "bullet-led summary sections + key details + compressed per-commit bullet list" — but the CLAUDE.md edit (in commit `d810b7a`) was not updated to match.
**Why**: Touched doc has a stale claim that mis-describes what `/ak-merge-devshop` actually produces. Operators reading CLAUDE.md to understand the format will look for "verbatim history" and find compressed bullets instead.
**Fix**: Change "prose summary + key details + verbatim per-commit history under a `## Squashed commits` section" to "bullet-led summary sections + key details + compressed per-commit bullet list under a `## Squashed commits` section, SHAs recoverable via `git reflog`" — matching the workflow.md catalog row description that WAS updated.

### [domain: docs] [section: B] [severity: medium]

**File**: .claude/skills/ak-merge-devshop/SKILL.md:6-7,29-30,138,144
**What**: SKILL.md is internally inconsistent about the format it produces. Frontmatter description (lines 5-9) says "verbatim per-commit history under a `## Squashed commits` section". Intro paragraph (lines 28-33) says "prose summary + key details + verbatim per-commit history, all in one commit on main". Phase 0.3 step 1 (line 138) says the git log output "becomes the verbatim '## Squashed commits' section". But the format spec (lines 197+ § "Why bullet-led summary, not paragraphs") and (lines 224+ § "Why compressed bullets, not verbatim bodies") describe bullet-led summary + compressed bullet list — which is what the skill actually produces.
**Why**: The new skill's own self-description contradicts its own format spec. A reader skimming the frontmatter or intro will form the wrong mental model, then hit the format spec deeper in the file and have to reconcile two different claims. The `/` autocomplete description (driven by the `description:` frontmatter) will surface the stale "verbatim per-commit history" phrase to operators.
**Fix**: Update SKILL.md frontmatter description to "bullet-led summary + key details + compressed per-commit bullet list (SHAs recoverable via `git reflog`)". Update the intro paragraph (lines 28-33) to match. Update line 138 to either say "becomes the input the composer reads to write the compressed bullet list" or remove the "verbatim" framing entirely.

(No Docs-Coverage-Bypass trailers in range.)

### Tests findings

### [domain: tests] [section: A] [severity: medium]

**File**: .claude/skills/ak-merge-devshop/SKILL.md (no paired .bats)
**What**: New skill ships ~430 lines of bash logic — FEATURE-name regex, audit-state SHA parsing (`<!-- audited-at: -->` extraction), post-squash tree-equality check, workflow-scope detection, conventional-commit prefix-mapping for the squash subject — without a paired `kit/tests/util-ak-merge-devshop.bats` (or equivalent) smoke test. The peer pattern is established: `kit/tests/util-build-phase58-audit-parser.bats` tests `/ak-build`'s audit-parser bash one-liners; `kit/tests/util-bypass-trailers.bats` tests `/ak-check-docs-and-tests`'s trailer harvest.
**Why**: This skill's bash logic had **two regex bugs** caught only by manual smoke-testing during this very branch — `feature/` prefix not handled, then sed delimiter `|` conflicting with the alternation group's `|`. Both shipped to commit `d810b7a` and only surfaced when an operator ran the skill against a real branch. Without a codified bats test, the next regression in this layer (e.g., a 7th type prefix added without expanding the regex; a tree-equality check broken by a `git diff` flag change; an SHA-extraction regex breaking on a future review.md format tweak) would re-surface only on the next operator-driven smoke test — could be weeks or months away. The smoke-test-as-coverage model is exactly what util-bats tests are designed to replace for stable bash-logic surfaces.
**Fix**: Add `kit/tests/util-ak-merge-devshop.bats` covering at minimum:
(a) FEATURE extraction matrix — table-driven test across `feat/`, `feature/`, `fix/`, `docs/`, `chore/`, `refactor/` prefixes, plus a "branch with no recognized prefix" case verifying the guard fires (exit non-zero, error message names the branch).
(b) Audit-state SHA parser fixtures — `review.md` with 0, 1, and 3 `## Audit N` sections; verify `LATEST_SHA` resolves to the bottommost stamp, `AUDIT_N` increments correctly, and the empty-file case yields empty `$LATEST_SHA`.
(c) Conventional-commit prefix selection — given a list of constituent commit subjects, the squash subject's prefix matches the highest-impact rule (`feat!:` > `feat:` > `fix:` > `chore:` etc.).
(d) Tree-equality check — fixture where main and feature branch trees are equal (passes), and where they differ in one file (fails with the expected error message).
Severity is **medium** because (i) Phase 0's explicit operator gate catches most failures interactively before they ship, AND (ii) this is a coverage gap not a security gap. **Not high** because no auth / RLS / deploy boundary is involved.

(No Tests-Coverage-Bypass trailers in range.)

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-07)

<!-- audited-at: fdd07f1bc8c1e0e4391bb72c61cbfc873456b5af -->
<!-- range: d31686d5a647cea62684caa0abad7ac01ff9190a..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

Clean — no docs findings.

### Tests findings

Tests look solid — no findings.

### Bypass trailer audit

- (none)

## Audit 3: manual (2026-05-07)

<!-- audited-at: f6d468ef2bbc05ca3e346ed2b36ac4c0f1b934fb -->
<!-- range: fdd07f1bc8c1e0e4391bb72c61cbfc873456b5af..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

Clean — no docs findings.

### Tests findings

Tests look solid — no findings.

### Bypass trailer audit

- (none)

### Note

User feedback during smoke test surfaced a better fix for Audit 1's
findings: rather than syncing format-spec text across CLAUDE.md +
architecture.md + conventions.md + workflow.md + SKILL.md, the SKILL.md
should be the single source of truth and the others should reference
it without duplicating detail. Commit `f6d468e` slimmed CLAUDE.md +
workflow.md accordingly. Audit 3 verifies the slim is clean.
