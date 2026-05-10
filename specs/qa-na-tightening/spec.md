<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: qa-na-tightening -->
<!-- date: 2026-05-10 -->

# Spec: qa-na-tightening (PR N)

**Sources:**

- `PLAN.md` row #1 (`qa-na-tightening`) — primary scope (will be reframed during this PR; see Decisions § D0)
- `kit/ROADMAP.md § Tightening /qa's n/a criteria` (lines 1965-1985) — original problem statement, ACCEPT/REJECT vocabulary, mechanism (`adversarial-review.sh`)
- `.claude/skills/devshop/pre-ship/SKILL.md § Gate 9` (lines 591-692) — Gate 9 outcome contract; the Core user story N/A carve-out at lines 678-682
- `kit/scripts/preship/verify-story.sh` (lines 44-58, 125-129) — where N/A body parsing + skip-assertion live; D2's call site
- `kit/scripts/adversarial-review.sh` (lines 90-330, 332-372) — case-statement + per-check-type prompt + convention-inlining map; surface for the new check-type
- `kit/tests/util-adversarial-review-localTestSkipReason.bats` — pattern reference for the new BATS suite
- `kit/docs/guide/hooks.md § Bypass mechanism table` (lines 128, 232) — doc landing for the new check-type
- `kit/docs/guide/workflow.md § Core user story requirement` (lines 181-191) — convention-inlining target for D4
- Prior spec `specs/post-pr-c-deferred-polish/spec.md` — style + structure reference (most recent devshop-self spec)

Tighten the residual self-attestation rung in Gate 9: when a spec declares `## Core user story: N/A — <reason>`, route the rationale through `adversarial-review.sh` so an interpretive vibe ("no visible UI change", "cosmetic only") fails and a verifiable file/path claim ("no `.tsx` files modified", "diff is `supabase/migrations/**` only") passes — closing the gap that currently lets `verify-story.sh` skip artifact assertion on operator prose alone.

---

## Decisions (resolved at spec time)

Six `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded
below so Phase 1 preserves them verbatim and a crashed Phase 1 resumes
without re-asking. D0 captures the scope-reframe step (the original PLAN
row presupposed a Gate 9 `n/a` outcome that no longer exists post-`408b007`).

### D0: Scope reframe — "Gate 9 `n/a` outcome" → "Core user story: N/A rationale"

**Decision:** Target the `## Core user story: N/A — <reason>` body in `verify-story.sh`'s N/A branch (lines 125-129), not a Gate 9 `n/a` outcome.

**Rationale:** `pre-ship/SKILL.md § Gate 9 § Outcome contract` (line 602) was tightened to three outcomes (`pass | findings | blocked`) — `n/a` is no longer an officially supported Gate 9 outcome. The residual self-attestation rung migrated into `verify-story.sh`'s "Core user story is N/A — artifact assertion skipped" path (line 127), where the operator-supplied `<reason>` text bypasses Gate 9's evidence requirement with no adversarial review. The plan's principle (require a verifiable file:line claim, not interpretive prose) and mechanism (reuse `adversarial-review.sh`) carry over directly to this surface.

### D1: New check-type vs. extend `dismissalLog`

**Decision:** New check-type `coreUserStoryNaReason` in `adversarial-review.sh`.

**Rationale:** `dismissalLog` fires on a gate's `## Dismissals` body (per-finding rationale within a gate's report). The Core-user-story N/A reason lives in the spec, not in a gate's dismissal log — different surface deserves a dedicated check-type. Mirrors `localTestSkipReason` precedent (named for the bypass surface, not the gate it gates). Easier to test in isolation and gives the BATS suite a clean per-check-type case.

### D2: Where the call fires

**Decision:** Inside `verify-story.sh`'s N/A-body branch at lines 125-129, immediately before `return 0`.

