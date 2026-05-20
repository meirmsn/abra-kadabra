### [domain: docs] [section: C] [severity: high]
**File**: .claude/skills/devshop/pre-ship/SKILL.md:251,380-398
**What**: The `slow-job-lifecycle` gate's table row + dedicated section still describe the pre-2026-05-19 conditional-on-threshold behavior — title "Slow-job CI enabled past Phase 1c/1g", scope `n/a (no integration tests or E2E specs — Phase 1c/1g threshold not crossed)`, outcomes list omits the new Check 4 (hashFiles guards), Check 4b (Start local Supabase unguarded), Check 6 (changes-job + needs/if wiring), Check 7 (branch protection). This skill is the canonical user-facing description of the gate's behavior; it is NOT touched by this PR but the behavior it documents changed substantively in `kit/scripts/preship/slow-job-lifecycle-check.sh` (now runs on every project, not just past-threshold; new checks added; no `n/a (threshold not crossed)` exit path remaining).
**Why**: Cross-doc coherence break on a load-bearing surface. Operators reading `.claude/skills/devshop/pre-ship/SKILL.md` will form the wrong mental model of what gate 2c does (still think "only past threshold") and may dismiss findings that the new active-from-day-one gate actually catches. The gate's docstring + the convention doc already moved to the new model; the consumer skill is the contradicting outlier.
**Fix**: In `.claude/skills/devshop/pre-ship/SKILL.md`: (1) Row 251 — update title to "Slow-job CI active + structurally intact" and scope to "always (no gating on threshold)". (2) Section heading line 380 — drop "past the Phase 1c/1g threshold". (3) Section body lines 382-398 — rewrite to match the day-one-active model: scope is `always` when `.github/workflows/ci.yml` exists; outcomes drop the `n/a (... threshold not crossed)` row; `pass` outcome description enumerates the new check set (active stub, both jobs uncommented, runtime-gate predicate, edge-runtime retry, hashFiles guards on content-dependent steps, unguarded Start local Supabase, branch protection includes `slow`). Add cross-ref to `kit/docs/guide/conventions.md § Slow-Job Lifecycle § Structural enforcement (regression guard)`.

### [domain: docs] [section: C] [severity: medium]
**File**: kit/docs/guide/conventions.md:16
**What**: Table-of-contents entry `[Uncommenting checklist](#uncommenting-checklist)` is dangling — the `### Uncommenting checklist` section that anchor referenced was removed from the same file in this PR (commit 4592bb1 rewrote the section as Why-active / Per-step empty-state guards / Extending the active stub).
**Why**: A reader clicking the TOC link lands at no anchor; on GitHub the click is silently no-op. Worse: leaves a phantom "this still exists" signal in the doc's own TOC, contradicting the new model the prose body describes.
**Fix**: Delete line 16 (`  - [Uncommenting checklist](#uncommenting-checklist)`). While editing, also: (a) line 18 `[Structural enforcement](#structural-enforcement)` needs anchor updated to `#structural-enforcement-regression-guard` to match the renamed heading at line 195; (b) consider adding TOC entries for the new sub-sections — `Why active from day one`, `Per-step empty-state guards`, `Extending the active stub` — to surface them at TOC scan-depth.

### [domain: docs] [section: C] [severity: low]
**File**: .claude/skills/devshop/build/SKILL.md:617,673,836
**What**: Three references to gate 2c by name in `build/SKILL.md`. Each is a bare gate-name enumeration in the build skill's gate-chain listing; none describe the gate's behavior. Listed for completeness, not as a finding requiring fix.
**Why**: Section-C grep sweep surfaced these; they are NOT contradicting refs.
**Fix**: No action — informational. Bare gate-name enumerations don't need to track gate-behavior renames.

### [domain: docs] [section: B] [severity: low]
**File**: kit/docs/guide/conventions.md:154-296 (Slow-Job Lifecycle section rewrite)
**What**: The new `### Extending the active stub` sub-section (line 187) cites `pnpm --filter apps/web test:e2e` as the template's E2E invocation. Verified against `template/.github/workflows/ci.yml` line 230 — match confirmed. The new `### Per-step empty-state guards` table cites Playwright/migration glob patterns (`apps/web/e2e/**/*.spec.ts`, `supabase/migrations/*.sql`); verified against the template ci.yml hunks in this PR (lines 332, 366, 376, 381 of the template diff) — all matches confirmed.
**Why**: Adequacy spot-check on the new prose. All cited paths/globs exist at HEAD as described. No finding; recorded as confirming evidence.
**Fix**: No action.

### [domain: docs] [section: D] [severity: low]
**What**: No `Docs-Coverage-Bypass:` trailers in commit range (origin/main..HEAD, 2 commits).
**Why**: Bypass-trailer mechanism is informational for now; absence is not a finding.
**Fix**: No action.

## Bypass trailer harvest

No Docs-Coverage-Bypass trailers in range.

## Summary

- **Section A (Coverage)**: 0 findings. Every touched source surface has matching doc edits — `kit/scripts/preship/slow-job-lifecycle-check.sh` rewrite is mirrored in `kit/docs/guide/conventions.md § Slow-Job Lifecycle § Structural enforcement (regression guard)` + `kit/docs/guide/workflow.md § 2c` + `.claude/skills/devshop/new-project/SKILL.md § Step 24` (note: pre-ship/SKILL.md gap reported under Section C instead); `template/.github/workflows/ci.yml` rewrite is mirrored in `kit/docs/guide/ops.md § Template slow-job ships ACTIVE` + `kit/docs/guide/conventions.md`; `template/.nvmrc` Node bump is mirrored in the ci.yml commented rationale + ROADMAP C1 closure; `kit/tests/template-ci-yml-shape.bats` rewrite is mirrored in the tests' own header preamble (audit-time tests-review handles the test-side).
- **Section B (Adequacy)**: 0 findings. Touched doc hunks are substantive (not whitespace/reflow); named claims verified against the template ci.yml diff and the touched ROADMAP / SKILL.md sections; the Per-step empty-state guards table grounds every claim in a specific step + glob.
- **Section C (Coherence)**: 2 findings (1 high, 1 medium). One high: `.claude/skills/devshop/pre-ship/SKILL.md` was NOT touched by this PR but documents the gate that materially changed behavior — its row/title/scope/outcomes are now contradictory to the touched conventions/workflow/new-project docs. One medium: `kit/docs/guide/conventions.md`'s own TOC has a dangling `#uncommenting-checklist` anchor + a stale `#structural-enforcement` anchor.
- **Section D (Bypass trailers)**: 0 trailers in range.
- **Section E (CLAUDE.md hygiene)**: SKIPPED — devshop self-mode (GIT_ROOT == /devshop).

high=1 medium=1 low=3
