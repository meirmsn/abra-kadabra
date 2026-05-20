# Review — fault-injected-qa-gate

## Audit 1: manual (2026-05-20)

<!-- audited-at: fc8daa961034b75c490583e728f5b5d4cce36a91 -->
<!-- range: origin/main..HEAD -->

findings: high=1 medium=4 low=4

### Docs findings

### [domain: docs] [section: C] [severity: high]
**File**: fc8daa9 commit message body (lines 19-22) vs specs/fault-injected-qa-gate/spec.md:80-90 (D4) vs kit/scripts/preship/fault-injected-qa.sh
**What**: The commit message asserts "`devshop.faultInjectionSkipReason` git-config flag short-circuits the sub-step to pass (v0 honors without adversarial review; follow-up TODOS row tracks wiring the faultInjectionSkipReason check-type into adversarial-review.sh)" — but (a) spec D4 explicitly decides "**No bypass flag**. No `devshop.faultInjectionSkipReason` or equivalent bypass" with a rationale paragraph, and (b) `grep -n faultInjectionSkipReason kit/scripts/preship/fault-injected-qa.sh` returns zero matches. The flag does not exist in the shipped code.
**Why**: The commit message is the durable audit-time artifact for this delta on `main` (devshop ships via squash-merge — the squash body becomes the canonical change log entry). It now describes a feature that wasn't implemented and contradicts the spec's own load-bearing decision. Future readers of `git log` will believe a bypass exists and look for it; reviewers consulting the spec will be told there is no bypass. Either the spec needs to flip D4 (and the script needs the flag wired) OR the commit message needs to be corrected — they cannot both stand. Coherence failure on a Gate 9 contract surface (sub-step outcome semantics).
**Fix**: Pick one — (a) drop the `devshop.faultInjectionSkipReason` paragraph from the commit message before the squash lands (rewrite via `git commit --amend` on the worktree, OR rewrite at squash time inside `/ak-merge-devshop` Phase 2's squash body construction); OR (b) if a bypass is actually wanted, reopen D4, implement the flag in `fault-injected-qa.sh` (mirror the `localTestSkipReason` shape from `kit/scripts/preship/changed-tests-local.sh`), add the matching check-type to `adversarial-review.sh`, and document under `## Outcome mapping` in the SKILL.md sub-step block. (a) is the lower-risk move given the spec rationale is already written and the v0 scope is "make the gate exist".

### [domain: docs] [section: B] [severity: medium]
**File**: specs/fault-injected-qa-gate/spec.md:46-47 (D2 Rationale)
**What**: D2 Rationale claims the harness convention "Mirrors the existing e2e layout (`apps/web/e2e/qa-walk.spec.ts`, `apps/web/e2e/*-qa-walk.spec.ts`)" — but `ls template/apps/web/e2e/` shows only `forgot-password.spec.ts`, `sign-up.spec.ts`, and a `helpers/` dir. There is no `qa-walk.spec.ts` and no `*-qa-walk.spec.ts` glob in the template. The "existing e2e layout" being mirrored doesn't exist.
**Why**: Named-section claim verification (per Section B "stale paths or dangling section references → finding"). A reader looking for the prior-art harness to copy can't find it. The justification for D2's directory choice (`apps/web/e2e/fault-injected/<slug>.spec.ts`) loses its grounding — D2 might still be the right call, but the rationale text misleads.
**Fix**: Replace the parenthetical with an accurate one. Options: (a) "Mirrors the existing e2e layout (`apps/web/e2e/*.spec.ts` flat per-feature, e.g. `sign-up.spec.ts`, `forgot-password.spec.ts`)" — accurate to template state; (b) drop the parenthetical and lean on "Single, predictable lookup path" alone; (c) if the intent was to mirror lalista's qa-walk layout specifically, cite that explicitly with the project-relative path. Low-risk text-only edit; can land in the same squash as a spec amendment.

### [domain: docs] [section: B] [severity: medium]
**File**: kit/docs/guide/latency-feedback.md (no edit) + specs/fault-injected-qa-gate/spec.md:46 + .claude/skills/devshop/pre-ship/SKILL.md:884-887 (Detection block)
**What**: The new `fault-injected-qa.sh detect-surfaces` primary path greps the spec for `## Surface mapping` or `### Surface mapping` headings (see `parse_spec_surface_mapping` regex `/^#{2,3} Surface mapping[[:space:]]*$/`). The SKILL.md amendment cites "spec's `## Surface mapping` table (per `latency-feedback.md § Applying the framework`)" — but `latency-feedback.md § Applying the framework to your project` (lines 373-393) tells project authors the table lives "as part of your spec's `## Decisions` block" with NO specified heading. There is no documented convention telling project authors that the script requires a `## Surface mapping` or `### Surface mapping` heading. Result: a convention-following project that puts the table inline under `## Decisions` without a sub-heading silently falls through to the grep fallback even when the spec is "convention-compliant".
**Why**: Adequacy gap on the new detection contract. The SKILL.md sub-step block names the primary path as "the spec is convention-compliant" but the convention itself doesn't mandate the heading the script needs. First time a project author wonders "why isn't my surface mapping table being picked up?" they get to debug `parse_spec_surface_mapping` to discover the heading requirement. Surface-trigger match (Section B): the script expects a header that no doc tells authors to write.
**Fix**: Add a one-line addendum to `kit/docs/guide/latency-feedback.md § Applying the framework to your project` (after the table example, before "A worked example…"): "Place the table under a `## Surface mapping` heading (or `### Surface mapping` nested in `## Decisions`) so `/ak-pre-ship` Gate 9's fault-injected sub-step can detect the rows." OR amend the SKILL.md detection block to spell out the heading requirement explicitly in the primary-path bullet. Either is sufficient; the latency-feedback.md edit is the more durable home (convention lives there).

### [domain: docs] [section: B] [severity: low]
**File**: .claude/skills/devshop/pre-ship/SKILL.md:887 (Fault-injection sub-step Detection bullet 1)
**What**: SKILL.md amendment cites "per `latency-feedback.md § Applying the framework`" — but the actual heading in `kit/docs/guide/latency-feedback.md:373` is "## Applying the framework to your project". The "to your project" suffix is missing.
**Why**: Named-section claim verification (Section B). The mismatch is small (the reader can navigate from the truncated form) but Section B requires named references to match. Low priority — the section is still findable via the truncated name.
**Fix**: Append " to your project" to the citation: "(per `latency-feedback.md § Applying the framework to your project`)". One-character-grain edit.

No Docs-Coverage-Bypass trailers in range.

### Tests findings

### [domain: tests] [section: A] [severity: medium]

**File**: `kit/tests/preship-fault-injected-qa.bats:200-218`
**What**: `cmd_run`'s Playwright invocation paths — the `pass` outcome (surface detected + harness present + Playwright succeeds) and the `findings (N) — failed: <slug-list>` outcome (Playwright fails) are not exercised by any bats test. Only the scope-exempt `pass (no Tier A2 surfaces in scope)` and `blocked (missing fault-injected harness: ...)` paths are covered.
**Why**: The script's header explicitly documents `PLAYWRIGHT_BIN   override pnpm exec playwright (bats sets a stub).` — i.e., the env-var hook exists specifically to let bats stub Playwright. But no test uses it, so the orchestration code in `cmd_run` (per-surface loop, `mkdir -p` of `gates_dir`, JSON-output redirection to `specs/<feature>/gates/fault-injected-<slug>.json`, exit-code aggregation into `fail_count` / `fail_detail`, final outcome line emission) ships untested. A regression in slug iteration, the `IFS=', '` join (which produces `, `-separated output, not `,`-separated as the docs imply), or the JSON output path is silent until first project use. Spec § Tests defers these paths as "would require headed Chromium" — but stubbing `PLAYWRIGHT_BIN=/bin/true` (pass path) or `PLAYWRIGHT_BIN=/bin/false` (fail path) needs no Chromium at all. The spec's stated rationale doesn't match what the script's own env-var hook enables.
**Fix**: Add two bats tests using `PLAYWRIGHT_BIN`:
```bash
@test "run: emits pass when Playwright stub succeeds for every surface" {
  write_spec_with_table "| AddItem | A2 | hook |"
  touch "$WORK/apps/web/e2e/fault-injected/add-item.spec.ts"
  PLAYWRIGHT_BIN=/bin/true run bash "$SCRIPT" run --feature foo --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  # Last line is the outcome; should be exactly "pass" (not scope-exempt).
  [[ "${lines[-1]}" == "pass" ]]
  # Per-surface JSON written under specs/foo/gates/.
  [ -f "$WORK/specs/foo/gates/fault-injected-add-item.json" ]
}

@test "run: emits findings when Playwright stub fails for a surface" {
  write_spec_with_table "| AddItem | A2 | hook |" "| EditRow | A2 | hook |"
  touch "$WORK/apps/web/e2e/fault-injected/add-item.spec.ts" \
        "$WORK/apps/web/e2e/fault-injected/edit-row.spec.ts"
  PLAYWRIGHT_BIN=/bin/false run bash "$SCRIPT" run --feature foo --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  assert_output --partial "findings (2)"
  assert_output --partial "add-item"
  assert_output --partial "edit-row"
}
```
Either land the stub-based coverage or rewrite the spec § Tests note to match what's actually true (the stub hook is unused; coverage genuinely deferred to first live project run).

### [domain: tests] [section: B] [severity: medium]

**File**: `kit/tests/preship-fault-injected-qa.bats:87-93`
**What**: The `detect-surfaces: emits empty route when no annotation present` test uses a disjunctive shape assertion: `[[ "$output" == *$'\t' ]] || [[ "$output" == *$'\thook\t' ]]`. The test passes if EITHER pattern matches — so the test cannot fail in the way the assertion suggests, and doesn't pin down the actual output format.
**Why**: A regression that swaps trailing-tab vs `\thook\t` formatting would pass the test silently. The whole point of this test is to verify the route-hint column is empty when no `[route:...]` annotation is present — but the assertion lets either format slide. If parsing changes to drop the notes column entirely or add stray whitespace, this test will not catch it.
**Fix**: Pin the exact expected output. The parser emits `<slug>\t<notes>\t<route>`; with `notes="hook"` and no route annotation, the line should be exactly `save\thook\t`:
```bash
[[ "$output" == $'save\thook\t' ]]
```
Or use `assert_equal "$output" $'save\thook\t'` for a clearer diff on failure.

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/preship-fault-injected-qa.bats:175-181`
**What**: `verify-harness: exits non-zero with missing slugs on stderr` asserts on `"$output"`, which in bats by default merges stdout+stderr — the test does not actually verify the missing-slug list went to **stderr** as the script header's contract requires (`Exit non-zero with comma-separated missing slugs on stderr otherwise`).
**Why**: A regression that prints the missing list to stdout instead of stderr would still pass this test. Downstream callers (like `cmd_run` parsing `2>&1` capture) depend on the stderr placement; a silent stdout/stderr swap is invisible to this test.
**Fix**: Use bats' `--separate-stderr` mode or redirect explicitly:
```bash
@test "verify-harness: exits non-zero with missing slugs on stderr" {
  touch "$WORK/apps/web/e2e/fault-injected/a.spec.ts"
  run --separate-stderr bash "$SCRIPT" verify-harness --slugs a,b,c --root "$WORK"
  assert_failure
  [[ "$stderr" == *"b,c"* ]]
  [ -z "$output" ]   # nothing on stdout
}
```

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/preship-fault-injected-qa.bats` (no test for `--diff-range`)
**What**: The `--diff-range` argument to `detect-surfaces` and `run` (which scopes the grep fallback to TS/TSX files in the supplied git range) is not exercised by any test. Its 12-line code branch in `grep_useoptimistic_callsites` (the `if [ -n "$diff_range" ]; then ... git diff --name-only ... fi` block) ships untested.
**Why**: A misquoted glob, a wrong `--diff-filter` flag, or a quoting break that lets the diff-range path swallow non-TS files is invisible until first real-project use. The diff-range path is the production hot-path for `/ak-build` (where the gate runs per-PR with a known base) — the full-tree scan is only the offline-debug fallback.
**Fix**: Add a test that initializes a real git repo inside `$WORK` (already done in `setup()`), commits a baseline, then adds a new `useOptimisticMutation({ failureMode: 'banner' })` call site, and verifies `detect-surfaces --diff-range HEAD~1..HEAD` picks up only the new file (not pre-existing call sites in the baseline).

### [domain: tests] [section: C] [severity: low]

**File**: n/a
**What**: No `Tests-Coverage-Bypass:` trailers in the commit range.
**Why**: Section C harvest is empty — the bypass mechanic isn't active for this PR. No action needed; logged for completeness.
**Fix**: n/a

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-20)

