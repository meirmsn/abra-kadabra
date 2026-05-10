<!-- audited-at: 3a29d075efb3ef4f1df489cd5e7696a8f5f4c882 -->

# Pre-ship review: qa-na-tightening

Branch: `feature/qa-na-tightening`
HEAD: `3a29d07`
Diff base: `origin/main`

## Phase 0: Preflight

- `gh auth status`: OK (logged in as meirmsn).
- Branch check: OK (not on `main`).
- Scope detection (`grep -E '^(apps/|packages/ui/|components/)' /tmp/preship-changed.txt`): no matches → `TOUCHES_UI` is empty.
- Diff path classifier (`path-classifier.sh diff-needs-stack origin/main HEAD`): exit=1 → diff does NOT need stack.
- Supabase bootstrap: skipped (advisory; no UI / app / package files in diff and no `supabase/{migrations,functions}/**` changes).
- Deploy boundaries reminder: no `supabase/migrations/**` or `supabase/functions/**` in diff → no auto-deploy implications.

Changed files (10 total — devshop-self only; verified positively: no `apps/**` or `packages/**` files in diff):

```
.claude/skills/devshop/pre-ship/SKILL.md
PLAN.md
kit/docs/guide/hooks.md
kit/docs/guide/workflow.md
kit/scripts/adversarial-review.sh
kit/scripts/preship/verify-story.sh
kit/tests/preship-verify-story.bats
kit/tests/util-adversarial-review-coreUserStoryNaReason.bats
specs/qa-na-tightening/spec.md
specs/qa-na-tightening/tasks.md
```

Outcome: preflight `pass`. No `blocked` tooling. Browser preflight is `n/a` because no UI changes.

## Gate 1: docs-check (ak)

**Scope:** PR touches `kit/`. Runs.

**Findings:** Both touched guide docs (`kit/docs/guide/hooks.md`, `kit/docs/guide/workflow.md`) are in sync — they describe the same shipped behavior (the new `coreUserStoryNaReason` adversarial-review check-type) and explicitly cross-reference each other plus `pre-ship/SKILL.md § Gate 9`.

- `hooks.md` adds a new "Pre-ship-time additions to the adversarial-review surface" subsection (lines 237-247) framing the check as NOT a commit-time `git -c devshop.<key>` flag, matching the spec's Gotcha note.
- `workflow.md § Core user story requirement` (lines 188-195) describes the same adversarial review and points back at `pre-ship/SKILL.md § Gate 9`.
- `kit/docs/OVERVIEW.md` not edited — high-level architecture map; new check-type is covered by the broad line 102 reference ("adversarial review") and detailed in `hooks.md` per the existing doc-routing convention.

**Outcome:** `pass`.

## Dismissals

None

## Gate 2: metrics-check (ak)

**Scope:** user-facing code PRs.

**Outcome:** `n/a` — diff has no `apps/**`, no `packages/**`, no `supabase/functions/**`. Verifiable file-path claim: `grep -E '^(apps/|packages/|supabase/functions/)' /tmp/preship-changed.txt` returns exit=1 (no matches). Diff is `kit/scripts/**`, `kit/tests/**`, `kit/docs/**`, `.claude/skills/devshop/**`, `specs/**`, `PLAN.md` only — no user-facing code surfaces.

## Dismissals

None

## Gate rls-coverage (ak)

**Scope:** PRs that touch `supabase/migrations/**`, `packages/core/src/api/**`, `apps/web/app/**`, or `supabase/functions/**`.

**Outcome:** `n/a (no migration or client API change)` — verifiable: `grep -E '^(supabase/migrations/|packages/core/src/api/|apps/web/app/|supabase/functions/)' /tmp/preship-changed.txt` returns exit=1.

## Dismissals

None

## Gate slow-job-lifecycle (ak)

**Scope:** runs when integration tests (`*.integration.test.ts`) or E2E specs (`apps/*/e2e/*.spec.ts`) exist.

**Outcome:** `n/a (no integration tests or E2E specs — devshop-self has no apps/ or packages/ directory; Phase 1c/1g threshold not applicable)`. Verifiable: `find /devshop/packages /devshop/apps -name '*.integration.test.ts'` and `find /devshop/apps -path '*/e2e/*.spec.ts'` both return zero matches.

## Dismissals

None

## Gate changed-tests-local (ak)

**Scope:** runs when diff includes `apps/**`, `packages/{core,ui}/**`, `*.integration.test.ts`, `apps/*/e2e/*.spec.ts`, or `supabase/{migrations,functions}/**`.