**Rationale:** `is_na_core_story` already detects the surface (line 126). The rationale text is the body after `N/A — `. On reject → exit non-zero with the reviewer verdict appended → Gate 9 reports `blocked` with the rejection as fix recipe. Single chokepoint; matches the existing "exit 1 with summary" pattern in `verify_all` (line 168).

### D3: ACCEPT/REJECT vocabulary in the prompt

**Decision:** Copy verbatim from `kit/ROADMAP.md § Tightening /qa's n/a criteria` lines 1973-1974 — ACCEPT positive file/path-based claims (`no .tsx files modified`, `diff is supabase/migrations/** only`, `apps/web/components/** untouched`); REJECT interpretive prose (`no visible UI change`, `nothing user-facing changed`, `cosmetic only`).

**Rationale:** The vocabulary is already authored at the source; copying preserves intent and avoids paraphrase drift. The prompt's worked examples land directly in the check-type's documentation block, matching `localTestSkipReason`'s shape.

### D4: Convention-inlining target

**Decision:** Inline `kit/docs/guide/workflow.md § Core user story requirement` (lines 181-191) into the reviewer's context block.

**Rationale:** Per the `(check_type, gate_name)` routing map at `adversarial-review.sh:332-372`, the reviewer needs the contract for what `Core user story: N/A` means and when it's appropriate. `workflow.md:181-191` is the single load-bearing definition — covers the literal `N/A — <reason>` form, which PRs are migration-only / non-user-facing, and points to the Gate 9 enforcement contract.

### D5: Model routing (Haiku 4.5 vs. Sonnet 4.6)

**Decision:** Sonnet 4.6.

**Rationale:** Mirrors existing `dismissalLog` and `localTestSkipReason` routing (`adversarial-review.sh:52`). Interpretive judgment of operator prose ("does this rationale name a verifiable file claim, or is it a vibe?") is Sonnet-tier, not deterministic-rule application. Haiku is reserved for purely textual checks (e.g., manifest-reviewed) where the rule maps 1:1 to surface signals.

### D6: Backwards compatibility for already-shipped specs

**Decision:** None needed.

**Rationale:** The check fires only at pre-ship time on new invocations. Already-merged specs aren't re-exercised. Existing `specs/<feature>/` directories on disk that happen to declare `Core user story: N/A — <interpretive prose>` from before this PR don't trigger the check until a new pre-ship runs over them — and any such fresh pre-ship is by definition for a new commit on a current branch, where the operator can re-author the rationale.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Screens, Data
     model changes, API contracts, Offline behavior, Metrics, Files to
     create/modify, Tests, Dependencies, Task order, Gotchas, Acceptance /
     rollout / rollback. The Decisions section above stays verbatim. -->

## In scope

Concrete deliverables for this PR (devshop kit only):