<!-- audited-at: 59f8f90f999bfd5a3cd77fc1013100506ea0ec72 -->
<!-- range: fc8daa961034b75c490583e728f5b5d4cce36a91..HEAD -->

findings: high=0 medium=1 low=0

### Docs findings

### [domain: docs] [section: C] [severity: medium]
**File**: specs/fault-injected-qa-gate/spec.md:184-188 (## Tests rationale) vs kit/tests/preship-fault-injected-qa.bats:224-247 (new PLAYWRIGHT_BIN-stub tests added in 59f8f90)
**What**: spec § Tests still asserts "The `pass` and `findings` paths require a real Playwright run and are not covered by bats (would require headed Chromium in the bats env). They're exercised live the first time a project ships a fault injection spec; the integration is shape-verified manually before that first ship." — but 59f8f90 added exactly that coverage: `run: emits pass when Playwright stub succeeds for every surface` (uses `PLAYWRIGHT_BIN=/bin/true`) and `run: emits findings (N) when Playwright stub fails per-surface` (uses `PLAYWRIGHT_BIN=/bin/false`). The headed-Chromium claim is the same rationale Audit-1's tests-medium-A finding flagged as wrong; the fix landed the stub tests but didn't update the spec text that argued against them.
**Why**: Cross-doc coherence (Section C). The spec is the canonical artifact for "what tests this gate has" — a future reader (or `/ak-spec` consultation in a follow-on iteration) will believe the `pass`/`findings` paths are uncovered, may "fix" the gap by adding redundant coverage, and will not learn the `PLAYWRIGHT_BIN` stub hook as the canonical pattern. The 59f8f90 commit message itself acknowledges this (`spec rationale claimed "needs headed Chromium" which the stub disproves`) — so the contradiction is known but unresolved in the durable artifact. Same shape as Audit-1's high-severity coherence finding (commit-message-vs-spec-vs-code), one tier down because the spec is internal not user-facing.
**Fix**: Rewrite spec.md:184-188 to match shipped state. Suggested replacement: "The `pass` and `findings` paths are covered via the `PLAYWRIGHT_BIN` env-var stub (`/bin/true` for the pass path, `/bin/false` for the findings path) — no headed Chromium needed. Per-surface JSON output + outcome aggregation are exercised end-to-end. A full Playwright run with real `useOptimisticMutation` surfaces is still deferred to first live project use." One-paragraph swap; low-risk text-only edit; can land in the same squash as the rest of the Audit-1 fixes if recomposed, or as a small follow-up commit on the worktree before squash.

No Docs-Coverage-Bypass trailers in range.

### Tests findings

- (none)

### Bypass trailer audit

- (none)