**Outcome:** `n/a (no stack-needing paths in diff)` — diff is entirely `kit/scripts/**`, `kit/tests/**`, `kit/docs/**`, `.claude/skills/devshop/**`, `specs/**`, `PLAN.md`. None of those paths are stack-needing per `path-classifier.sh`.

## Dismissals

None

## Gate 3: responsive-theme (ak)

**Scope:** UI PRs only.

**Outcome:** `n/a (no UI changes)` — verifiable file-path claim: no `apps/**` or `packages/**` files in diff (this PR's whole point is to enforce that vocabulary). `grep -E '^(apps/|packages/ui/|components/)' /tmp/preship-changed.txt` returns exit=1.

## Dismissals

None

## Gate 5: /ak-check-docs-and-tests (Audit 1 — pre-polish)

**Scope:** always.

`/ak-check-docs-and-tests` ran as Audit 1 over `origin/main..HEAD` (5 commits: `49e405d` → `3a29d07`). Sub-skills `/ak-docs-review` and `/ak-tests-review` ran sequentially; structured `## Audit 1` section landed below.

- **Docs findings:** 0/0/0 across Sections A (coverage), B (adequacy), C (cross-doc coherence), D (bypass trailers). Coverage satisfied: every touched script (`adversarial-review.sh`, `verify-story.sh`) has a paired guide-doc edit (`hooks.md`, `workflow.md`) plus the SKILL.md note. Adequacy: each touched doc names the new check-type, the ACCEPT/REJECT vocabulary, model routing, and the propagation contract. Coherence: `CLAUDE.md`, `OVERVIEW.md`, `README.md`, `FAQ.md` unchanged but consistent — the model-split mention in CLAUDE.md is representative, not exhaustive, so no contradiction. Bypass trailers in range: 0.
- **Tests findings:** 0/0/0. Section A (coverage): the new `coreUserStoryNaReason` check-type has 16 BATS cases in `kit/tests/util-adversarial-review-coreUserStoryNaReason.bats`, mirroring the reference `localTestSkipReason` suite. The new wiring in `verify-story.sh` has two new cases in `kit/tests/preship-verify-story.bats` (accept + reject paths). Section B (quality): assertions are content-specific (`assert_output --partial`, `grep -q` for load-bearing phrases, mock-claude verdict capture); no weak `toBeDefined`-style assertions; no `.skip` / `.only` patterns; bash + BATS so Playwright/WebKit/Zod/realtime rubrics are N/A. Section C: 0 bypass trailers.

**Outcome:** `pass`. 0 high-severity findings → no halt. Audit 1 section appended below per the parse contract.

## Dismissals

None

## Audit 1: pre-polish (2026-05-10)

<!-- audited-at: 3a29d075efb3ef4f1df489cd5e7696a8f5f4c882 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none)

### Tests findings

- (none)

### Bypass trailer audit

- (none)

## Gate 4: /simplify

**Scope:** always.

Reviewed all changed code in the diff (bash scripts + BATS):

- **Reuse:** `coreUserStoryNaReason` case branch mirrors `localTestSkipReason`'s shape (diff-path gathering with `origin/main...HEAD` + `HEAD~1` fallback). Borderline duplication (~5 lines) — kept inline because every case-branch builds its own CONTEXT framing, and a 2-case shared helper adds indirection without payoff. The `extract_bold_section` helper is genuinely new (first markdown bolded-marker extractor) and necessary: `extract_convention_section` resolves only `## ` headings, but the workflow.md target is a `**bolded**` sub-section. `get_workflow_to_inline` correctly kept as a sibling to `get_conventions_to_inline` per spec D4 (different file).
- **Quality:** awk in `extract_bold_section` is clean (substring match via `index()`, tracks `prev_blank`, exits on next `## ` or blank-followed-by-bold). Comments explain non-obvious WHY (regex char-set source from `is_na_core_story`; convention drift gotchas). Triple-sed rationale extractor in `verify-story.sh` is readable (trim → strip N/A marker → trim again) and the inline comment names the regex source.
- **Efficiency:** fires once per pre-ship run; no hot-path concerns. `claude -p` dominates cost; everything else negligible.

No fixes needed. Code matches the established `adversarial-review.sh` patterns.

**Outcome:** `pass`.

## Dismissals

None

## Gate 6: /review

**Scope:** always — pre-landing code review of the diff against `origin/main`.

Pre-landing review categories scanned (per `/review` rubric): shell-injection, SQL safety, LLM trust boundary, conditional side effects, enum completeness, error-path coverage. Diff is 100% bash + BATS + markdown — no SQL, no client code, no auth surface.

**Findings:** 0 critical, 4 informational (all classified as design-choice-not-actionable; see Dismissals).