- **New `coreUserStoryNaReason` check-type in `kit/scripts/adversarial-review.sh`** — a sibling to `localTestSkipReason` / `dismissalLog`. New case branch in the main switch (D1) that gathers the diff path-list as context, a Sonnet model-routing entry (D5), and a convention-inlining map entry that pulls `kit/docs/guide/workflow.md § Core user story requirement` into the reviewer's context block (D4). Adds Rule #11 to the prompt enumerating the ACCEPT / REJECT vocabulary verbatim from `kit/ROADMAP.md § Tightening /qa's n/a criteria` lines 1973-1974 (D3) plus a worked example contrasting "diff is `supabase/migrations/**` only" (verifiable) against "no visible UI change" (interpretive).
- **N/A-branch wiring in `kit/scripts/preship/verify-story.sh`** — replace the unconditional `return 0` at the end of the `is_na_core_story` branch (current lines 125-129) with a call to `adversarial-review.sh coreUserStoryNaReason "<rationale>"`. On accept (exit 0), preserve the existing `Core user story is N/A — artifact assertion skipped for this PR` message + `return 0`. On reject (exit 1), emit the reviewer's `FAIL: <verdict>` line on stdout and `return 1` so Gate 9's caller surfaces `blocked (Core user story N/A rationale rejected: <verdict>)` with the verdict landing in `review.md § Gate 9` as the fix recipe (D2).
- **BATS suite at `kit/tests/util-adversarial-review-coreUserStoryNaReason.bats`** — pure-mock pattern parallel to `util-adversarial-review-localTestSkipReason.bats`. Mocks `claude` to capture stdin + `--model`, asserts case-statement recognition (no "unknown check type"), prompt-header presence, convention-block inlining, Sonnet routing, ACCEPT-vocab → PASS paths, REJECT-vocab → FAIL paths, and survival in the unknown-check-type fallback enumeration.
- **Doc updates** — single new row in `kit/docs/guide/hooks.md`'s adversarial-reviewed bypass list (line 232 area) for `coreUserStoryNaReason`; one-line addendum under `## Gate 9 § Core user story artifact assertion § When the spec's Core user story is N/A` (`.claude/skills/devshop/pre-ship/SKILL.md` line 678-682) noting the rationale is now adversarially reviewed and pointing at the new check-type.

## Out of scope

- **Rewrite of `dismissalLog`** — the existing per-finding rationale judge is unrelated; this PR adds a sibling check-type at a different surface (the spec's Core user story body, not a gate's `## Dismissals` section). Touching `dismissalLog` is a separate concern with its own scope.
- **Generalization to other gates' `n/a` rungs** — Gate 9's outcome contract was already tightened to `pass | findings | blocked` (no `n/a` outcome remains). This PR closes the residual self-attestation rung that migrated into `verify-story.sh`. Other gates do not currently have an analogous "operator prose bypasses evidence" path; if one emerges, it gets its own check-type, not a generalized one.
- **Backwards compatibility for already-shipped specs** (D6) — no migration; the new check fires only at pre-ship time on new invocations.
- **Lalista-side adoption** — this is a devshop kit PR. Lalista picks up the tightening on its next devshop pull when the operator next pre-ships a spec whose Core user story is `N/A`. No explicit follow-up PR needed.
- **Workflow-doc edits** — `kit/docs/guide/workflow.md § Core user story requirement` (lines 181-191) is the body inlined into the reviewer's context. Editing that body is a separate concern (and would require updating this PR's BATS fixtures in lockstep — see Gotchas).
- **METRICS event for accept/reject ratio** — devshop kit; no METRICS.md instrumentation. The `claude -p` invocation already emits to the devshop adversarial-review telemetry budget alongside other Sonnet check-types.
- **Bypass-flag surface** — unlike `dirtyTreeReason` / `localTestSkipReason`, this check-type is invoked at pre-ship time from `verify-story.sh`, not at commit-time via `git -c devshop.<key>="..."`. There is no new git-config flag; the rationale lives in the spec file itself, where it's already required by `/ak-spec`'s Core-user-story step.

## Files to create / modify

| Path                                                           | Change | Why                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| -------------------------------------------------------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kit/scripts/adversarial-review.sh`                            | modify | (1) Add `coreUserStoryNaReason)` case in the main `case "$CHECK_TYPE" in` switch (after `localTestSkipReason)`, before `prDescStaleReason)`) that gathers the diff path-list as context (`git diff --name-only --diff-filter=AM origin/main...HEAD` with HEAD~1 fallback, mirroring `localTestSkipReason`'s shape). (2) Add `coreUserStoryNaReason` to the Sonnet branch in `get_model_for_check_type()` (D5). (3) Add `coreUserStoryNaReason` case in `get_conventions_to_inline()` returning a sentinel handled by a new branch in the inlining loop that pulls `kit/docs/guide/workflow.md § Core user story requirement` (D4 — `workflow.md`, not `conventions.md`; see Gotchas). (4) Add Rule #11 to the in-prompt rule-list with the ACCEPT / REJECT vocabulary + worked examples. (5) Update the docstring header (lines 17-29) and the unknown-check-type fallback message (line 324) to enumerate `coreUserStoryNaReason`. (6) Update the model-routing comment (line 51-52) to list `coreUserStoryNaReason` under Sonnet. |
| `kit/scripts/preship/verify-story.sh`                          | modify | Replace the `is_na_core_story` branch's unconditional `echo … skipped` + `return 0` (lines 126-129 of current file) with: extract the rationale text from the body (everything after the literal `N/A — ` or `N/A: ` or `N/A -` marker, falling back to the trimmed first non-empty line if no marker), invoke `bash "$(dirname "$0")/../adversarial-review.sh" coreUserStoryNaReason "<rationale>"`, and branch on its exit code. Accept → existing "skipped" message + `return 0`. Reject → echo `blocked: Core user story N/A rationale rejected by adversarial review` followed by the reviewer's `FAIL:` line on stdout, `return 1`. The verdict-on-stdout shape is what makes the rejection text propagate cleanly into `review.md § Gate 9` as the fix recipe (Gotchas).                                                                                                                                                                                                                                                     |
| `kit/tests/util-adversarial-review-coreUserStoryNaReason.bats` | create | New BATS file mirroring `util-adversarial-review-localTestSkipReason.bats`'s shape (mock `claude`, capture prompt + `--model`, exercise PASS / FAIL paths). Test cases enumerated in § Tests below.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `kit/docs/guide/hooks.md`                                      | modify | Add one row to the adversarial-reviewed bypass-flag enumeration around line 232: `coreUserStoryNaReason` — but framed differently (it's not a `git -c devshop.<key>` flag at commit-time; it judges the rationale text in `## Core user story: N/A — <reason>` at pre-ship time). The row sits in a small note paragraph adjacent to the existing flag list rather than in the table; see the Gotchas note about flag-vs-pre-ship-rationale framing.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `.claude/skills/devshop/pre-ship/SKILL.md`                     | modify | One-line addendum under `## Gate 9 § Core user story artifact assertion § When the spec's Core user story is N/A` (lines 678-682 region): "The N/A rationale is adversarially reviewed (`coreUserStoryNaReason`) — interpretive prose ('no visible UI change', 'cosmetic only') fails; verifiable file/path claims ('diff is `supabase/migrations/**` only', 'no `.tsx` files modified') pass."                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |

## Tests

New BATS suite at `kit/tests/util-adversarial-review-coreUserStoryNaReason.bats`. Mirrors `util-adversarial-review-localTestSkipReason.bats`'s setup pattern (mock `claude`, capture prompt + `--model` to tmpdir; `MOCK_CLAUDE_VERDICT` env var controls verdict). No unit / integration / E2E impact — adversarial-review is bash + a `claude -p` subshell.

**Wiring assertions (the new check-type is hooked correctly):**

1. `coreUserStoryNaReason: case statement recognized (no 'unknown check type')` — invoke with a benign rationale; assert `refute_output --partial "unknown check type"`.
2. `coreUserStoryNaReason: prompt header includes 'Check type: coreUserStoryNaReason'` — capture prompt; grep the literal header.
3. `coreUserStoryNaReason: convention block inlines workflow.md § Core user story requirement` — capture prompt; grep for a load-bearing phrase from `workflow.md` lines 181-191 (e.g., `"Every spec produced by /ak-spec MUST include a ## Core user story section"` or `"N/A — <reason> for non-user-facing PRs"`). Asserts the new convention-inlining branch resolves to `workflow.md`, not `conventions.md`.
4. `coreUserStoryNaReason: prompt context includes the diff-paths section` — same shape as the `localTestSkipReason` "Diff paths" assertion. Confirms the case branch surfaces `DIFF_PATHS` for the reviewer.
5. `coreUserStoryNaReason: routes to Sonnet (interpretive judgment)` — capture `--model`; grep `sonnet`.
6. `coreUserStoryNaReason: enumerated in unknown-check-type fallback message` — invoke `adversarial-review.sh madeUpCheck "x"`; assert failure + `assert_output --partial "coreUserStoryNaReason"`. Confirms the docstring-comment / fallback enumeration was updated in lockstep.

**ACCEPT vocabulary (verbatim phrases from `kit/ROADMAP.md` lines 1973-1974) → PASS:**

7. `accept: 'no .tsx files modified' → PASS when reviewer accepts` — `MOCK_CLAUDE_VERDICT="PASS"`, rationale = `no .tsx files modified`. `assert_success`.
8. `accept: 'diff is supabase/migrations/** only' → PASS when reviewer accepts` — same shape, rationale = `diff is supabase/migrations/** only`. `assert_success`.
9. `accept: 'apps/web/components/** untouched' → PASS when reviewer accepts` — same shape, rationale = `apps/web/components/** untouched`. `assert_success`.
10. `accept: spec's own dogfooded ACCEPT example → PASS` — rationale = the literal body this spec uses for its own Core user story (the dogfooding example: `N/A — devshop pipeline tightening; touches kit/scripts/adversarial-review.sh, kit/scripts/preship/verify-story.sh, kit/tests/, kit/docs/guide/hooks.md, .claude/skills/devshop/pre-ship/SKILL.md only; no apps/** or packages/** files in diff.`). `MOCK_CLAUDE_VERDICT="PASS"`, `assert_success`. The eat-your-own-dogfood smoke test.

**REJECT vocabulary (verbatim phrases from `kit/ROADMAP.md` lines 1973-1974) → FAIL:**

11. `reject: 'no visible UI change' → FAIL when reviewer rejects` — `MOCK_CLAUDE_VERDICT="FAIL: 'no visible UI change' is interpretive — name a verifiable file/path claim"`, rationale = `no visible UI change`. `assert_failure` + `assert_output --partial "FAIL"`.
12. `reject: 'nothing user-facing changed' → FAIL when reviewer rejects` — same shape, rationale = `nothing user-facing changed`. `assert_failure`.
13. `reject: 'cosmetic only' → FAIL when reviewer rejects` — same shape, rationale = `cosmetic only`. `assert_failure`.

**Diff-path enumeration (parallels the `localTestSkipReason` smoke tests):**

14. `coreUserStoryNaReason: stages a diff path into context when origin/main exists` — set up `origin/main` ref, add a file under `apps/web/components/Foo.tsx`, invoke; capture prompt; grep the path. Confirms the `git diff --name-only origin/main...HEAD` branch fires.
15. `coreUserStoryNaReason: graceful degrade when origin/main is missing (HEAD~1 fallback)` — two-commit repo, no origin/main, file under `apps/web/components/Foo.tsx`; assert path appears in the captured prompt. Confirms the `HEAD~1..HEAD` fallback wires correctly.

**Prompt-rule presence:**

16. `coreUserStoryNaReason: prompt rules include rule #11 with ACCEPT/REJECT examples` — capture prompt; grep `^11\. For coreUserStoryNaReason` and at least one ACCEPT phrase + one REJECT phrase from D3's vocabulary list. Mirrors `localTestSkipReason`'s rule-10 shape assertion.

That's 16 cases. Pattern matches the reference suite (16 tests in `localTestSkipReason`'s BATS file); no new test categories invented.

## Task order

Numbered, dependency-ordered. Execution order is fixed by reverse-dependency: the `adversarial-review.sh` check-type must exist before anything calls it; the BATS suite exercises behavior the script implements; docs describe behavior the gate produces. The `## Task order` header is the discriminator the resume check uses to tell "skeleton" from "complete spec" — kept literal.

1. **Add `coreUserStoryNaReason` check-type to `kit/scripts/adversarial-review.sh`** — case branch + Sonnet routing + convention-inlining (workflow.md branch) + Rule #11 + docstring-header + fallback-message updates. One commit. _Depends on: nothing._
2. **Wire `verify-story.sh`'s N/A branch** — replace the `is_na_core_story` branch's `return 0` with the `adversarial-review.sh coreUserStoryNaReason "<rationale>"` call + accept/reject branching. One commit (gate code). _Depends on: Task 1 (the check-type must exist or `verify-story.sh` calls would fail with `unknown check type`)._
3. **BATS suite** — `kit/tests/util-adversarial-review-coreUserStoryNaReason.bats` with the 16 cases enumerated in § Tests. One commit. _Depends on: Task 1 (test target). Doesn't strictly depend on Task 2 — the BATS suite mocks `claude` and exercises `adversarial-review.sh` directly, not via `verify-story.sh`. But landing in this order keeps the bisect history clean (every commit makes the suite pass green)._
4. **Doc updates** — `kit/docs/guide/hooks.md` (one new row + framing note) + `.claude/skills/devshop/pre-ship/SKILL.md` (one-line addendum under Gate 9's N/A subsection). One commit (both files together — they describe the same shipped behavior; splitting risks mid-PR doc-drift). _Depends on: Tasks 1-3 (concrete shape to describe)._

(Phase 5.6 of `/ak-build` separately removes the matching `kit/ROADMAP.md § Tightening /qa's n/a criteria` entry. That's the standard post-ship ROADMAP cleanup — out of scope for this spec's task list.)

## Gotchas

Non-obvious rules surfaced during Phase 0 spec resolution and at spec-write time. Read before touching the relevant area.

- **The prompt's worked examples must distinguish "diff is `supabase/migrations/**`only" (verifiable by`git diff --name-only`) from "migration only" alone (interpretive).** The reviewer's worked-example block in Rule #11 must include both shapes side-by-side and call out why the first PASSes and the second FAILs: the first names a path glob a future reader can re-verify against `git diff --name-only origin/main...HEAD`(the same diff-path list the case branch already surfaces in CONTEXT); the second is a vibe — "migration" describes the operator's mental model, not a file-system fact. Without this contrast, a Sonnet reviewer can talk itself into accepting "migration only" as PASS-shaped because it sounds specific. The vocabulary in D3 is verbatim from`kit/ROADMAP.md` and intentionally calls out the verifiable-claim shape; the worked example operationalizes it.

- **The inlined `workflow.md § Core user story` body must be kept fresh — same convention as the `localTestSkipReason` inline blocks.** D4's convention-inlining target is `kit/docs/guide/workflow.md` lines 181-191 (NOT `kit/docs/guide/conventions.md` — note this requires a small extension to `get_conventions_to_inline()` since the existing helper assumes `conventions.md`). The body is inlined verbatim into the reviewer's context block; if `workflow.md` is rewritten later (e.g., the Core-user-story requirement is generalized or rephrased), the BATS test in § Tests #3 (which greps a load-bearing phrase from the inlined block) will fail and force the operator to update either the grep-target or the inlining map. Same lockstep-update discipline as the existing `localTestSkipReason` Rule-10 inline-list (the four test categories in `adversarial-review.sh:213-218`). The `extract_convention_section()` helper takes a file path argument already (line 341); the new branch passes `workflow.md` instead of `conventions.md` and reuses the heading-slice logic unchanged.

- **`verify-story.sh` is invoked from Gate 9; the `adversarial-review.sh` call timeout default is 180s.** `adversarial-review.sh:428-434` sets `COMMIT_TIMEOUT=180` and applies it to all check-types except `dismissalLog` (which uses `PRESHIP_TIMEOUT`, default 120s, override-able via `PRESHIP_ADVERSARIAL_TIMEOUT`). `coreUserStoryNaReason` falls into the 180s bucket — fine for our case (single short rationale + diff-paths context, well under any plausible Sonnet response time). If a future change subjects this check to a different timeout setting (e.g., Gate 9 starts running under a parent-imposed timeout), surface the constraint here. The current `/ak-pre-ship` gate flow has no parent timeout that bites; the only failure mode is `claude -p` API-side slowness, which the existing `BACKOFF_DELAYS=(15 60)` retry already handles.

- **On reject, the rejection text becomes the Gate 9 fix recipe — `verify-story.sh` MUST propagate the verdict to stdout so it lands in `review.md § Gate 9`.** `adversarial-review.sh` writes `FAIL: <verdict>` to stdout and exits 1 on reject (lines 569-572). `verify-story.sh`'s reject branch must NOT swallow that output — capture it (e.g., `verdict=$(adversarial-review.sh ... 2>&1)` then `echo "$verdict"`) and emit it on stdout before `return 1`. The Gate 9 caller harvests `verify-story.sh`'s stdout into the review.md report, so a swallowed verdict produces a useless `blocked` outcome with no actionable diagnostic. Mirror the existing per-verb diagnostic shape (`echo "✖ verb $n: ..."` at lines 161-163) — clear marker line, then the verdict body.

- **The N/A-rationale format is operator-flexible (`N/A — <reason>` / `N/A: <reason>` / `N/A - <reason>`); the rationale extractor must handle all three.** `is_na_core_story()` already accepts any of these via the regex `^[Nn]/?[Aa]([[:space:]:—-]|$)` (line 58). The new rationale extractor in `verify-story.sh`'s reject-branch must strip the same set of separators — em dash (`—`), hyphen (`-`), colon (`:`), and surrounding whitespace — then trim. If the body is just `N/A` with no rationale, the rationale text is empty; pass empty string to `adversarial-review.sh` (the reviewer will then judge "no rationale at all" as automatically REJECT under Rule #11's "missing rationale" sub-criterion — same shape as `dismissalLog`'s "missing rationale field entirely" rule).

- **`adversarial-review.sh`'s repo-mode detection (devshop vs project; lines 84-88) treats the test sandbox as devshop-mode when `kit/` exists at the repo root.** The BATS setup creates `$TEST_REPO/kit/docs/guide/conventions.md` exactly to satisfy this probe (see the reference suite's setup at lines 35-37). The new suite must do the same AND additionally create `$TEST_REPO/kit/docs/guide/workflow.md` with the canonical `## Core user story requirement` body — otherwise the convention-inlining loop's `[ -f "$WORKFLOW_FILE" ]` guard will skip the inline silently and § Tests #3 will fail on an empty inline block. Bake the workflow.md fixture into the suite's `setup()` helper.

- **BATS fixture body for `workflow.md § Core user story requirement` is verbatim from the real file.** Copy lines 181-191 of `/devshop/kit/docs/guide/workflow.md` into the test fixture as a heredoc — don't paraphrase. The grep-assertion in § Tests #3 targets a literal phrase ("Every spec produced by `/ak-spec` MUST include a `## Core user story` section" or "N/A — <reason> for non-user-facing PRs"). If the test fixture differs from the real file, the test passes against fixture text but the real shipped behavior never gets validated.

- **`coreUserStoryNaReason` is NOT a commit-time bypass flag.** Unlike every other entry in `hooks.md`'s adversarial-reviewed flag list (`dirtyTreeReason`, `prDescStaleReason`, `localTestSkipReason`, etc.), this check-type is invoked at pre-ship time from `verify-story.sh`, not at commit-time via `git -c devshop.<key>="..."`. There is no `devshop.coreUserStoryNaReason` git-config flag — the rationale lives in the spec body, where `/ak-spec` already requires it. The `hooks.md` doc edit must frame it as "additionally judged at pre-ship time" rather than slotting it into the bypass-flag table where it would imply a commit-time use it doesn't have.

## Acceptance / rollout / rollback

### Acceptance criteria

1. `kit/scripts/adversarial-review.sh` contains the `coreUserStoryNaReason)` case branch, populates `CONTEXT` with diff-paths (matching `localTestSkipReason`'s shape), routes to Sonnet, inlines `workflow.md § Core user story requirement` into the reviewer context, and lists Rule #11 with the verbatim ACCEPT / REJECT vocabulary from D3.
2. `kit/scripts/preship/verify-story.sh`'s `is_na_core_story` branch invokes `adversarial-review.sh coreUserStoryNaReason "<rationale>"` and propagates the verdict on stdout for both accept and reject paths.
3. The 16 BATS cases at `kit/tests/util-adversarial-review-coreUserStoryNaReason.bats` pass under the project's BATS runner. Existing `util-adversarial-review-localTestSkipReason.bats` continues to pass (no regression in the reference suite or in the unknown-check-type fallback enumeration).
4. `kit/docs/guide/hooks.md` and `.claude/skills/devshop/pre-ship/SKILL.md` describe the new behavior in the load-bearing sections (D4 inlining target reference + Gate 9 N/A subsection).
5. Manual exercise: on a fake spec with Core user story body `N/A — no .tsx files modified`, `verify-story.sh verify-all --feature <fake> --spec <path>` returns 0 and emits the existing "skipped" message (with `MOCK_CLAUDE_VERDICT=PASS` mocking the reviewer). On a fake spec with body `N/A — no visible UI change`, the same call returns 1 and emits `FAIL: …` on stdout (with `MOCK_CLAUDE_VERDICT="FAIL: interpretive — name a file/path claim"`). The two manual exercises are the dogfooded version of the BATS suite's most load-bearing assertions.
6. The spec's own `## Core user story` body (`N/A — devshop pipeline tightening; touches kit/scripts/adversarial-review.sh, kit/scripts/preship/verify-story.sh, kit/tests/, kit/docs/guide/hooks.md, .claude/skills/devshop/pre-ship/SKILL.md only; no apps/** or packages/** files in diff.`) PASSes adversarial review when this PR runs `/ak-pre-ship` against itself — the eat-your-own-dogfood acceptance signal. (BATS test case #10 covers this in mock form; the live signal is Gate 9 on this PR's own pre-ship run.)

### Rollout

No separate rollout — lands with normal devshop merge.

- Devshop's `main` PR merges → kit changes are immediately available to any project that pulls them in.
- The new check fires only at pre-ship time on new invocations. Already-merged specs aren't re-exercised; no migration needed.
- Existing projects (lalista) pick up the tightening on their next `/ak-pre-ship` run on a spec whose Core user story is `N/A`. No project-side wiring required — `verify-story.sh` already runs as part of Gate 9 from the kit, not from a project-side copy.
- No GitHub Variables / Secrets / branch-protection / Supabase configuration changes required.
- No new flag, no ramp, no telemetry sentinel — devshop kit, all consumers re-pull on next gstack-style upgrade.

### Rollback

Single layer, narrow blast radius:

- **Revert the four-file PR.** `kit/scripts/adversarial-review.sh` reverts to the pre-PR shape (no `coreUserStoryNaReason` case; the unknown-check-type branch will fail any pre-ship that's already been re-pulled — but those are already calling the new branch in `verify-story.sh`, so the revert must be atomic on both files). `kit/scripts/preship/verify-story.sh` reverts to the unconditional `return 0` on the `is_na_core_story` branch — i.e., the prior "skip on N/A presence alone" behavior. BATS file is deleted. Doc edits revert.
- The atomicity is the load-bearing constraint: don't revert `adversarial-review.sh` without also reverting `verify-story.sh`, or every pre-ship with an N/A spec will fail with `unknown check type: coreUserStoryNaReason`. Standard PR-revert workflow handles this by reverting all four files in one commit.
- No data migration. No persistent state. Worst case during a botched land: a few `/ak-pre-ship` runs surface `unknown check type` in their Gate 9 fix recipe, which is loud and self-diagnosing.

## Core user story

N/A — devshop pipeline tightening; touches kit/scripts/adversarial-review.sh, kit/scripts/preship/verify-story.sh, kit/tests/, kit/docs/guide/hooks.md, .claude/skills/devshop/pre-ship/SKILL.md only; no apps/** or packages/** files in diff.