- **Shell-injection** — `verify-story.sh:138-142` extracts `rationale` via four-stage piped sed/grep then passes it as `"$rationale"` (quoted) to `bash adversarial-review.sh coreUserStoryNaReason "$rationale"`. The rationale text is treated as a positional argument by the child shell — never `eval`'d, never spliced into a constructed command. Inside `adversarial-review.sh:72`, `REASON="${2:-…}"` captures it as a parameter, then it's interpolated via `$REASON` into the heredoc-built `PROMPT` variable (line 575) and written to a tempfile (`echo "$PROMPT" > "$PROMPT_FILE"`). The tempfile is read on stdin by `claude -p` via `< "$PROMPT_FILE"` (line 673) — never a shell argument. Clean.
- **LLM trust boundary** — Reviewer verdict text (`REVIEW`) is captured from `claude -p` stdout (line 673), grep-scanned for `^FAIL` (line 698), echoed verbatim to caller stdout on FAIL (line 699), and the script exits 0 or 1 based purely on the grep match. `verify-story.sh:145` captures the verdict via `verdict=$(... 2>&1)` and on reject branches (line 148) echoes it back on stdout before `return 1`. Verdict never `eval`'d, never used as a path, never used as a shell arg. Exit code is the contract; verdict text is data only. Clean.
- **SQL safety** — `n/a`. No SQL changes. `grep -E '(supabase/migrations/|\.sql)' /tmp/preship-changed.txt` returns no matches.
- **Conditional side effects** — The new `coreUserStoryNaReason` case branch (`adversarial-review.sh:233-271`) only sets `CONTEXT` (a string variable). No file writes, no git mutations, no network calls outside the existing `claude -p` invocation that fires for every check-type. Convention-inlining (lines 487-509) is read-only file extraction. The `verify-story.sh` reject path adds `return 1` plus stdout emission — no destructive side effects. Clean.
- **Enum completeness** — The new check-type was added to: (1) the `case "$CHECK_TYPE" in` switch (line 233); (2) `get_model_for_check_type()` Sonnet branch (line 549); (3) `get_workflow_to_inline()` (line 454); (4) the unknown-check-type fallback message's enumerated survivor list (line 367); (5) the docstring header surviving check-types list (line 29-32); (6) the model-routing comment (line 56). All six enumeration sites updated in lockstep — no drift. Clean.

**Borderline informationals (4 — all dismissed):**

1. `verify-story.sh:138-142` rationale-extraction multi-line handling — `grep -m1 -v '^[[:space:]]*$'` takes the first non-empty line of the body. If a multi-line rationale spans paragraphs, only the first is judged. Design choice: rationales are conventionally a single paragraph (the spec template models this); a multi-paragraph rationale is itself a smell the reviewer should question. Not flagged actionable.
2. `verify-story.sh:145` `2>&1` stderr merging — `verdict=$(bash "..." adversarial-review.sh ... 2>&1)` merges stderr into stdout. This means transient retry messages from `adversarial-review.sh:677` (`echo "⚠ Adversarial review attempt $ATTEMPT failed..."`) land in the verdict variable. Confirmed intentional by the previous agent: the merge is what guarantees retry diagnostics surface in the Gate 9 report when the API is flaky, not just the final verdict. Confirming-intent dismissal.
3. `adversarial-review.sh:401-407` `extract_bold_section` silent-skip on missing heading — if the heading marker is not present in the file, the awk body never sets `in_s=1` and prints nothing; the caller's `[ -n "$WORKFLOW_BODY" ]` guard skips the inlining block silently. Design choice: matches the existing `extract_convention_section` (line 384-392) shape, where a missing heading also prints nothing. The BATS suite covers the in-fixture "happy path" only — relying on the convention that workflow.md fixtures must mirror real file shape (spec Gotcha §6, BATS suite setup lines 49-71). Lockstep test-fixture-versus-real-file discipline is the existing pattern; not flagged actionable.
4. `adversarial-review.sh:240-249` diff-paths gathering — near-duplicates the equivalent block in `localTestSkipReason` (lines 215-228). Borderline DRY violation (~5 lines × 2 sites). Kept inline because each case-branch builds its own CONTEXT framing string, and a shared helper would force every check-type's CONTEXT through a common shape — which would obscure that `coreUserStoryNaReason`'s framing ("rationale must be a verifiable claim") is meaningfully different from `localTestSkipReason`'s ("explain why each test category was skipped"). Design-choice dismissal — Gate 4 (/simplify) already weighed this and confirmed.

**Outcome:** `pass`.

## Dismissals

The 4 informationals above are all design-choice / confirming-intent dismissals consistent with the spec's Decisions section (D1-D6) and Gotchas. None reflect a fix the reviewer is owed. No fix required; no follow-up tracked.

## Gate 7: /cso

**Scope:** PRs that touch security-relevant surfaces (auth, RLS, secrets, third-party HTTP, shell-execution surfaces with operator input).

**Outcome:** `pass`.

The diff's only execution surface is `kit/scripts/preship/verify-story.sh:145` invoking `bash adversarial-review.sh coreUserStoryNaReason "$rationale"` with operator-supplied rationale text. Threat-modelled in Gate 6 above (shell-injection category): rationale is passed as a quoted positional argument, captured into `REASON` variable, interpolated into a heredoc PROMPT string written to a tempfile, then read on stdin of `claude -p` via `< "$PROMPT_FILE"`. At no point does it touch `eval`, command substitution, or shell-argument expansion. Clean.

**Threat surface evidence:**

- `grep -E '^(supabase/|apps/|packages/)' /tmp/preship-changed.txt` → exit 1 (no matches). Confirms no auth, no SQL, no client code, no third-party HTTP surface added.
- `grep -nE 'eval|\$\([^)]*\$' kit/scripts/preship/verify-story.sh kit/scripts/adversarial-review.sh` returns no matches against operator-controlled text. The only `$(...)` command-substitutions are over fixed git commands (`git diff --name-only`, `git rev-parse`, `git branch`) — none take operator input.
- LLM verdict text propagation (Gate 6 § LLM trust boundary above) is exit-code-driven; verdict body is data-only on stdout, never converted to a shell arg or path.
- No new secrets surface. No new env var read. No third-party API calls beyond the existing `claude -p` invocation that every other check-type already uses.
- Devshop-self diff: no consumer-facing surfaces (the same reason as Gate rls-coverage's `n/a`).

No fixes needed; no findings.

## Dismissals

None

## Gate 8: /design-review

**Scope:** UI PRs only.

**Outcome:** `n/a (no UI changes)`. Verifiable file-path claim: `grep -E '^(apps/|packages/)' /tmp/preship-changed.txt` returns exit 1 (no matches). This PR's whole point is to enforce that vocabulary as the dogfooded ACCEPT example — eat-your-own-dogfood.

## Dismissals

None

## Gate 9: /qa

**Scope:** UI PRs only — devshop-self has no live web app to walk.

**Outcome:** `n/a`. Verifiable file-path claim: `grep -E '^(apps/|packages/)' /tmp/preship-changed.txt` returns exit 1 (no matches); no live web app exists in the devshop kit. The spec's `## Core user story` body is the literal `N/A — devshop pipeline tightening; touches kit/scripts/adversarial-review.sh, kit/scripts/preship/verify-story.sh, kit/tests/, kit/docs/guide/hooks.md, .claude/skills/devshop/pre-ship/SKILL.md only; no apps/** or packages/** files in diff.` — this is the dogfooded ACCEPT example.

**Eat-your-own-dogfood live signal (spec AC #6):** Invoked the new `coreUserStoryNaReason` check against this very spec via:

```
$ bash kit/scripts/preship/verify-story.sh verify-all \
    --feature qa-na-tightening --spec specs/qa-na-tightening/spec.md
Core user story is N/A — artifact assertion skipped for this PR
$ echo $?
0
```

The new check ran against the spec's own N/A rationale, the rationale's verifiable file-path claim PASSed adversarial review (Sonnet 4.6 reviewer accepted "no apps/** or packages/** files in diff" as the verifiable-claim shape per Rule #11 (a)), and `verify-story.sh` returned 0 with the existing "skipped" message. AC #6 satisfied with a live signal — not just the BATS mock at test case #10.

**BATS suite re-run:** All 41 cases across `kit/tests/util-adversarial-review-coreUserStoryNaReason.bats` (16) and `kit/tests/preship-verify-story.bats` (25) pass green. No regression in the existing reference suite or in the unknown-check-type fallback enumeration (AC #3 satisfied).

The live dogfood signal is a bonus acceptance signal; the gate outcome is `n/a` (no live web app).

## Dismissals

None

## Gate 10: /benchmark

**Scope:** PRs that change perf-relevant surfaces (page rendering, bundle size, query plans).

**Outcome:** `n/a (no perf surface)`. Same verifiable claim as Gate 8: `grep -E '^(apps/|packages/)' /tmp/preship-changed.txt` returns exit 1 (no matches). No web app, no client bundle, no SQL — nothing measurable by `/benchmark`.

## Dismissals

None

## Gate 11: convention-check

**Scope:** always.

Verified the new code follows existing devshop conventions across four sub-checks:

- **Bash conventions** — both `kit/scripts/adversarial-review.sh` (header line 69 unchanged) and `kit/scripts/preship/verify-story.sh` (line 30 unchanged) ship `set -euo pipefail`. New code in both files honors that contract: variables are declared `local`, expansions are quoted (`"$rationale"`, `"$verdict"`), and the rationale-extractor pipeline (`verify-story.sh:138-142`) handles empty input gracefully (the four-stage pipeline yields empty string → reviewer auto-FAILs via Rule #11 (d), as documented in spec Gotcha §5). Error-message conventions match (`echo "blocked: ..."` prefix matches existing style at lines 121, 159, 192).

- **awk helpers** — `extract_bold_section` (lines 399-409) follows the same shape as `extract_convention_section` (lines 384-392): `awk -v <var>=<value> '...'` invocation, `in_s` flag, `exit` on next-section marker. Variable names match the existing convention (single-letter `h` for heading parameter; `in_s` for in-section flag). The `prev_blank` tracking is genuinely new but well-commented (line 398 explains why bolded-marker termination needs blank-line lookahead).

- **BATS suite conventions** — `util-adversarial-review-coreUserStoryNaReason.bats` (234 lines, 16 cases) mirrors the `util-adversarial-review-localTestSkipReason.bats` reference suite's shape: same `setup()` pattern (`load helpers/setup`, `setup_mock_bin`, `create_test_repo`), same `MOCK_BIN/claude` heredoc pattern with `MOCK_CLAUDE_VERDICT` env var, same per-test `cd "$TEST_REPO"` discipline, same `[ -f "$CAPTURED_PROMPT" ]` + `grep -q ...` assertion shape. The `preship-verify-story.bats` extension (cases 33 + 34, lines 187-226) drops a per-test inline `claude` mock — this is the right shape because the two new tests need _different_ verdicts (PASS for the accept path, FAIL for the reject path) and per-test mock-overwrite is cleaner than a single setup-level mock with per-test env-var toggling.

- **Spec/tasks/review trio** — `specs/qa-na-tightening/spec.md` is well-formed (208 lines, all required sections present: Sources, Decisions, In scope, Out of scope, Files to create/modify, Tests, Task order, Gotchas, Acceptance/rollout/rollback, Core user story). `tasks.md` mirrors the spec's Task order section. `review.md` (this file) follows the canonical Gate-NN pattern with per-gate Outcome + Dismissals subsections. The `Audit 1` section was correctly appended below Gate 5 per the audit-time docs+tests parse contract.

**Outcome:** `pass`. No findings.

## Dismissals

None

## Gate 12: /ak-design-conformance

**Scope:** PRs that touch UI under a project with a `DESIGN.md` source-of-truth.

**Outcome:** `n/a (no UI; no DESIGN.md in devshop scope)`. Devshop kit has no `DESIGN.md` design-system contract — that file lives in consumer projects (e.g., `/workspace/DESIGN.md` for lalista). Verifiable file-path claim: `grep -E '^(apps/|packages/)' /tmp/preship-changed.txt` returns exit 1.

## Dismissals

None

## Gate 13: hero-shots-capture

**Scope:** UI PRs only — captures committed evidence of new screens for PR body and changelog.

**Outcome:** `n/a (no UI)`. Same verifiable claim as Gates 8, 10, 12: no `apps/**` or `packages/**` in diff.

## Dismissals

None

## Audit 2: post-polish (2026-05-10)

<!-- audited-at: f2ccdf7 -->
<!-- range: 3a29d07..f2ccdf7 -->

findings: high=0 medium=0 low=0

Range contents (3 commits):

- `0c96193` `chore(qa-na-tightening): pre-ship review (gates pass)` — review.md only
- `f44ec18` `chore(qa-na-tightening): BUILD-LOG entry` — BUILD-LOG.md only
- `f2ccdf7` `chore(roadmap): close Tightening /qa's n/a criteria (shipped via PR #31)` — PLAN.md + kit/ROADMAP.md

All three commits are pure bookkeeping artifacts — they record what shipped earlier in the same PR (already audited at Audit 1, stamp `3a29d07`). No new runtime code, no new behavior, no new test surface, no new code branches. The artifacts themselves are the audit trail.

### Docs findings

- (none — bookkeeping artifacts only)

### Tests findings

- (none — no source-code changes in range)

### Bypass trailer audit

- (none in range)

## Gate tally

passed: 6
findings_pending: 0
n_a: 10
blocked: 0
