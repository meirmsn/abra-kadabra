# Devshop Roadmap

Devshop capabilities to build eventually — how you build, not what you ship.
Tactical fixes go in `TODOS.md`. Project features go in root `PRODUCT-ROADMAP.md`.

Priority tiers:

- **v0** — fixes the current template needs before a second project adopts it. Each exists because the first template-validation project (lalista) surfaced a gap every future project will hit. Factoring up now avoids each project re-inventing the wheel.
- **v1** — devshop capabilities that would be valuable but aren't blocking next-project onboarding.
- **v+** — future, when the need is felt.

---

## v0 — blocks next-project adoption

### Move adversarial Layer 2 reviews from per-commit to audit-time (`/ak-check-docs-and-tests`)

**Problem.** Every devshop commit fires `docsReviewed` (Sonnet, 30–90s, ~$0.05–0.15 of API spend). Every project commit touching source can fire `testCoverageProject` Layer 2 + `docsFreshnessProject` Layer 2. A typical PR cycle has 5–15 commits past `/ak-implement`; collapsing to one Sonnet call per audit moment saves 5–14× the cost and time per ship.

The deeper structural critique: per-commit adversarial review **asks the wrong question at the wrong moment.** While a developer is iterating on code, docs and tests aren't ready yet — they're explicitly batched for an end-of-work pass. The hook fires asking "where are the docs?", the developer correctly answers "I'll write them later," and a Sonnet call judges a not-yet-written artifact. The right shape: per-commit is **deterministic Layer 1 only** (cheap, file-existence math); Sonnet judgment fires at named **audit moments** when docs and tests have actually been written.

A second problem: today `/ak-test-review` (a skill) and `testCoverageProject` (a check-type) judge overlapping concerns from different homes. The skill judges quality (assertion strength, RLS auth boundaries, skip audits); the check-type judges coverage (does the diff have paired tests). Operators have to know which is which. Unifying coverage + quality per domain into one Layer 2 skill (one for docs, one for tests) makes the surface obvious.

**Audit moments (canonical):**

- **First audit** — work is done, before polish/review begins. This is when docs and tests get _written_ for the change. The reviewer judges thoroughness as input to the human reviewer (project) or self-review (devshop).
- **Second audit** — polish is done, immediately before merge. The reviewer audits the diff between the first audit and HEAD; anything that changed must be reflected in updated docs/tests.

Both audits append to a single `specs/<feature>/review.md`. Each audit appends a new `## Audit N` section with its own `<!-- audited-at: <SHA> -->` HTML-comment stamp, range, findings counts, per-finding bullets, and bypass-trailer review. Audit history is visible in one file; idempotence reads the latest audit section's stamp. Replaces the previous two-file model (`review.md` + `test-review-followup.md`).

Audit section shape:

```markdown
## Audit 1: pre-polish (2026-05-06)

<!-- audited-at: a3b9c2f1 -->
<!-- range: origin/main..a3b9c2f1 -->

findings: high=0 medium=2 low=3

### Docs findings

- [med] apps/web/.../<file>:<line> — <one-line summary>

### Tests findings

- [med] apps/web/e2e/<file>:<line> — <one-line summary>

### Bypass trailer audit

- <commit SHA> Docs-Coverage-Bypass: "<reason>" — VERIFIED
- <commit SHA> Tests-Coverage-Bypass: "<reason>" — DEFER (revisit at next audit)

## Audit 2: post-polish (2026-05-08)

<!-- audited-at: f4e8d129 -->
<!-- range: a3b9c2f1..f4e8d129 -->

findings: high=0 medium=1 low=0
[...]
```

The HTML-comment markers (`<!-- audited-at: ... -->`) render invisibly in any Markdown view but provide an unambiguous, greppable parser contract. Phase 5.8 already uses this pattern on `test-review-followup.md`; this RFC extends it.

**Trigger map (per repo / per surface):**

| Repo                        | First audit                                                        | Second audit                                                     |
| --------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------- |
| Project, inside `/ak-build` | Phase 3 (`/ak-pre-ship` Gate 5 invokes `/ak-check-docs-and-tests`) | Phase 5.8 (re-runs `/ak-check-docs-and-tests` over polish range) |
| Project, manual flow        | Operator invokes `/ak-check-docs-and-tests` when work is done      | Operator invokes `/ak-check-docs-and-tests` again before merge   |
| Devshop                     | Operator invokes `/ak-check-docs-and-tests` before ff-merge        | Re-invokes if iterating; idempotent                              |

Devshop has no PR review surface, so its "polish round" is informal local iteration. Re-running `/ak-check-docs-and-tests` before each merge attempt covers it; idempotent on unchanged HEAD.

#### End-state architecture

```
                  ┌───────────────────────────────┬───────────────────────────────┐
                  │  PER-COMMIT (bash hooks)      │  AUDIT-TIME (agent skills)    │
                  │  Caller: kit/hooks/pre-       │  Caller: /ak-check-docs-      │
                  │    commit.sh + .husky/*       │    and-tests (skill)          │
                  ├───────────────────────────────┼───────────────────────────────┤
                  │                               │                               │
  LAYER 1         │  4 bash scripts in 2×2 grid:  │  ✗ N/A                        │
  (deterministic, │                               │                               │
   file-existence │  ┌──────────┬──────────────┐  │  Layer 1 is per-commit only.  │
   math)          │  │ tests    │ docs         │  │                               │
                  │  │          │              │  │                               │
                  │  │ -project │ -project     │  │                               │
                  │  │ -devshop │ -devshop     │  │                               │
                  │  └──────────┴──────────────┘  │                               │
                  │                               │                               │
                  │  Block on FAIL. Bypass via    │                               │
                  │  `git -c <flag>=<reason>`     │                               │
                  │  → emits commit trailer via   │                               │
                  │  prepare-commit-msg hook.     │                               │
                  │                               │                               │
                  ├───────────────────────────────┼───────────────────────────────┤
                  │                               │                               │
  LAYER 2         │  ✗ REMOVED                    │  Two domain skills:           │
  (LLM judgment   │                               │                               │
   over a range)  │  This is the entire point     │  /ak-docs-review              │
                  │  of the migration. Per-commit │   coverage + quality of docs  │
                  │  was the wrong moment for     │                               │
                  │  Layer 2.                     │  /ak-tests-review             │
                  │                               │   coverage + quality of tests │
                  │                               │                               │
                  │                               │  Both repo-aware, both read   │
                  │                               │  bypass trailers from range,  │
                  │                               │  both emit structured findings│
                  │                               │                               │
                  └───────────────────────────────┴───────────────────────────────┘

  ORCHESTRATOR (audit-time, skill):
    /ak-check-docs-and-tests
      ├─ compute commit range from review.md
      ├─ /ak-docs-review
      ├─ /ak-tests-review
      └─ append `## Audit N` to specs/<feature>/review.md

  BYPASS-REASON ENGINE (per-commit, narrowed):
    kit/scripts/adversarial-review.sh
      Surface narrows to bypass-reason check-types only:
        prDescStaleReason, dirtyTreeReason, manifestReviewed,
        hookBypass, exemptAddition, testReviewSkipReason, dismissalLog
      All artifact-adequacy check-types removed in PR-C.
```

Why this shape:

- **Layer 1 = "check," Layer 2 = "review."** Different verbs in the names, different roles. Layer 1 is deterministic file-presence math; Layer 2 is rubric-driven LLM judgment.
- **Symmetric across domains.** Both docs and tests get one Layer 1 script per repo and one Layer 2 review skill. No leftover asymmetry.
- **Symmetric across repos.** Both `/devshop` and `/workspace` get the full 2×2 Layer 1 grid. Today devshop is missing a docs Layer 1 (Sonnet `docsReviewed` fires unconditionally per-commit instead) — that gap closes here.
- **Skills own their prompts.** Each Layer 2 skill's SKILL.md is the source of truth for what it judges. No central CHECK_TYPE switch with a 100-line per-type case branch.
- **adversarial-review.sh shrinks to its actual job.** After PR-C it carries only bypass-reason judgment — fired by bash hooks, exit-0/exit-1 contract, narrow surface. Its complexity matches its role.
- **Bypass at commit time stays cheap, expensive to fake.** Operators waving past Layer 1 don't pay an LLM call. But they DO pay later: audit harvests their bypass trailers from the commit range and adversarially re-judges every one with full diff context.

#### Component design

##### A. Layer 1 scripts (per-commit, bash, file-existence math)

Four scripts in `kit/scripts/commit-hooks/`:

|             | tests                             | docs                             |
| ----------- | --------------------------------- | -------------------------------- |
| **project** | `check-tests-coverage-project.sh` | `check-docs-coverage-project.sh` |
| **devshop** | `check-tests-coverage-devshop.sh` | `check-docs-coverage-devshop.sh` |

**Renames** (PR-C, atomic with the new-script add; use `git mv` to preserve history):

- `check-test-coverage-project.sh` → `check-tests-coverage-project.sh` (pluralize for symmetry with docs)
- `check-test-coverage.sh` → `check-tests-coverage-devshop.sh` (add explicit `-devshop` suffix; was implicit)
- `check-docs-freshness-project.sh` → `check-docs-coverage-project.sh` (drop "freshness," use universal "coverage" for file-pairing)

**New script** (PR-C):

- `check-docs-coverage-devshop.sh` — implements the surface→doc mapping below. Surfaces and required staged docs:

| Surface path touched                                 | Required staged doc (at least one)                               |
| ---------------------------------------------------- | ---------------------------------------------------------------- |
| `kit/scripts/**.sh`                                  | any `kit/docs/guide/*.md` OR `CLAUDE.md`                         |
| `kit/scripts/commit-hooks/**`                        | `kit/docs/guide/hooks.md`                                        |
| `kit/scripts/preship/**`                             | `.claude/skills/devshop/pre-ship/SKILL.md` OR `kit/docs/guide/*` |
| `kit/hooks/**`                                       | `kit/docs/guide/hooks.md` OR `CLAUDE.md`                         |
| `.claude/skills/**/SKILL.md`                         | `kit/docs/guide/workflow.md` OR `CLAUDE.md`                      |
| `template/**` (excl. `template/.devcontainer/.env*`) | `kit/docs/guide/{architecture,security,ops}.md`                  |
| `.devcontainer/**` (excl. `.env`)                    | `kit/docs/guide/{security,ops}.md`                               |
| `kit/manifest.txt`                                   | `kit/docs/guide/architecture.md`                                 |

Carve-outs (no firing): `kit/notes/**`, `kit/ROADMAP.md`, `kit/TODOS.md`, `kit/docs/CHANGELOG.md`, `kit/version`, `kit/tests/**`, `kit/docs/**` itself (audit handles guide-only commits).

**Common contract for all four scripts:**

- Exit 0 = pass / not applicable.
- Exit 1 = block (missing required pairing).
- Bypass: `git -c devshop.<flag-name>=<reason>` — accepts the commit without LLM judgment, **but** the commit gets a trailer (see § B).
- No LLM calls. No claude CLI invocation. Pure file-presence math.

**Bypass flag names** (one per domain, repo detected via `$GIT_ROOT`):

| Domain         | Flag                          |
| -------------- | ----------------------------- |
| tests-coverage | `devshop.testsCoverageReason` |
| docs-coverage  | `devshop.docsCoverageReason`  |

Tuning items surfaced during the lalista PR #43 work (no script change needed; documented as known limits):

- Component prop additions (`AwaitingConfirmationCard` + `onEdit`) don't fire Layer 1 — too costly to detect deterministically. Audit-time concern.
- `posthog.capture(...)` / `Sentry.captureException(...)` triggers fire correctly.
- New `apps/*/app/**/page.tsx` / `route.ts` triggers fire correctly.

##### B. Bypass trailers (per-commit emission via `prepare-commit-msg`, audit-time consumption)

When a Layer 1 script accepts a bypass via `git -c devshop.<flag>=<reason>`, a `prepare-commit-msg` hook appends a Git trailer to the commit message **before the commit lands**. Trailers travel with the commit (survive rebases, push to origin, visible in `git log --format=%B`).

**Mechanism**:

1. **`pre-commit` (existing hook)**: Layer 1 scripts read `git config devshop.<flag>` and decide pass/block. No side-files. No commit-message manipulation.
2. **`prepare-commit-msg` (new hook in `template/.husky/prepare-commit-msg`)**: runs after pre-commit, before the commit message is finalized, with the commit-message file path as `$1`. Reads the same `git config` flags that pre-commit read (same `git commit -c <flag>=<reason>` invocation, same config visible). For each flag with a non-empty value, appends the corresponding trailer via `git interpret-trailers --in-place --trailer "<Key>: <reason>" "$1"`.

The implementation is a single ~20-line script (`kit/scripts/commit-hooks/append-bypass-trailers.sh`) called from `template/.husky/prepare-commit-msg`. No state carried across hook boundaries — both hooks independently read the same per-invocation config.

**Trailer keys**:

| Layer 1 script                              | Trailer key              |
| ------------------------------------------- | ------------------------ |
| `check-tests-coverage-{project,devshop}.sh` | `Tests-Coverage-Bypass:` |
| `check-docs-coverage-{project,devshop}.sh`  | `Docs-Coverage-Bypass:`  |

**Example commit message after bypass**:

```
fix(auth): wire onEdit prop into AwaitingConfirmationCard

Adds the prop and its handler. CLAUDE.md update batched with
parent feature work; will be addressed at end-of-feature audit.

Docs-Coverage-Bypass: deferring CLAUDE.md§Where Things Happen update to end of feature
```

**Audit-time consumption**:

`/ak-docs-review` and `/ak-tests-review` each run:

```bash
git log --format='%H%n%B%n---' <range> | \
  awk '/^Docs-Coverage-Bypass:/{print prev_sha, $0}/^[a-f0-9]{40}$/{prev_sha=$0}'
```

Each harvested bypass becomes an explicit `[bypass-revisit]` finding in the sub-skill's prompt — instruction to verify the bypass claim against current diff state. Possible outcomes:

- **VERIFIED**: bypass was load-bearing AND remains valid given current diff. Recorded but not escalated.
- **DEFER**: bypass remains pending (e.g., docs-update batched to end-of-feature; subsequent audit will re-check). Recorded.
- **ESCALATE**: bypass was load-bearing at the time but the diff has shifted such that the bypass would no longer be valid. Escalated to medium or high severity.

**Why trailers vs side-log**:

- Trailers travel with the commit (survive rebase, push, clone). Side-log files are local-only and flaky (interruptions, container rebuilds).
- Trailers are universally greppable via `git log`. Side-log requires custom tooling.
- Trailers are visible to anyone reading the PR (GitHub displays the full commit body).
- Git trailers + `prepare-commit-msg` are documented Git conventions. No new format invented.

##### C. `/ak-docs-review` (Layer 2 skill, audit-time)

**Path**: `.claude/skills/devshop/docs-review/SKILL.md`

**Purpose**: judge whether docs in the commit range are coverage-complete AND quality-adequate.

**Inputs (passed by orchestrator)**:

- `--range <SHA>..HEAD` — commit range to audit.
- `--feature-dir <path>` — `specs/<feature>/` for emitting findings.

**Repo awareness** (branches on `$GIT_ROOT`):

- `/devshop` → reads `/devshop/CLAUDE.md`, `/devshop/kit/docs/OVERVIEW.md`, `/devshop/kit/docs/MODEL.md`, full bodies of `kit/docs/guide/*.md`.
- `/workspace` (or any project) → reads `/workspace/CLAUDE.md`, `/workspace/OVERVIEW.md`, `/workspace/ARCHITECTURE.md`, per-package READMEs.

**Prompt structure**:

```
## Artifact
- Range: <SHA>..HEAD
- Diff: <git diff output>
- Bypass trailers harvested from range:
  - <commit SHA> Docs-Coverage-Bypass: <reason>

## Reference docs (always inlined, full body)
<top-level docs for this repo>

## Reference docs (flat catalog, ## headers only)
<deeper docs — guide/, FAQ, etc.>

## Section A — Coverage
Did the right docs get touched for what changed in this diff?
Rubric: [surface→doc mapping rules]

## Section B — Adequacy
For docs that DID get touched, are the updates substantive?
Rubric: [no-stub-edits, named-section claims verified by grep, etc.]

## Section C — Cross-doc coherence
Do the docs touched contradict any reference doc not in the diff?
Rubric: [check named claims survive against current state]

## Section D — Bypass trailer audit
For each harvested trailer: VERIFIED / DEFER / ESCALATE based on full diff context.

## Output format
For each finding: severity (high/medium/low) + section tag + file:line + fix.
0/0/0 → "Clean" entry.
```

**Source content for prompt**: built primarily by adapting the existing `docsReviewed` prompt in `adversarial-review.sh` (lines 84-228 today), restructured into the four sections above. The existing `CONVENTIONS_TO_INCLUDE` map content for `docsReviewed` ports directly into Section A's "Reference docs" and Section B's rubric.

**Output**: structured findings written to a tempfile read by orchestrator. Format consistent with how orchestrator builds the `## Audit N` section.

**Severity rules** (mirror current `/ak-test-review` scheme):

- `high` → halt audit. Operator must fix before ship.
- `medium` → surface in Phase 6 audit comment.
- `low` → noted in review.md, not surfaced elsewhere.

##### D. `/ak-tests-review` (Layer 2 skill, audit-time)

**Path**: `.claude/skills/devshop/tests-review/SKILL.md`

**Purpose**: judge whether tests in the commit range are coverage-complete AND quality-adequate.

**Critical**: this skill **absorbs the existing `/ak-test-review`** — all 150 lines of test-quality rubric content survive the rebuild via delete-and-rebuild. Specifically:

- Weak assertions section
- Missing error/invalid input tests section
- Untested auth boundaries (RLS) section
- Implementation detail tests section
- Missing boundary conditions section
- Shape-only assertions section
- WebKit form-state hydration race section
- Realtime test missing publication migration section
- Wrapper API design — lifecycle events not just data section
- Runtime validation at LLM / edge-function boundaries section
- Skipped tests audit section

These all become **Section B (Quality)** content in the rebuilt skill. The bats coverage in PR-A explicitly enumerates these 11 sub-sections and asserts they exist in the prompt — see § Bats coverage plan.

**Inputs**: same as `/ak-docs-review`.

**Repo awareness**:

- `/devshop` → tests = `kit/tests/**.bats`, source = `kit/scripts/**.sh`, `kit/hooks/**`, `.claude/skills/**`.
- `/workspace` → tests = `apps/*/**/*.test.ts`, `apps/*/**/*.spec.ts`, `packages/*/**/*.test.ts`, `apps/web/e2e/**`; source = corresponding non-test files.

**Prompt structure**:

```
## Artifact
- Range: <SHA>..HEAD
- Diff: <git diff output>
- Bypass trailers harvested:
  - <commit SHA> Tests-Coverage-Bypass: <reason>

## Reference rules (always inlined)
- Testing philosophy from kit/docs/guide/conventions.md § Non-Negotiables — Testing
- For project repos: § Test Presence + § Test Assertion Depth

## Section A — Coverage of new behavior
For each source change in the diff, verify a corresponding test
exercises the NEW behavior (not just file-pairing).
Rubric:
- New API wrapper → test for happy path AND invalid input AND unauthorized access
- New page.tsx / route.ts → e2e spec exercising the primary verb
- New RPC function → integration test
- ...

## Section B — Test quality
[All 150 lines from the prior /ak-test-review skill — restructured
into clear sub-sections but content unchanged.]

## Section C — Bypass trailer audit
Same shape as docs-review § D.

## Output format
Same as docs-review.
```

**Severity rules**: same as `/ak-docs-review`.

##### E. `/ak-check-docs-and-tests` (orchestrator, audit-time)

**Path**: `.claude/skills/devshop/check-docs-and-tests/SKILL.md`

**Purpose**: single operator entry point for the audit moment. Computes the commit range, invokes the two domain skills in sequence, appends `## Audit N` section to `specs/<feature>/review.md`.

**Inputs**:

- (none required) — defaults to feature-dir auto-detection.
- `--feature-dir <path>` — explicit override.
- `--range <SHA>..HEAD` — explicit range (rare; usually auto-computed).

**Behavior**:

1. **Resolve feature dir** (in order of preference):
   - If invoked from `/ak-build` Phase 3 or 5.8, the parent skill passes feature dir as arg.
   - Else: derive from current branch name (`feat/auth-improvements` → `specs/auth-improvements/`).
   - Else: ask operator (last resort).
   - If feature dir doesn't exist: scaffold `specs/<branch>/review.md` empty stub.
   - If branch is `main`: error out — audit is feature-level.

2. **Compute range**:
   - Read all `## Audit N:` section headers from review.md.
   - If none → range = `origin/main..HEAD`, audit_n = 1.
   - Else → latest section's `<!-- audited-at: <SHA> -->` → range = `<SHA>..HEAD`, audit_n = N+1.
   - If `<SHA>` doesn't exist (rebase) → fall back to `origin/main..HEAD`, add `<!-- rebased: prior audit at <missing-SHA> invalidated -->` note in the new section.
   - If `<SHA>` == HEAD → no-op with `✓ already audited at <SHA>`.

   Parser one-liner:

   ```bash
   grep -oP '(?<=<!-- audited-at: )[a-f0-9]+' "$FEATURE_DIR/review.md" | tail -1
   ```

3. **Invoke sub-skills**:
   - Call `/ak-docs-review` with range + feature dir.
   - Call `/ak-tests-review` with range + feature dir.
   - Each emits structured findings to a tempfile.
   - Both run sequentially (not parallel) — keeps logs readable, simpler error handling.

4. **Append `## Audit N` section** to `review.md` — see file-format spec above.

5. **Halt-or-continue**:
   - If any high-severity findings: print them to stdout, exit non-zero. Caller (`/ak-pre-ship` Gate 5 or operator) decides next steps.
   - If only medium/low: exit 0. Findings are recorded; no halt.

6. **Idempotence**: latest `## Audit N` section's audited-at SHA == HEAD → skill no-ops with `✓ already audited at <SHA>`. Phase 5.8.5 already uses this pattern (just on `<!-- audited-at -->` frontmatter on `test-review-followup.md`); the shape is preserved.

##### F. `adversarial-review.sh` narrowing

After PR-C, the script's CHECK_TYPE switch carries only bypass-reason check-types:

| Check-type             | Caller                | Job                                               |
| ---------------------- | --------------------- | ------------------------------------------------- |
| `prDescStaleReason`    | `.husky/pre-push`     | Judge "PR description matches commits" claim      |
| `dirtyTreeReason`      | `.husky/pre-commit`   | Judge "uncommitted changes are intentional" claim |
| `manifestReviewed`     | `commit-guard.sh`     | Judge `kit/manifest.txt` review claim             |
| `hookBypass`           | `commit-guard.sh`     | Judge generic hook-bypass reason                  |
| `exemptAddition`       | `commit-guard.sh`     | Judge addition to an exempt list                  |
| `testReviewSkipReason` | `/ak-build` Phase 5.8 | Judge "test-review skip" claim                    |
| `dismissalLog`         | `/ak-pre-ship`        | Judge Phase 6 dismissal rationale                 |

**Removed in PR-C**:

- `docsReviewed` (replaced by `/ak-docs-review` skill)
- `testCoverageProject` (replaced by `/ak-tests-review` skill)
- `docsFreshnessProject` (replaced by `/ak-docs-review` skill on project side)
- `testCoverage` (release-time devshop check; replaced by `/ak-tests-review` running per-merge)

CONVENTIONS_TO_INCLUDE map narrows correspondingly. Repo-mode detection (devshop vs project) stays — used by surviving check-types like `dismissalLog`. Model routing (Sonnet vs Haiku) stays — surviving check-types still use it.

##### G. Wiring into `/ak-pre-ship` and `/ak-build`

**`/ak-pre-ship` Gate 5** (`.claude/skills/devshop/pre-ship/SKILL.md`):

- Today: invokes `/ak-test-review`. Findings to `specs/<feature>/review.md § Gate 5`.
- After PR-A: invokes `/ak-check-docs-and-tests` (which calls both sub-skills). Findings flow into `## Audit 1` section instead of `## Gate 5` section.
- Gate name in the gate table → "Gate 5: docs + tests review" (was "Gate 5: test-review").
- All other Gate 5 references in the file get updated to point at the new orchestrator.

**`/ak-build` Phase 3** (`.claude/skills/devshop/build/SKILL.md`):

- Today: calls `/ak-pre-ship`, which in turn runs Gate 5 (`/ak-test-review`).
- After PR-A: same call shape, but Gate 5 now invokes `/ak-check-docs-and-tests`. The first audit's `## Audit 1` section gets appended to `review.md` as part of pre-ship.

**`/ak-build` Phase 5.8** (`.claude/skills/devshop/build/SKILL.md`):

- Today: invokes `/ak-test-review` over `<pre-ship-sha>..HEAD`, writes findings to `specs/<feature>/test-review-followup.md`.
- After PR-B: invokes `/ak-check-docs-and-tests` over the same range (auto-detected from latest `## Audit N` section's audited-at), appends `## Audit 2` section to `review.md`.
- Step 0 resume rung 1a: today reads `test-review-followup.md` to decide whether 5.8 already ran. After PR-B: reads `review.md`'s latest `## Audit N` section's audited-at.
- Phase 6 audit comment generation: today reads `review.md` + `test-review-followup.md`. After PR-B: reads `review.md` only (which now contains both `## Gate N` and `## Audit N` sections).

**Manual operator flow** (devshop):

- Operator runs `/ak-check-docs-and-tests` directly before ff-merge. Audit mechanic identical to the /ak-build path.

#### CLAUDE.md convention (added in PR-C)

Add to `/devshop/CLAUDE.md`:

> **Adversarial Layer 2 reviews fire at audit moments, not per commit.**
>
> Per-commit hooks run only Layer 1: deterministic file-existence math via `check-{tests,docs}-coverage-{project,devshop}.sh`. If a Layer 1 check is bypassed via `git -c devshop.<flag>=<reason>`, the `prepare-commit-msg` hook appends a `Tests-Coverage-Bypass:` or `Docs-Coverage-Bypass:` trailer to the commit message — recorded for audit-time review.
>
> Layer 2 (Sonnet judgment over the diff — `/ak-docs-review`, `/ak-tests-review`) fires when `/ak-check-docs-and-tests` is invoked:
>
> - **First audit**: when working code is done, before polish/review begins. Inside `/ak-build`, this is Phase 3. Manually, the operator invokes `/ak-check-docs-and-tests`.
> - **Second audit**: when polish is done, immediately before merge. Inside `/ak-build`, this is Phase 5.8. Manually, the operator re-invokes `/ak-check-docs-and-tests`.
>
> Devshop has no PR review surface — its audit moment is **before each ff-merge to main**. If the operator iterates locally between attempts, the audit is re-invoked. Idempotent.
>
> Both audits append to a single `specs/<feature>/review.md` (one `## Audit N` section per audit, each with its own `<!-- audited-at: <SHA> -->` HTML-comment stamp). The file is the historical record. The reviewer judges the _actual_ docs (CLAUDE.md, OVERVIEW.md, guide/\*) and _actual_ tests (.test.ts / .bats files), not the audit log itself.

#### Phased rollout

##### PR-A — audit mechanics, no removals

**Goal**: ship the orchestrator + both Layer 2 skills, wire them into `/ak-pre-ship` Gate 5. Validate the first-audit path on the project side. Per-commit Layer 2 still fires; nothing removed yet.

**Files created**:

- `.claude/skills/devshop/check-docs-and-tests/SKILL.md` (orchestrator)
- `.claude/skills/devshop/docs-review/SKILL.md` (new sub-skill)
- `.claude/skills/devshop/tests-review/SKILL.md` (rebuild — fully replaces existing `/ak-test-review` content; absorbs all 150 lines of quality rubric, adds new Section A coverage rubric)
- `kit/tests/util-check-docs-and-tests.bats` (orchestrator behavior tests)
- `kit/tests/util-docs-review.bats` (sub-skill smoke + range-detection tests)
- `kit/tests/util-tests-review.bats` (sub-skill smoke + range-detection tests + the 11-sub-section content-survival assertions)

**Files modified**:

- `.claude/skills/devshop/pre-ship/SKILL.md` — Gate 5 invokes `/ak-check-docs-and-tests` instead of `/ak-test-review`. Rename gate label. Update gate table.
- All references to `/ak-test-review` in `.claude/skills/devshop/**/SKILL.md`, `kit/docs/guide/*.md`, root `CLAUDE.md` — mechanical rename to `/ak-tests-review`.

**Files deleted**:

- The old `test-review/` skill directory (the rename to `tests-review/` is a delete + rebuild). The bats test docstring for `util-tests-review.bats` includes a pointer like:
  > If you need to recover the original `/ak-test-review` content for reference: it was at commit `<SHA>` in `.claude/skills/devshop/test-review/SKILL.md` (renamed to `tests-review/` and rebuilt in PR-A on `<date>`).

**No-ops in PR-A**:

- Per-commit `docsReviewed` still fires.
- `testCoverageProject` and `docsFreshnessProject` Layer 2 still fire from their respective hooks.
- `testCoverage` still fires at release time.
- Layer 1 scripts retain their current names (renames in PR-C).
- Bypass trailer mechanic NOT YET active.

**Validation criteria**: a `/ak-build` cycle on a real PR produces a `## Audit 1` section in `review.md` with non-zero findings that match what `/ak-test-review` would have caught + adds new docs-coverage findings the old skill couldn't surface.

**Estimated effort**: 5–7 hours.

##### PR-B — Phase 5.8 wiring + collapse two-file model

**Goal**: wire `/ak-check-docs-and-tests` into `/ak-build` Phase 5.8. Collapse `test-review-followup.md` into the single-file `review.md` `## Audit N` model. Validate the second-audit path.

**Files modified**:

- `.claude/skills/devshop/build/SKILL.md`:
  - Phase 5.8 invokes `/ak-check-docs-and-tests` over the latest-audit-to-HEAD range.
  - Step 0 resume rung 1a: read latest `## Audit N` section's audited-at instead of `test-review-followup.md` frontmatter.
  - Phase 5.8.5 idempotence: same shift.
  - Phase 6 audit comment generation: read only `review.md` (which now contains both Gate N and Audit N sections); remove `test-review-followup.md` references.

**Convention removed**:

- Writing to `test-review-followup.md`. The path is no longer referenced.
- Existing `specs/*/test-review-followup.md` files are NOT deleted (historical record); just not produced anew.

**Validation criteria**: a `/ak-build` Phase 5.8 invocation produces a `## Audit 2` section appended to `review.md`. Phase 6 audit comment surfaces both audit findings. No `test-review-followup.md` produced.

**Estimated effort**: 4–6 hours.

##### PR-C — remove per-commit Layer 2, add devshop docs Layer 1, symmetry rename, bypass trailers

**Goal**: cost savings land. Per-commit Layer 2 invocations removed. Devshop docs Layer 1 added. All Layer 1 scripts renamed for symmetry. Bypass trailer emission active.

**Files created**:

- `kit/scripts/commit-hooks/check-docs-coverage-devshop.sh` (NEW; surface→doc mapping per § A)
- `kit/scripts/commit-hooks/append-bypass-trailers.sh` (NEW; ~20 lines, called from `prepare-commit-msg`)
- `template/.husky/prepare-commit-msg` (NEW; calls `append-bypass-trailers.sh`)
- `kit/tests/guard-docs-coverage-devshop.bats` (bats coverage)
- `kit/tests/util-bypass-trailers.bats` (trailer emission + round-trip)

**Files renamed** (`git mv` to preserve history):

- `check-test-coverage-project.sh` → `check-tests-coverage-project.sh`
- `check-test-coverage.sh` → `check-tests-coverage-devshop.sh`
- `check-docs-freshness-project.sh` → `check-docs-coverage-project.sh`

**Files modified**:

- All four `check-*-coverage-*.sh` scripts: read the bypass flag without LLM judgment (just accept/block based on flag presence). Trailer emission lives in the new `prepare-commit-msg` hook, not in pre-commit scripts.
- `kit/scripts/commit-hooks/commit-guard.sh`:
  - Remove `docsReviewed` invocation (used to fire after Layer 1; now nothing fires there).
- `kit/scripts/adversarial-review.sh`:
  - Remove `docsReviewed`, `testCoverageProject`, `docsFreshnessProject`, `testCoverage` check-type cases.
  - Remove their CONVENTIONS_TO_INCLUDE entries.
  - Verify remaining check-types still pass their bats coverage.
- `kit/scripts/release.sh`:
  - Remove `release-coverage` adversarial-review.sh `testCoverage` invocation.
  - Reduce release flow to: bump version + write semantic tag-description summary.
- `kit/hooks/pre-commit.sh`:
  - Update Layer 1 script invocations to renamed paths.
  - Add invocation of new `check-docs-coverage-devshop.sh`.
- `/devshop/CLAUDE.md`: add convention block above.
- `kit/docs/guide/hooks.md`:
  - Update Layer 1 ↔ Layer 2 description to reflect new architecture.
  - Document bypass trailer mechanic + `prepare-commit-msg` hook.
- `kit/docs/guide/conventions.md`:
  - Add `§ Bypass trailers` documenting trailer keys and their meanings.
  - Update `§ Test Presence` and `§ Project Docs Freshness` (rename → `§ Project Docs Coverage`) to reflect new layer split.
- All bats files referencing renamed scripts: update paths.

**Validation criteria**:

- A devshop commit that touches `kit/scripts/**.sh` without staging any guide doc → `check-docs-coverage-devshop.sh` blocks (Layer 1).
- Bypass via `git -c devshop.docsCoverageReason="<why>"` accepts the commit AND the resulting commit has a `Docs-Coverage-Bypass: <why>` trailer (validated via `git log --format=%B`).
- A subsequent `/ak-check-docs-and-tests` over a range containing such a commit harvests the trailer and surfaces a `[bypass-revisit]` finding.
- A devshop merge to main no longer triggers any per-commit Layer 2 calls. Cost-comparison: 5–15 commits × $0.10 → 0 per-commit + 1–2 audit × $0.10–0.30.
- `release.sh` runs without invoking `testCoverage`; release output is a tag with semantic summary.

**Estimated effort**: 3–5 hours.

##### PR ordering rationale

PR-A and PR-B prove the audit mechanic on real `/ak-build` cycles before PR-C removes the per-commit safety net. Each PR is independently revertible:

- Revert PR-C → per-commit Layer 2 returns; audits still work; no lost data.
- Revert PR-B → Phase 5.8 returns to its old `test-review-followup.md` shape; first-audit + pre-ship Gate 5 still works.
- Revert PR-A → full pre-change state.

PR-C is the load-bearing cost-savings step. If audits prove unreliable on real cycles, hold PR-C indefinitely and operate in dual-mode (per-commit + audit both fire).

#### Bats coverage plan

| File                                               | What it tests                                                                                                                                                                                                                                                                                                                  |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `kit/tests/util-check-docs-and-tests.bats`         | Orchestrator: range computation, idempotence (same SHA → no-op), feature-dir auto-detection, missing-feature-dir scaffolding, rebase detection (missing audited-at SHA), branch=main rejection, Audit N numbering, halt-on-high.                                                                                               |
| `kit/tests/util-docs-review.bats`                  | Sub-skill: prompt structure (4 sections present), repo branching (devshop vs workspace), bypass trailer harvesting from range, finding format, severity grading, output file format.                                                                                                                                           |
| `kit/tests/util-tests-review.bats`                 | Sub-skill: same structure as docs-review but tests-domain. **Critical**: includes assertions confirming all 11 sub-sections from the prior `/ak-test-review` skill survived the rebuild (test the prompt content, not just structure). Docstring includes commit-pointer to original `/ak-test-review` SKILL.md for debugging. |
| `kit/tests/guard-docs-coverage-devshop.bats`       | Layer 1: surface→doc mapping rules from § A, all carve-outs honored, bypass via flag accepts (does not block). ~20 cases mirroring existing `guard-docs-freshness-project.bats`.                                                                                                                                               |
| `kit/tests/util-bypass-trailers.bats`              | `prepare-commit-msg` hook: trailer emission given flag set, no trailer when flag unset, correct key per domain (Tests-Coverage-Bypass / Docs-Coverage-Bypass), `git interpret-trailers --in-place` round-trip preserves message body.                                                                                          |
| `kit/tests/guard-tests-coverage-devshop.bats`      | Existing `guard-test-coverage.bats` renamed; verify rename didn't break anything; flag-presence behavior.                                                                                                                                                                                                                      |
| `kit/tests/guard-docs-coverage-project.bats`       | Existing `guard-docs-freshness-project.bats` renamed; flag-presence behavior.                                                                                                                                                                                                                                                  |
| `kit/tests/guard-tests-coverage-project.bats`      | Existing `guard-test-coverage-project.bats` renamed; flag-presence behavior.                                                                                                                                                                                                                                                   |
| `kit/tests/util-adversarial-review-narrowing.bats` | After PR-C: verify removed check-types fail with `unknown check type` rather than firing the old code path. Verify surviving check-types still pass.                                                                                                                                                                           |

Existing `kit/tests/util-adversarial-review*.bats` files: PR-C updates them to remove cases for the deleted check-types.

#### Risks & mitigations

| Risk                                                                                                                                                      | Severity                 | Mitigation                                                                                                                                                                                                                                                                                         |
| --------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Lost fast-feedback during iteration: today operators get an LLM check at commit time pointing out missing docs while context is fresh; audit defers that. | Medium                   | Layer 1 still blocks obvious gaps deterministically (added a `route.ts` without staging CLAUDE.md → block). Audit judgment moves to a moment where it has the full diff and the docs HAVE been written, producing higher-signal findings.                                                          |
| Bypass trailer mechanic adds complexity (new hook).                                                                                                       | Low                      | `prepare-commit-msg` is a documented git hook, not an invented mechanism. ~20 lines of bash. Bats coverage validates emission and round-trip.                                                                                                                                                      |
| `/ak-tests-review` rebuild loses content from prior `/ak-test-review`.                                                                                    | **High** (if it happens) | Bats test in `util-tests-review.bats` enumerates the 11 required sub-sections and asserts they exist in the prompt. Test fails if any are dropped. Docstring points at the commit where original lives in git history for recovery. **This is the highest-risk piece of PR-A** — must not regress. |
| Audit produces noisy `[bypass-revisit]` findings even when bypass was load-bearing.                                                                       | Medium                   | Reviewer prompt is explicit: VERIFIED bypasses are a separate finding category, not noise. Findings list shows bypass→outcome explicitly so operators can grep VERIFIED to ignore.                                                                                                                 |
| Phase 5.8.5's idempotence regresses on the new `## Audit N` parser.                                                                                       | Low                      | Bats coverage in `util-check-docs-and-tests.bats` covers idempotence. PR-B includes a parser-stability test.                                                                                                                                                                                       |
| `/ak-build` Phase 6 audit comment regresses on collapsed two-file model.                                                                                  | Low                      | PR-B adds bats coverage for Phase 6 reading both Gate N and Audit N sections from a single file.                                                                                                                                                                                                   |
| Cost savings don't materialize because operators don't run audit.                                                                                         | Low                      | `/ak-build` Phase 3 + 5.8 invoke audit automatically. Manual flow documented in CLAUDE.md convention block. Nothing relies on operator memory.                                                                                                                                                     |

#### Why v0

Cost saving is non-trivial (Sonnet calls per ship: 5–15× → 1–2×). More importantly, the per-commit Sonnet model produces low-signal reviews (asks for docs that aren't ready yet), pushing developers toward generic bypass reasons. Concentrating the review at audit moments produces higher-signal output and matches how docs/tests actually get written.

#### Trigger

- Lalista chapter 1m or 1k is the next `/ak-build` invocation. PR-A could land before that ships, validating the first-audit path on a real PR.
- OR: a second devshop project shows up — the per-commit cost compounds across projects.

#### Cross-references

- `/ak-build § Phase 5.8` (shipped 2026-05-05) — the second-audit path that PR-B extends.
- `/ak-pre-ship § Gate 5` — currently runs `/ak-test-review`; PR-A switches to `/ak-check-docs-and-tests`.
- `kit/scripts/adversarial-review.sh § CONVENTIONS_TO_INCLUDE` — the inlining map; narrowed in PR-C.
- `kit/scripts/commit-hooks/check-{test-coverage,docs-freshness}-project.sh` — Layer 1 stays; renamed + Layer 2 invocation removed in PR-C.
- `kit/scripts/commit-hooks/commit-guard.sh § docsReviewed` — removed in PR-C.
- `kit/scripts/release.sh § release-coverage` — removed in PR-C. Release flow simplifies to: bump version + semantic tag-description summary.
- `kit/notes/roadmap/adversarial-review-doc-inlining.md` — prior architectural work on the same engine; this RFC builds on its convention-inlining model.

#### Cost & reversibility summary

- PR-A: 5–7 hours. Adds skills + bats coverage. No removals. Lowest risk; highest content load (the `/ak-tests-review` rebuild).
- PR-B: 4–6 hours. Phase 5.8 wiring + two-file collapse. Validates second-audit path.
- PR-C: 3–5 hours. Removes per-commit Layer 2, adds devshop docs Layer 1, renames for symmetry, activates bypass trailers, adds CLAUDE.md convention. Cost savings land here.
- **Reversibility**: each PR is independently revertible. PR-C is the load-bearing cost-saving step; if it bites harder than expected, reverting it alone keeps PR-A + PR-B's audit mechanics in place.

---

### Audit `kit/docs/guide/conventions.md` → distribute operational copy into the skills that fire

**Problem.** `kit/docs/guide/` (including `conventions.md`) is loaded **on demand only** — never at session start. Skills load their own `SKILL.md` content when invoked. So a convention placed only in `conventions.md` is a paper rule: it never enters my context unless I happen to grep for it. The session that surfaced this (2026-04-26) read `/ak-build` SKILL.md's "Without this, gh run download fails" prereq line, decided artifact-pull was blocked, and never opened `conventions.md` to find the routing rule that would have told it otherwise.

**Tier model** (from the 2026-04-26 audit):

| Tier | Content                                                                        | Loaded when                                |
| ---- | ------------------------------------------------------------------------------ | ------------------------------------------ |
| 1    | `/devshop/CLAUDE.md` (+ project `CLAUDE.md` per session via SessionStart hook) | Every session start                        |
| 2    | Skill `SKILL.md` files                                                         | Only when the matching slash command fires |
| 3    | `kit/docs/guide/**`, `kit/docs/OVERVIEW.md` (incl. § Concept), `FAQ.md`        | Only when explicitly read or grep'd        |

Operational rules belong in Tier 1 (cross-cutting principles) or Tier 2 (skill-specific actions). Tier 3 is the human-browseable encyclopedia + cross-reference index.

**Audit (mapping each `conventions.md` section to its action skill, surfaced 2026-04-26):**

| Section in `conventions.md`                                           | Where it actually fires                                                                 | Current state                               | Action                                                                                                                               |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Metrics Lifecycle                                                     | `/ak-spec` (event-add gate at decision time), `/ak-build` Phase 0.2 (decisions preview) | Likely already in `/ak-spec`; verify        | Verify replication; remove from conventions.md if duplicated, OR keep conventions.md as reference + ensure skill copy is canonical   |
| Events / Feature Flags taxonomy                                       | reference taxonomy (no specific skill)                                                  | Reference-only                              | Keep in conventions.md as Tier 3 reference                                                                                           |
| TASKS.md Format                                                       | `/ak-implement` (writes the file)                                                       | Likely in `/ak-implement` SKILL.md; verify  | Verify; canonical home is the skill                                                                                                  |
| SPEC.md Quality Checklist                                             | `/ak-spec`                                                                              | Likely in `/ak-spec` SKILL.md; verify       | Verify; canonical home is the skill                                                                                                  |
| DESIGN.md as Contract (`design-conformance` (ak) gate)                | `/ak-pre-ship` Gate 3                                                                   | Likely in `/ak-pre-ship` SKILL.md; verify   | Verify; canonical home is the skill                                                                                                  |
| Screenshot Routing                                                    | `/ak-pre-ship` (screenshot capture)                                                     | Likely in `/ak-pre-ship` SKILL.md; verify   | Verify; canonical home is the skill                                                                                                  |
| Deploy Boundaries                                                     | `/ak-go-live`                                                                           | Possibly in `/ak-go-live` SKILL.md; verify  | Verify; canonical home is the skill                                                                                                  |
| Supabase Hardening Defaults (incl. `ON DELETE on auth.users` rule)    | migration time (no dedicated skill)                                                     | Reference-only                              | Lift the principles to `/devshop/CLAUDE.md § Implementation Approach`; keep details in conventions.md as reference                   |
| Confidence Calibration                                                | every decision the agent makes                                                          | Tier 3 only — paper rule                    | **Move to `/devshop/CLAUDE.md` (Tier 1)** — cross-cutting; affects every action                                                      |
| TODO Protocol                                                         | every out-of-scope discovery                                                            | In CLAUDE.md ✓ + conventions.md (duplicate) | Drop conventions.md copy; CLAUDE.md is canonical                                                                                     |
| Backlog Routing Guide                                                 | every TODO filing                                                                       | In CLAUDE.md (paraphrased) + conventions.md | Either lift the table verbatim into CLAUDE.md, or keep table in conventions.md and ensure CLAUDE.md cross-refs it                    |
| Test Assertion Depth                                                  | `/ak-test-review`                                                                       | Likely in `/ak-test-review` SKILL.md ✓      | Verify; canonical home is the skill                                                                                                  |
| Testing Lifecycle                                                     | `/ak-implement` (test-after-task discipline)                                            | Likely already there; verify                | Verify; canonical home is the skill                                                                                                  |
| Kit Testing                                                           | bash test authoring (no dedicated skill)                                                | Reference-only                              | Keep in conventions.md as Tier 3 reference                                                                                           |
| Non-Negotiables → Testing                                             | every commit                                                                            | Tier 3 only — but rule is cross-cutting     | **Lift to `/devshop/CLAUDE.md` § Non-Negotiables** (already exists there) — verify match + drop the conventions.md copy if redundant |
| Non-Negotiables → Metrics / Responsive + Theme / PWA / Code Structure | per-action gates                                                                        | Skill-resident                              | Verify each is in the right gate's skill copy                                                                                        |

**Why v0 — blocks next-project adoption:**

The first project that scaffolds the devshop today inherits a guide-conventions tree that looks authoritative but isn't load-bearing. Their first `/ak-build` run reads SKILL.md (good) and `/devshop/CLAUDE.md` (good) and never opens `conventions.md` (oops). Conventions written-but-never-followed are worse than no conventions, because they create the illusion that the agent will respect them. Fixing the placement once means future projects start with a tier model that actually fires.

**Trigger:**

- Lalista PR 26 (e2e-audit-fill-gaps) ships with the "closure rule" already moved correctly (`/ak-build` Phase 5.6 + CLAUDE.md + a one-line pointer in conventions.md). That's the worked example; the audit + sweep is the generalization.
- OR: a second project surfaces a "convention not followed" issue traceable to a conventions.md-only rule.

**Cross-ref:**

- `/ak-build § Phase 5.6` — the destination skill for the closure rule (worked example shipped 2026-04-26).
- `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships` — Tier 1 home for the closure rule.
- `/devshop/CLAUDE.md § Context Loading` — describes the load tiers but doesn't yet name the implication ("rules in Tier 3 don't fire").
- `/devshop/kit/docs/guide/conventions.md` — the file being audited.

**Cost/risk:**

- Implementation: ~3-5 focused hours per skill (read each skill's `SKILL.md`, identify operational rules, ensure each is restated where it fires; cross-ref conventions.md sections to confirm). Adversarial-review docs-drift will check each skill change carefully — budget review-cycle time accordingly.
- Risk: low — non-functional doc shuffling. Worst case: a temporary duplication that gets resolved on the next audit pass. No production code changes.
- Benefit: rules actually fire. Closes the "paper rule" footgun for every future devshop project.

**Adjacent v0 entry**: § Adversarial reviewer reads guide/ for convention checks (below) — the same audit's other half. They can ship as one PR (sweep skills + amend reviewer prompts in the same change) or as two — the latter is cleaner because the skill audit is more text-heavy and the reviewer change is more structural.

---

### Adversarial reviewer reads `guide/` for convention checks

**Problem.** The current pre-commit adversarial reviewers (`commit-guard.sh` + `adversarial-review.sh`) check whether **bypass reasons** are valid (e.g., is the docsReviewed note thorough? is the dirtyTreeReason load-bearing?). They don't check whether the **commit itself** follows the project's documented conventions. So a commit that adds a feature without a test, or adds a metric event without registering it in `METRICS.md`, or skips a doc update that conventions require, sails through the reviewer because the bypass-reason gate is the only checkpoint.

The agent often forgets convention X (especially one buried in conventions.md per the sibling audit above), and the reviewer doesn't catch it because it doesn't know X exists.

**Shape of the fix:**

Extend the adversarial-review prompt construction to **inline relevant `kit/docs/guide/` sections** as context the reviewer uses to flag convention violations. Two modes:

1. **Inline conventions in the existing per-flag reviewers** (cheap, additive). Each existing review (`docsReviewed`, `prDescStaleReason`, etc.) gets the relevant conventions appended to its prompt: "These are the documented conventions for this concern; flag the commit if it violates them." E.g., the `docsReviewed` reviewer gets `conventions.md § Metrics Lifecycle` and `§ Non-Negotiables → Testing`; the `prDescStaleReason` reviewer gets nothing (no relevant convention).

2. **A new "convention check" gate** that runs unconditionally on every commit (no bypass flag). Reads the diff, reads the conventions, asks the reviewer: "Does this diff follow them?" Cheaper path: only fire on commits that touch `apps/**` / `packages/**` / `supabase/**` (real code), skip on docs-only.

**Implementation surface:**

- `kit/scripts/adversarial-review.sh` — extend the prompt builder to inline guide sections by topic. Add a `CONVENTIONS_TO_INCLUDE` map keyed by review topic.
- `kit/scripts/commit-hooks/commit-guard.sh` — add a `convention-check` gate (or fold into existing gates per option #1 above).
- `kit/scripts/preship/check-conventions.sh` (new) — option #2's standalone check, invoked from pre-commit.
- `kit/tests/<corresponding>.bats` — coverage tests using fixture commits that violate / follow each convention.

**Why v0 — blocks next-project adoption:**

The whole reason `kit/docs/guide/conventions.md` exists is to encode "how this devshop wants you to work." Without an automated check, the conventions are aspirational — agents follow them when convenient and skip them when not, with no mechanism to catch the skip. New projects bring new convention pressure (mobile devshop adds touch-target rules, etc.); each new convention adds maintenance burden if it's only enforced by future-Claude-remembering. Codifying convention-check at commit-time means each documented rule is also enforced.

**Sequencing with the conventions audit (above):**

Order matters. Audit first, reviewer-check second. Reasons:

1. The audit moves operational rules out of conventions.md into skills. Once rules are in skills, the reviewer can prompt against the SKILL.md content directly (no need to inline guide/conventions.md). Conventions.md becomes pure reference (taxonomies, examples).
2. Without the audit first, the reviewer prompt would inline content that's also being moved — risky doc drift during the convention-check ship.
3. Audit also surfaces which conventions are operational (worth enforcing) vs aspirational (reference-only) — the reviewer should only enforce the former.

**Trigger:**

- Conventions audit (above) lands on devshop main.
- OR: a real "convention violation slipped through review" incident that costs an hour+ of debugging.

**Cross-ref:**

- `/devshop/kit/scripts/adversarial-review.sh` — the prompt builder to extend.
- `/devshop/kit/scripts/commit-hooks/commit-guard.sh` — the gate-orchestration point.
- `/devshop/kit/docs/guide/hooks.md` — documents the existing adversarial-review pattern; will need updates when this ships.
- Sibling entry above (conventions audit) — load-bearing prereq.

**Cost/risk:**

- Implementation: ~2-3 focused hours (prompt builder changes + new gate + bats coverage).
- Risk: false positives if the reviewer misreads convention scope (e.g., flags a "missing test" for a doc-only PR). Mitigate via narrow prompts + diff-aware filtering before invoking the reviewer.
- Benefit: documented conventions become enforced conventions, end-to-end. Closes the gap between "we wrote it down" and "the agent follows it."

---

### Migration sequencing safety nets for the Vercel-preview window

**Problem.** The lalista-style architecture pipes the same `NEXT_PUBLIC_SUPABASE_URL` (= prod) into all three Vercel envs (Production, Preview, Development) per `/ak-new-project § Step 13`, so **Vercel previews dial prod Supabase**. `deploy-migrations.yml` runs `on: push: main` — migrations apply only at merge-time, not when the PR opens. That creates a window between PR-open and PR-merge where:

- Feature branch has migration M+1 applied to its slow-job-CI local stack (`supabase start` + `supabase db reset` apply all migrations).
- Vercel preview front-end is on M+1 code, but reads prod which is still on schema M → preview is broken or surfaces wrong shape.
- Reviewer opens preview, can't tell whether what they see is a real bug or a schema-lag artifact.

The architecture's implicit assumption is that **all migrations are backwards-compatible in BOTH directions during the PR window**:

- New code on old schema must work (e.g., handles missing column with default)
- Old code on new schema must work (e.g., new NOT NULL column has a default)

Additive migrations satisfy this. Mutating migrations (renames, drops, NOT NULL without default, type changes) violate it — they break preview during the PR window.

**Why DiD doesn't fully solve this.** The pending lalista PLAN row `devshop-preship-hardening` ships DiD (`/var/run/docker.sock` bind-mount) so `supabase start` runs in the devcontainer. After that ships:

- ✅ qa-walk during dev runs against the local stack (no migration race)
- ✅ `pnpm dev` reads from local stack
- ✅ `/qa`, `/qa-only`, `/design-review` (when their separate v0 entry ships) run against local stack
- ❌ Vercel previews still hit prod (DiD is irrelevant — Vercel runs on Vercel's infrastructure)

So DiD closes the dev-side gap but not the Vercel-preview gap. This entry addresses the Vercel-preview side specifically.

**Shape of the fix** — three coordinated safety nets:

#### Track A: `/ak-spec` migration scoping prompt

When a feature spec includes a migration, the spec subagent (or `/ak-build § Phase 0` decisions preview) must ask:

> "Is this migration backwards-compatible in BOTH directions during the PR window? (a) New code on old schema works (e.g., handles missing column gracefully) AND (b) old code on new schema works (e.g., new NOT NULL column has a default)."

If yes (additive) → ship normally.

If no (mutating) → spec must include a **staged-deploy plan** under a "Migration Sequencing" section:

- Apply the migration to prod manually before merging the code PR (operator runs `supabase db push --include-roles` or triggers `deploy-migrations.yml` via `workflow_dispatch`); OR
- Document the brief preview-breakage window the team accepts during the PR review (timeboxed: "preview is intentionally broken from PR-open to PR-merge; expect <2hr").

The decision is recorded in the spec; later phases (`/ak-pre-ship` and `/ak-go-live`) cross-check.

**Edit targets:** `.claude/skills/devshop/spec/SKILL.md` (or wherever migration-scoping prompts live) — add the question + decision-tree paragraph. `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 4` (Realtime publication) is adjacent but different — keep this in its own subsection.

#### Track B: `/ak-go-live § Step 1.6` migration sequencing pre-flight (do this first; highest-leverage)

Before invoking `/land-and-deploy`, if the PR diff touches `supabase/migrations/**`, classify the migration and surface the right action:

```bash
MIGRATIONS_TOUCHED=$(git diff --name-only "origin/${BASE}...HEAD" | grep -E '^supabase/migrations/' || true)
if [ -n "$MIGRATIONS_TOUCHED" ]; then
  # Read the migration file(s); classify additive vs mutating
  # Heuristic: presence of CREATE TABLE / ALTER TABLE ADD COLUMN ... DEFAULT
  # without DROP / RENAME / ALTER COLUMN SET NOT NULL → likely additive.
  # If the spec already declared the migration's compatibility in
  # specs/<feature>/spec.md § Migration Sequencing, trust that.
  ...
fi
```

If migration is **additive** → continue normally; the post-merge `deploy-migrations.yml` race is fine per the existing comment in that workflow.

If migration is **mutating** → AskUserQuestion before proceeding to merge:

> The PR's migration `<NNN>_<name>.sql` is mutating (rename / drop / NOT NULL without default). After merge, Vercel auto-deploys the front-end in parallel with `deploy-migrations.yml`; for ~30-60s prod runs new code against old schema → user-visible 500s.
>
> Options:
>
> - **Apply migration to prod first, then merge** — recommended. Run `supabase db push --include-roles` against prod (or trigger `deploy-migrations.yml` via `workflow_dispatch`); confirm prod schema is M+1; then merge the code PR. Closes the race window.
> - **Merge anyway, accept the brief breakage window** — only if the spec already documented this as an accepted trade-off (cross-check `specs/<feature>/spec.md § Migration Sequencing`).
> - **Pause and re-spec** — if the spec didn't document this, the spec author skipped Track A's check; surface the gap.

This is the **highest-leverage capture** because it catches the most dangerous case (non-additive migration about to merge with prod still on old schema) at the most actionable moment (right before merge).

**Edit targets:** `.claude/skills/devshop/go-live/SKILL.md` — add Step 1.6 between the existing Step 1.5 (prod-curl probe) and Step 2 (`/land-and-deploy`). Step 1.6 only fires when the diff touches migrations.

#### Track C: `kit/docs/guide/ops.md § Migration Sequencing` (documentation backstop)

Add a new section to ops.md documenting:

- The architecture's "additive-only during PR window" assumption (cross-ref `apps/web/.github/workflows/deploy-migrations.yml`'s sequencing-note comment as the authoritative source on the post-merge race; this section adds the pre-merge half).
- The two-phase manual deploy recipe (operator-side `supabase db push`).
- Decision tree: additive → ship normally; mutating → two-phase OR documented acceptance.
- Cross-ref to Tracks A + B as the operational enforcement points.

**Edit targets:** `kit/docs/guide/ops.md` — new `## Migration Sequencing` section (place after `## CI/CD` or wherever migration-related ops content lives).

**Why v0 — blocks next-project adoption:**

Every devshop project that adopts the Vercel + Supabase + auto-deploy-on-merge pattern (which is the default `/ak-new-project` shape) inherits this gap. Without these safety nets:

- Spec authors don't think about migration compatibility until reviewers spot it (or worse, until prod breaks).
- Operators rely on remembering to manually push migrations for non-additive changes — easy to forget.
- The Vercel preview's apparent brokenness during PR review confuses reviewers and erodes trust in the preview signal.

These three tracks codify the discipline once at the devshop level so every project gets it for free.

**Sequencing recommendation (do them in this order):**

1. **Track B first** (`/ak-go-live § Step 1.6` pre-flight). Highest leverage; catches the most dangerous case at the most actionable moment. Single SKILL.md edit, ~30 lines. If this fires often enough that the patterns become clear, escalate to Tracks A + C; if it fires rarely (because the team's migrations are mostly additive), Track B alone may be sufficient and Tracks A + C can be skipped or deferred.
2. **Track A second** (spec scoping prompt). Shifts the decision earlier — better, but requires `/ak-spec` (or Phase 0 decisions preview) to grow a new question category. Worth doing once Track B's data shows the pattern is real and frequent.
3. **Track C third** (ops.md doc). Wraps it up with the documentation backstop. Cheapest of the three (~30 min); ship after A + B so the doc references the actually-shipped operational rules rather than aspirational ones.

If the project's migration cadence is mostly additive (typical for early-stage products), **Track B alone** is sufficient and A + C can stay as "file-and-forget" reminders. The ordering preserves option value: Track B's data tells you whether to invest in A + C.

**Trigger:**

- A second project adopts the devshop and hits the migration-sequencing question on its first non-additive migration; OR
- Lalista hits a non-additive migration in PR 6 (Zod) / PR 7 (structured intent parsing) — Zod doesn't add migrations, structured intent parsing might add `quantity` / `unit` columns to `list_entries` (already exist per the v0 § 1k spec, so this is also additive). So lalista may not trigger this on its current PR queue; second-project adoption is the more likely trigger.

**Cross-ref:**

- `apps/web/.github/workflows/deploy-migrations.yml` — the sequencing-note comment in this file is the authoritative description of the **post-merge** race. This entry adds the **pre-merge** half (PR-open to merge window).
- `lalista PLAN.md row 2 (devshop-preship-hardening)` — closes the dev-side gap (DiD bind-mount, qa-walk against local stack); Vercel-preview gap remains regardless.
- `/devshop/kit/notes/roadmap/qa-options.md` — original QA-backend isolation discussion that surfaced the dev-side gap.
- `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 4` (Realtime publication) — adjacent migration-discipline pattern; same migration file usually carries Realtime publication adds, so spec scoping in Track A naturally covers both.

**Cost/risk:**

- **Track B implementation**: ~1 hour (single SKILL.md edit + bats coverage if the existing pre-flight has bats). Adversarial-review docs cycles add 2-3 cycles per commit.
- **Track A implementation**: ~2 hours (spec subagent prompt extension + worked example in `kit/docs/guide/supabase-ssr-boilerplate.md`).
- **Track C implementation**: ~30 min (ops.md doc section + cross-refs).
- **Risk during rollout**: false positives in Track B's classifier (e.g., misclassifies an `ALTER TABLE` that's actually safe because of a default). Mitigate via the spec's pre-declared classification (Track A) when present; fall back to "ask the user, prefer manual two-phase" when uncertain.
- **Benefit**: catches the most dangerous migration-sequencing failure mode at the right moment; codifies the "additive-only during PR window" assumption explicitly so it's a deliberate architecture choice rather than an undocumented surprise.

**Out of scope (deferred to v1 if/when needed):**

- A **staging Supabase project** with separate Vercel preview env override + a staging-targeted `deploy-migrations.yml` variant. The full-isolation solution. Lower priority because (a) most projects accept the Vercel-preview gap as a trade-off if migrations are mostly additive, (b) it doubles the Supabase-project management overhead, (c) staging-vs-prod data drift becomes its own problem. Revisit if multiple projects adopt the devshop and report frequent Vercel-preview-broken-by-pending-migration incidents — that's the data signal that the trade-off is no longer acceptable.

---

### CI slow-job lifecycle convention

Today `/devshop/template/.github/workflows/ci.yml` ships the `slow:` job entirely commented out (lines 75-113, including the lalista-PR-26 edge-runtime health-check retry pattern). `/ak-new-project` Step 24 explicitly defers slow-job adoption to "after Phase 1c (integration tests + supabase start) or Phase 1g (Playwright E2E)" with branch-protection contexts updated from `["fast"]` to `["fast","slow"]`. That deferral is correct — there's no point running a slow job when there's nothing to run. But once a project crosses the threshold, **nothing structural enforces that the slow job actually gets uncommented, that branch protection gets updated, or that subsequent integration/E2E specs get included in its globs**. Maintenance is operator-memory only.

Lalista's slow job got uncommented when Phase 1c shipped, but the wiring quality is hand-maintained — PR 26 surfaced an edge-runtime startup flake the operator had to debug + retry-loop manually. Future projects will hit the same class of issue without the lalista-codified retry pattern unless the convention enforces it.

**Shape of the convention:**

- **`/ak-spec` migration-scoping prompt extension**: when a spec includes the project's first integration test or Playwright spec, the spec subagent must surface "this is the Phase 1c / 1g threshold — uncommenting the slow job is part of the spec's scope, not a follow-up" as an explicit decision row. Today this is implicit in `/ak-new-project § Step 24`; making it spec-time-explicit means the slow-job ship lands in the same PR as the test that needs it.
- **`/ak-pre-ship` gate**: new check that runs when `*.integration.test.ts` or `apps/web/e2e/*.spec.ts` files are present in the repo. Asserts:
  1. The `slow:` job in `.github/workflows/ci.yml` is uncommented.
  2. Its `if:` predicate matches the canonical `github.event_name == 'pull_request'` shape.
  3. `supabase start` health-check retry is wired (the codified PR-26 pattern, comparable against a checksum of the template's commented reference).
  4. Branch protection contexts include `slow` (via `gh api repos/{owner}/{repo}/branches/main/protection` query).
  5. The slow job's test glob actually matches at least one staged or repo-resident integration test file (catches "uncommented slow job that runs zero tests" silent regression).
  6. The skip-on-docs-only filter is wired — `changes:` setup-job exists, declares a `runtime` output, and the `slow:` job's `needs:` + `if:` reference it. (Shipped via #29; see `kit/docs/guide/conventions.md § Slow-Job Lifecycle § Skip-on-docs-only filter`.)
     Block-on-failure with a clear "uncomment + add to branch protection" remediation message.
- **Convention doc** in `guide/conventions.md § Slow-Job Lifecycle`: documents the Phase 1c / 1g threshold, the uncommenting checklist, and the cross-link to branch protection.
- **Template improvement**: convert the commented `slow:` block in `/devshop/template/.github/workflows/ci.yml` to a separate `template/.github/workflows/ci-slow.yml.template` file that `/ak-new-project § Step 1c` (or wherever the integration-test setup lives) renames into place when the threshold is crossed. Cleaner than uncommenting, and the rename itself is a structural signal the pre-ship gate can detect.

**Why v0 — blocks next-project adoption:**

Every devshop project that adopts integration tests or E2E will hit this lifecycle question. Without enforcement: (a) the slow job lives commented out indefinitely while integration tests run only locally, masking environment-specific failures, (b) branch protection drifts from CI reality, letting PRs merge without the slow check actually gating, (c) the lalista-codified edge-runtime retry pattern doesn't propagate, so each project re-invents it after their own PR-26-style incident.

**Trigger:**

- Lalista is the prior art — its slow job is already uncommented and includes the retry pattern. The convention extracts that shape into the template + adds the pre-ship gate.
- Second project crosses Phase 1c / 1g without this in place → slow-job uncommenting becomes operator-memory and the lifecycle gap reproduces

**Cross-ref:**

- `/devshop/template/.github/workflows/ci.yml:75-113` — the commented-out slow-job stub
- `/devshop/.claude/skills/ak-new-project/SKILL.md:967-989` — the current Step 24 deferral language
- `lalista/.github/workflows/ci.yml § slow:` — the live shape this convention codifies (especially the edge-runtime health-check retry)
- `### Migration sequencing safety nets for the Vercel-preview window` above — adjacent CI/migration territory; both are about making CI behavior structural rather than operator-maintained

**Cost/risk:**

- Implementation: ~3–5 focused hours (`.yml.template` extraction + `/ak-new-project` Step 1c edit + `/ak-pre-ship` new gate + branch-protection check + conventions doc)
- Risk: low — all changes are CI/template surface, no prod data path
- Benefit: the slow job becomes a structural gate that every integration-test-shipping project gets correctly, with the lalista-PR-26 hard-won retry pattern propagated by default rather than re-discovered per project

---

### Security-posture cleanup: CI/prod credential separation + URL guard + classification

Audit of `/ak-new-project`'s credential surface (2026-04-25, after the auto-deploy-backend ship) surfaced four issues that compound:

1. **Real duplication**: `SUPABASE_PROJECT_REF` is the subdomain slice of `SUPABASE_URL` (the URL is `https://<ref>.supabase.co`). We added it as a GH Variable when the deploy workflows landed; it can be derived inline. Single source of truth = `SUPABASE_URL`. Eliminate the Variable.

2. **Public values stored as Secrets**: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `NEXT_PUBLIC_POSTHOG_KEY` are public by design — baked into the front-end JS bundle, visible to every browser. Storing as GH Secrets is symmetric with the rest but technically a misclassification. Doesn't leak (Secrets and Variables share the same UI) but confuses readers about what's actually sensitive. Move to Variables.

3. **Real security risk: `SUPABASE_SERVICE_ROLE_KEY` ambiguity**. The skill says `SUPABASE_SERVICE_ROLE_KEY=<secret-key>` without specifying which project. A reader will paste their **prod** service-role key — full DB admin access via REST, no RLS. If it leaks (CI logs, container image, misconfigured workflow), prod is **totally compromised**. Lalista's PR 18 D8 + D22 already worked around this (CI's `SUPABASE_URL` rotated to local stack `http://127.0.0.1:54321`; CI's service-role key is the local stack's published default JWT, not sensitive); plus a runtime URL guard `assertNotProdUrlInTestEnv` that throws if test-env code ever instantiates a Supabase client pointing at prod. The template + skill need to ship this discipline by default.

4. **Documentation gaps**: each credential has "where to find it" but no blast-radius callout, no CI-vs-prod separation guidance, no rotation cadence, no explanation of why some are stored as Secrets vs Variables.

**Shape of the fix** (5 tracks; do them as one coordinated change because they cross-reference each other):

**Track A — Eliminate `SUPABASE_PROJECT_REF`**:

- `template/.github/workflows/deploy-migrations.yml` + `deploy-functions.yml`: replace `--project-ref ${{ vars.SUPABASE_PROJECT_REF }}` with a sed-derive from `SUPABASE_PROD_URL`:
  ```bash
  PROJECT_REF=$(echo "$SUPABASE_PROD_URL" | sed -E 's|https://([^.]+)\.supabase\.co|\1|')
  supabase link --project-ref "$PROJECT_REF"
  ```
- `/ak-new-project` Step 5 Variables: drop `SUPABASE_PROJECT_REF`; add `SUPABASE_PROD_URL` instead (this is the prod URL the deploy workflows target — distinct from CI's `SUPABASE_URL` which points at local stack).
- Lalista mirrors the same change (its workflows also derive ref from `SUPABASE_PROD_URL`).

**Track B — Reclassify public values + add CI-vs-prod naming distinction**:

- `/ak-new-project` Step 5 reorganized:
  - **Variables tab** (public):
    - `SUPABASE_URL` = local stack URL `http://127.0.0.1:54321` (used by CI fast/slow jobs against `supabase start`)
    - `SUPABASE_ANON_KEY` = local stack's published default anon JWT
    - `SUPABASE_SERVICE_ROLE_KEY` = local stack's published default service-role JWT (still admin, but on a sandboxed local instance — not prod)
    - `SUPABASE_PROD_URL` = real prod URL (used by deploy-migrations + deploy-functions only)
    - `NEXT_PUBLIC_POSTHOG_KEY` = PostHog key (public via NEXT*PUBLIC* convention)
  - **Secrets tab** (genuinely sensitive):
    - `SUPABASE_DB_PASSWORD` = prod DB password (used by deploy-migrations)
    - `SUPABASE_ACCESS_TOKEN` = account-wide Supabase token (used by both deploy workflows)
    - `ANTHROPIC_API_KEY_QA` = if edge functions call Claude (used by slow-job; re-exported as `ANTHROPIC_API_KEY` inside the test step's env block)
    - `ANTHROPIC_API_KEY_PROD` = if edge functions call Claude in prod (pushed by `deploy-functions.yml` to the prod Supabase project's edge-function secrets as `ANTHROPIC_API_KEY`; never on local disk)
    - `SENTRY_DSN` + `SENTRY_AUTH_TOKEN`
    - `VERCEL_TOKEN`
- Vercel env (separate surface from GH) keeps prod values: `NEXT_PUBLIC_SUPABASE_URL` = prod, `NEXT_PUBLIC_SUPABASE_ANON_KEY` = prod anon. Skill should explicitly note Vercel and GH are different env surfaces with different values.

**Track C — Local-stack defaults documented in skill**:

- `/ak-new-project` Step 5 Variables sub-section gains the **literal values** for local-stack defaults:
  - `SUPABASE_URL` value: `http://127.0.0.1:54321`
  - `SUPABASE_ANON_KEY` value: the published JWT (currently `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9...` — implementer should source the current published value from `supabase start` output or Supabase docs)
  - `SUPABASE_SERVICE_ROLE_KEY` value: same shape, role: service_role
- Note that these are public hardcoded values across every Supabase local-stack install, so no per-project copying from `.env` is needed for these three.

**Track D — Ship the URL guard helper in the template**:

- New file `template/packages/core/src/supabase.ts` (or similar — match the template's existing structure) exporting `assertNotProdUrlInTestEnv` per lalista's PR 18 D22 implementation.
- Helper logic: when `process.env.NODE_ENV === 'test'` AND the URL passed to `createClient` matches a prod-shaped pattern (`*.supabase.co` and NOT the configured project's CI-allowed values), throw with a clear message.
- Tests for the helper (mirror lalista's 5 unit tests in `packages/core/src/supabase.test.ts`).
- Wire into the template's `createClient` call sites so it fires on every client instantiation in test env.

**Track E — Add § Security Posture to `/ak-new-project`**:

New section after Step 5 (or as part of Step 5) with:

- **Blast-radius table** per credential — what an attacker can do if it leaks:

  | Credential                                    | Blast radius if leaked                                                                                       |
  | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
  | `SUPABASE_DB_PASSWORD`                        | Direct DB connection (no RLS); read/write any table                                                          |
  | `SUPABASE_ACCESS_TOKEN`                       | Account-wide: all projects on this Supabase account, manage settings, drop projects                          |
  | `ANTHROPIC_API_KEY_QA`                        | Spend rate-limit on the CI/local-dev key only — cannot affect prod billing or rate limits                    |
  | `ANTHROPIC_API_KEY_PROD`                      | Spend rate-limit on the prod-traffic key only — cannot pollute CI rate limits; rotate same-day               |
  | `SENTRY_AUTH_TOKEN`                           | Upload sourcemaps, manage org                                                                                |
  | `VERCEL_TOKEN`                                | Deploy to any of your Vercel projects                                                                        |
  | `SUPABASE_SERVICE_ROLE_KEY` (prod, NOT in CI) | Full DB admin via REST; no RLS — if it gets in CI accidentally, that's the highest-blast-radius failure mode |
  | Local-stack defaults (Variables)              | None — published constants                                                                                   |

- **CI-vs-prod credential separation** — explicit rule: CI never holds prod Supabase credentials except `SUPABASE_PROD_URL` (used only by deploy workflows), `SUPABASE_DB_PASSWORD`, `SUPABASE_ACCESS_TOKEN`. Everything else CI uses is the local-stack default.

- **Rotation cadence**: rotate `SUPABASE_ACCESS_TOKEN` quarterly (account-wide blast radius); `SUPABASE_DB_PASSWORD` after any team-member departure or suspected compromise; sourcemaps tokens annually.

- **URL guard reminder**: the structural defense (assertNotProdUrlInTestEnv) is in the template by default — Track D — and projects should keep it active.

**Track F — Cleanup step in `/ak-new-project` for upgrading existing projects**:

For projects that already went through the OLD `/ak-new-project` flow (lalista is one), add a "Migration to new credential layout" step OR a one-off cleanup section in the skill:

- List of GH Secrets to delete that no longer apply (e.g., legacy `SUPABASE_PROJECT_REF` Variable if previously set)
- List of values to add (e.g., `SUPABASE_PROD_URL` Variable if not present)
- List of Secrets to convert to Variables
- Rotation prompt for any potentially-mixed credentials

This step is `[HUMAN]` — Claude can list what to do but can't manage GH Secrets via the devcontainer PAT.

**Doc propagation** (after Tracks A–E land):

- `OVERVIEW.md` — workspace-layout file map gains the URL guard helper file at `packages/core/src/supabase.ts` (already there for lalista; needs template parity)
- `kit/docs/guide/conventions.md` — § Deploy Boundaries already updated for auto-deploy; gains a callout about CI-vs-prod credential separation as the structural enforcement of the boundary
- `kit/docs/guide/security.md` — gains a § "CI credential isolation" subsection summarizing the URL guard + local-stack-defaults pattern
- `kit/docs/guide/ops.md` § CI/CD — already updated; verify the prod-URL-vs-local-URL distinction is noted
- `CLAUDE.md` § Known Footguns — gains an entry about the prod-service-role-in-CI risk + URL guard remediation

**Project-side changes (lalista — first adopter)**:

After the devshop side lands on a feature branch (NOT ff-merged yet — per the new "hold ff-merge until project validates" convention from CLAUDE.md § Devshop shipping flow):

1. **Workflow files**: update `.github/workflows/deploy-migrations.yml` + `deploy-functions.yml` to derive ref from `SUPABASE_PROD_URL` instead of `vars.SUPABASE_PROJECT_REF`. Drop the `SUPABASE_PROJECT_REF` Variable.
2. **GH Variables additions**:
   - Add `SUPABASE_PROD_URL` = `https://nzfdfjctpotjyuxdfcpw.supabase.co`
3. **GH Secrets → Variables migrations** (delete from Secrets after confirming Variables tab has them):
   - `SUPABASE_URL` (value already = local stack URL per D8) → Variables
   - `SUPABASE_ANON_KEY` (value already = local stack default) → Variables
   - `SUPABASE_SERVICE_ROLE_KEY` (value already = local stack default) → Variables
   - `NEXT_PUBLIC_POSTHOG_KEY` → Variables
4. **GH Secrets to keep as Secrets**: `SUPABASE_DB_PASSWORD`, `SUPABASE_ACCESS_TOKEN`, `ANTHROPIC_API_KEY_QA`, `ANTHROPIC_API_KEY_PROD`, `SENTRY_DSN`, `SENTRY_AUTH_TOKEN`, `VERCEL_TOKEN`.
5. **GH Variable to delete**: `SUPABASE_PROJECT_REF` (added today; superseded by `SUPABASE_PROD_URL` + sed-derive).
6. **URL guard already present**: lalista already has D22's `assertNotProdUrlInTestEnv` in `packages/core/src/supabase.ts` — verify it's wired into all `createClient` call sites.
7. **CI verification**: re-run slow-job CI on `feat/auto-deploy-backend` to confirm both deploy workflows still run green after the parameterization change.
8. **Once CI green on lalista, ff-merge devshop-side feature branch to devshop main**.

**Why v0**:

- Track A: trivial debt that compounds with every future project — fix while it's fresh.
- Track B–E: closes a real security gap. The prod-service-role-in-CI footgun is the highest-blast-radius failure mode in the current `/ak-new-project` flow. Every project scaffolded today has it; fixing now means the second project starts in the secure-by-default state.
- Track F: existing projects need a migration path; without it, the cleanup is ambiguous.

**Trigger**:

- Lalista PR 18 retro (2026-04-25) surfaced the audit — concrete case study + first adopter ready.
- Coordinated devshop+project change: implement on devshop feature branch, validate on lalista, ff-merge devshop after lalista CI green (per the convention from CLAUDE.md § Devshop shipping flow step 2 added 2026-04-25).

**Cross-ref**:

- Lalista PR 18 D8 (CI URL/anon rotation to local stack) — already shipped, this entry generalizes the pattern to template
- Lalista PR 18 D22 (`assertNotProdUrlInTestEnv` URL guard) — already shipped, this entry generalizes to template
- `kit/docs/guide/conventions.md` § Deploy Boundaries — context for the parallel-deploy model
- The pre-commit test-presence hook for project repos (sibling convention propagation pattern) shipped 2026-04-28 as `kit/scripts/commit-hooks/check-tests-coverage-project.sh`; see `kit/docs/guide/hooks.md` for the current contract

**Cost/risk**:

- Implementation: ~3-4 focused hours (template helper + tests, skill rewrite of Step 4/5, doc propagation across 5+ files, lalista mirror, CI re-run + verification). Adversarial review will require 2-3 doc enumeration cycles per commit; budget for that.
- Risk during rollout: lalista's deploy workflows briefly need `SUPABASE_PROD_URL` Variable BEFORE the workflow file change merges (or the parameter substitution will fail). Set the Variable first; merge second. Same for any future project adopting from template.
- Benefit: closes the prod-service-role-in-CI risk by default; eliminates the `SUPABASE_PROJECT_REF` redundancy; documents what's actually sensitive vs symmetric-but-public; provides migration recipe for existing projects.

---

### `/ak-go-live` post-merge prod-config sync (Arm B — automation core)

**Status:** Arm A (pre-flight surface) shipped 2026-05-10 via the devshop `feat/ak-go-live-arm-a-preflight` branch — `/ak-go-live` Step 1.8 reads the PR body + latest audit/ready-for-review comments, parses every `[ ]` checkbox grouped by section, annotates `[manual]` / `[deferred]` / `[!]`, and blocks on `## Out-of-band deploy items` only. Arm B (Management API integration that converts most `[manual]` items into `[auto]`) is scoped below and remains pending. The problem statement now narrows to the items Arm A surfaces but doesn't automate: the operator still pastes email templates, still verifies the auth allow-list, and still curls absolute-URL assets by hand.

**Problem.** Even with Arm A's pre-flight surface listing every pending item, the operator still types into the Supabase dashboard for each one. The recurring set:

- **Hosted Supabase email templates** (`[auth.email.template.confirmation]` + `[auth.email.template.recovery]` + `[auth.email.notification.password_changed]` from `supabase/config.toml` only auto-apply to the LOCAL stack; the prod project reads from its own dashboard). The operator logs into supabase.com/dashboard, navigates to Auth → Email Templates, pastes subject + body for each affected template by hand. Easy to forget; trivial to typo.
- **Hosted Supabase auth allow-list** (`additional_redirect_urls`). Local-stack glob patterns from `supabase/config.toml` are dev-only; prod's allow-list is configured separately on the dashboard. When a chapter changes the redirect surface (chapter 1l added `/auth/callback`), the operator verifies or updates the prod allow-list manually.
- **Static asset reachability** (e.g., `lalista-email-logo.png` referenced by absolute prod URL inside email templates). Vercel deploys it, but until verified the email might render with a broken image. A single curl confirms.

**Sibling to /ak-build Phase 5.8 + 5.9 — same family.** 5.8 catches test-coverage drift before merge; 5.9 refreshes visual evidence before merge; Arm B closes the gap AFTER merge so `/ak-go-live`'s output is a fully-deployed-and-verified state without manual paste-and-curl steps.

**Shape of the automation core.**

- **Email templates push** via Supabase Management API (`PATCH /v1/projects/<ref>/config/auth` with `mailer_subjects_*` and `mailer_templates_*` fields). Fires when the merged PR's diff touches `supabase/templates/**` or `[auth.email.template.*]` / `[auth.email.notification.*]` in `supabase/config.toml`. Reads the local files, posts the Management API call. Requires a Supabase Personal Access Token — new credential surface, separate from the service-role key used for ad-hoc admin queries.
- **Auth allow-list verification** via the same Management API (`GET /v1/projects/<ref>/config/auth`). Reads the prod allow-list, compares against the GLOB patterns in local `supabase/config.toml`'s `additional_redirect_urls` block (substituting the prod URL for `localhost` / `127.0.0.1`), warns or auto-updates depending on policy. The "auto-update" path requires user confirmation per the auto-mode-not-license-to-destroy rule — same shape as `/ak-go-live`'s existing rollback path (no auto-rollback because human judgment).
- **Static asset reachability check** via `curl -fsS https://<prod-domain>/<asset>` after Vercel reports deploy-ready. Specific to assets referenced by absolute URLs in places Vercel can't serve (email templates, third-party redirects). Reads which assets to check from a new `[ak-go-live.verify-assets]` block in the project's CLAUDE.md or `.devshop-deploy.toml` — explicit allow-list, not auto-discovery.

**Persistence**: `/ak-go-live` writes a per-run report to `specs/<feature>/go-live.md` with what ran, what passed/failed, and what's still pending. Reviewer of a future incident `git log`s `specs/*/go-live.md` to reconstruct what the deploy did.

**New credentials surface**: the Supabase Personal Access Token (`SUPABASE_ACCESS_TOKEN` env var convention) needs to live somewhere the skill reads at runtime. Two paths: (a) GH Secret + workflow-only access (skill reads via `gh secret get`); (b) operator's local `.devcontainer/.env` for local invocations + a CI run for merged-PR triggers. Recommend (a): `/ak-go-live` IS a deploy action and deploy actions belong in CI; locally it's "show me what would happen" mode without the actual prod-write authority. Same shape as `ANTHROPIC_API_KEY_PROD` today (CLAUDE.md § Anthropic API key split).

**Why this beats the obvious alternatives.**

- **"Keep pasting templates"** — Arm A's pre-flight surface already closes ~70% of forget-or-typo risk by listing the items unmissably; Arm B closes the rest by removing the manual step entirely.
- **"Use a generic `supabase config push` flow"** — the Supabase CLI doesn't have a clean equivalent for hosted projects (it's local-stack-focused). The Management API is the right shape.
- **"Roll into /ak-build Phase 7 instead of /ak-go-live"** — Phase 7 fires before the merge happens; the prod-config sync needs to happen AFTER. /ak-go-live is the correct skill.

**Why v0 — blocks next-project adoption.**

Every devshop project shipping features that touch email templates / auth allow-list / absolute-URL-referenced assets pays the manual-paste tax. Once a second project shows up, both projects pay until this lands. Closing it before that second project arrives means future projects inherit the protection.

**Trigger:**

- A second devshop project starts using `/ak-go-live` and hits the same paste-and-curl tax.
- OR: lalista chapter touches email templates / allow-list / absolute-URL assets again and the user asks to close the loop now that Arm A is shipped.

**Cross-ref:**

- `/devshop/.claude/skills/ak-go-live/SKILL.md § Step 1.8` — Arm A's surface; Arm B converts `[manual]` items it lists into `[auto]`.
- `/devshop/.claude/skills/ak-build/SKILL.md § Phase 6 § audit-comment template` — names the same items at a different lifecycle moment (just-shipped, not just-going-live); Arm B reads from this same convention.

**Cost/risk:**

- Implementation: ~6–10 hours — Management API integration (3 endpoints), credential plumbing, error handling, the per-run `go-live.md` report shape, bats tests for the auto-update confirmation flow.
- New-credential risk: the Supabase Personal Access Token has broad scope (project config write); leaking it = ability to misconfigure auth on the prod project. Same blast radius as today's `ANTHROPIC_API_KEY_PROD` (per the existing split convention) — manageable with the same CI-only + 1Password discipline.
- False-positive risk on the allow-list compare: `additional_redirect_urls` glob pattern matching is fuzzy; the safer default is "warn, don't auto-update" until the convention is exercised on a few real chapters and the failure modes are known.
- Pipeline-time risk: ~10–30 seconds for the Management API round-trips plus the curl check. Negligible.

---

### Generalize lalista PR #43's E2E + Supabase test-infra lessons to template + conventions

**Problem.** Four discrete testing-infrastructure lessons surfaced during chapter 1l's CI fix-loop are inline-documented in lalista's own files (forgot-password helper, auth-edge-cases spec) but not extracted to devshop. Every future devshop project that ships a Supabase auth flow + Playwright E2Es will rediscover all four from first principles. They cost lalista 9 CI fix-loop iterations + ~2 hours of debugging across two sessions; codifying them upstream cuts that to zero on the next project.

**The four lessons.** Each is reproducibly generic (not lalista-specific):

1. **Mailpit replaced Inbucket but Supabase CLI keeps the legacy `INBUCKET_URL` env var name.** Any devshop project using Supabase local stack with E2E helpers that need to read the mail relay hits this on Supabase CLI ≥ 2.x. The wire-level API differs (mailpit uses `/api/v1/search?query=to:<addr>`; inbucket used `/api/v1/mailbox/<addr>`). Inline doc lives at `lalista/apps/web/e2e/helpers/inbucket.ts:1-22`.

2. **Supabase's `{{ .ConfirmationURL }}` template variable renders with a bare `/verify` path on the auth host (port 54321) instead of the Kong-prefixed `/auth/v1/verify`.** Browsers follow the bare URL fine because they handle Kong's redirects, but `page.goto(link)` in Playwright 404s with "no Route matched." Affects any project that drives Supabase recovery/confirmation links via Playwright. Inline doc + the `rewriteBareVerify` function lives at `lalista/apps/web/e2e/helpers/inbucket.ts:108-128`.

3. **WebKit React-hydration race on controlled inputs.** `page.locator('#input').fill(value)` can resolve before React's state syncs back to the DOM `value` attribute on a freshly hydrated controlled input. The result: `fill` reports "value set", the next interaction observes the field as empty, the form submits with missing data. Reproduced identically across three CI runs in PR #43 (25258858879 / 25259626169 / 25260400981) before the fix landed. Robust pattern: `click + pressSequentially(value, { delay: 10 }) + expect().toHaveValue(value)` — real keystrokes give React time to settle, the value-equality assert auto-retries. Affects any Playwright + React project, not Supabase-specific. Inline doc at `lalista/apps/web/e2e/forgot-password.spec.ts:73-89`.

4. **Two-shape signup behavior depending on `[auth.email].enable_confirmations`.** When TRUE (prod's typical posture): Supabase returns `{ user: { identities: [] }, session: null }` for an existing-account second-signup — the no-enumeration shape. The app's /sign-up page can branch into AwaitingConfirmationCard, indistinguishable from a fresh signup. When FALSE (auto-confirm; CI's typical posture): Supabase returns an explicit `User already registered` error and the app's friendly-error mapping renders "already registered, try signing in instead." E2E tests on local stack (auto-confirm) exercise the visible-error path; unit tests should mock the prod shape to pin the no-enumeration parity. Inline doc at `lalista/apps/web/e2e/auth-edge-cases.spec.ts:155-174`.

**Shape of the convention.**

- **Lessons 1 + 2 → template helper file.** Ship `template/apps/web/e2e/helpers/inbucket.ts` (or whatever the canonical mail-relay helper is named for new projects — "inbucket.ts" preserves Supabase's env-var name; fine to keep) as part of the standard E2E scaffold. New projects scaffolding from the template inherit a working helper on day 1. The file's own docstring explains why the name is misleading + the bare-/verify rewrite. Pure code; no convention prose needed beyond what's in the file.

- **Lesson 3 → convention + skill amendment.** Convention prose lives at `kit/docs/guide/conventions.md § Playwright + controlled inputs on WebKit`. The rule: for forms with controlled inputs whose values are read at submit time (login, password reset, anything with `<input value={state} onChange=...>`), prefer `pressSequentially` over `fill` when targeting WebKit. One-line callout in `/ak-pre-ship` Gate 9 (QA walks) so it fires at the right moment.

- **Lesson 4 → convention + (optionally) template scaffold.** Convention prose at `kit/docs/guide/conventions.md § Supabase auth E2E patterns` covering: how to test the no-enumeration shape (mock at the unit level with `identities: []` + null session), how to test the auto-confirm shape (E2E against local stack), why the test-layer split is correct. If template ships any auth E2E examples, mirror this dual-layer pattern.

- **Cross-link from `kit/ROADMAP.md § Auth UX conventions`** (the existing v0 entry that extracts `AwaitingConfirmationCard` + `friendlyAuthError`). That entry is about UX components; this one is about test infrastructure. They pair naturally — UX work without test-infra produces flaky lessons-by-rediscovery loops.

- **Implementation order:** ship the template helper file FIRST (lessons 1 + 2 are pure code, easiest to verify), then the conventions (lessons 3 + 4 are prose, easier when there's a template helper to reference). One PR per lesson keeps the diff small; or one PR for the helper file + one for the conventions.

**Why this beats the obvious alternatives.**

- **"Just leave it inline in lalista"** — works for lalista (we wrote it; we'll find it), fails for the next project (they'll rediscover all 4 from first principles, costing ~2 hours each). The whole point of the template + conventions is to compound learning across projects.
- **"Wait for a second project to surface the gap"** — the Auth UX conventions entry already has this exact sequencing (extract after lalista soaks). Lessons 1-3 are technical and don't benefit from soak; the helper either works or doesn't. Lesson 4 might benefit from soak (the no-enumeration UX trade-off has UI implications worth seeing in production), but the convention prose can ship now and refine later.

**Why v0 — blocks next-project adoption.**

A second project shipping Supabase auth without these four lessons in template + conventions will hit them. Lessons 1 + 2 cost ~30 minutes each to debug from scratch (you need the trace.zip to see the URL form). Lesson 3 cost lalista a 9-iteration CI fix-loop because the symptom (test fails on WebKit, passes on Chromium) reads as flake. Lesson 4 is design-trade-off shaped (you need to KNOW about the two shapes to test correctly); without the convention, projects ship the wrong test layer and miss bugs.

**Trigger:**

- Lalista PR #43 just landed (2026-05-05); lessons are fresh. Ship the template helper this week.
- Conventions can be drafted alongside; pair-review with a future devshop project's auth flow as the validation pass.

**Cross-ref:**

- `lalista PR #43` (chapter 1l, merged 2026-05-05). The four files where the lessons currently live.
- `kit/ROADMAP.md § Auth UX conventions` — UX-side companion entry; pair these two to ship.
- `/ak-build` Phase 5.8 (shipped 2026-05-05) — the post-pre-ship audit re-runs `/ak-test-review` over the polish range; that's the gate where the "did you remember to use pressSequentially?" question fires (the WebKit convention below should be inlined into `/ak-test-review` so the audit catches violations).
- `kit/scripts/commit-hooks/check-test-coverage-project.sh` — the Layer-1 test-presence hook; the Layer-2 conventions ride on top.

**Cost/risk.**

- Template helper file: ~1 hour — copy lalista's file verbatim, generalize the comments, drop in `template/apps/web/e2e/helpers/`. Mirror in `template/apps/web/e2e/sign-up.spec.ts` + `forgot-password.spec.ts` skeletons that consume it.
- WebKit conventions: ~1 hour — prose in `kit/docs/guide/conventions.md` + the one-line callout in `/ak-pre-ship` SKILL.md.
- Two-shape signup convention: ~1 hour — prose + a small worked example in conventions.md.
- Total: ~3 hours for all four lessons. False-positive risk: zero (these are well-validated patterns from a 9-iteration debug loop).

---

### Auth UX conventions — shared error-surface + state patterns

Projects using Supabase auth keep re-solving the same UX gaps because there's no shared convention. Lalista surfaced two that every hosted-Supabase auth flow hits:

1. **Unconfirmed-signup silent bounce** — `mailer_autoconfirm: false` (default) makes a successful signup return no session. If the client immediately routes to an authed area, middleware redirects the unconfirmed user back to `/sign-in` with no feedback. Looks broken.
2. **Raw Supabase error strings leaking to users** — messages like "Invalid login credentials" / "Email rate limit exceeded" / "User already registered" are developer-facing. Users read them as "what does this mean?"

Both were fixed ad-hoc in lalista (commit `31b5637` on `feature/auth`: new `awaitingConfirmation` state + `friendlyAuthError()` helper). Every next project will hit the same gaps.

**Shape of the convention (not final):**

- **Package**: a thin `@devshop-template/auth-ux` helper module (or inline pattern in the template's sign-in page) providing:
  - `AwaitingConfirmationCard({ email, onBack })` React component — standardized "Check your email" UI
  - `friendlyAuthError(message: string): string` — normalizes Supabase error strings to user copy. Exhaustive coverage of the ~6 common cases (`invalid_credentials`, `email_not_confirmed`, `email rate limit exceeded`, `user already registered`, `over_email_send_rate_limit`, `signup disabled`). Unmapped messages pass through unchanged (safe default).
- **Convention doc** in `guide/conventions.md § Auth UX Conventions` with:
  - When to show awaiting-confirmation vs. sign-in-error UI
  - Error-copy style guide (user-action-oriented, not dev-state-oriented)
  - Email enumeration vs. UX-clarity trade-offs (projects pick a stance; document which one they picked)
- **Template sign-in page**: the lalista-auth-feature scaffold (or its successor) includes the pattern out-of-the-box so projects don't rediscover it.
- **Test helpers**: a standardized `e2e/helpers/auth-ux.ts` that exercises the awaiting-confirmation path, rate-limit path, wrong-password path — pairs with the "user-state matrix" expansion to Step 2's Fix C (QA walks must exercise more than the admin-API happy path).

**Password-reset sub-pattern (required for the full story):**

Surfaced 2026-04-20 while testing PR #10 on the Vercel preview. Supabase's dashboard "Send password recovery" email links to `<site_url>/#access_token=...&type=recovery`; if the project has no callback route to land on, the link hangs. Every Supabase project needs this plumbing.

- **`PasswordResetCard` component**: email input → `supabase.auth.resetPasswordForEmail(email, { redirectTo: <callback URL> })` → success state ("Check your email for a reset link"). Lives in the same `@devshop-template/auth-ux` module as `AwaitingConfirmationCard`.
- **`/auth/callback` route** (RSC + Route Handler hybrid): reads `code` query param, calls `supabase.auth.exchangeCodeForSession(code)` server-side, then redirects based on `type` (`recovery` → `/reset-password`; `email_change` → `/settings`; default → `/`). Sets the session cookie so subsequent requests are authed.
- **`/reset-password` route**: form to set a new password (validated against `password_min_length`). Calls `supabase.auth.updateUser({ password })` on submit — works because the callback already set a session. On success, push to `/` (or `/onboarding` if the user has no household).
- **Required Supabase config** (must be set at `/ak-new-project` time — see the `/ak-new-project` Phase B auth-hardening step):
  - `site_url` = production URL (e.g., `https://app.vercel.app`) — **NOT** `localhost:3000` (the free-tier default). Recovery emails embed this; a wrong value makes every reset link hang.
  - `uri_allow_list` includes: production URL, Vercel preview wildcard (`https://*-<team>.vercel.app/**`), and `http://localhost:3000/**` for dev. Without this, `redirectTo` values get rejected.

**Why v0 — blocks next-project adoption:**

Combined with the auth-hardening step (password_min_length: 8, landed in v1.11.0) and the invite-code signup (v1 entry below), this completes the "serious project auth out of the box" story. Waiting means every project gets an ad-hoc implementation. Lalista is example #1 with the `awaitingConfirmation` state and `friendlyAuthError()` function; lalista has a `TODOS.md § auth-ux-refactor-to-adopt` entry standing by to adopt the helper once it ships, which also verifies the helper works in practice.

**Trigger:**

- Second project adopts the devshop and hits the same silent-bounce bug (almost guaranteed)
- OR: lalista's implementation gets iterated on twice — the 3rd refinement is the signal to factor up
- OR: lalista clears its `auth-ux-refactor-to-adopt` verification debt as soon as the helper ships (current plan)

**Cross-ref:**

- Lalista commits `31b5637` (fix) and sign-in page.tsx / page.test.tsx — the concrete prior art
- Lalista `TODOS.md § v0 § auth-ux-refactor-to-adopt` — the refactor-to-adopt TODO that verifies the helper when it ships
- The `/ak-pre-ship` Gate 9 user-state matrix (landed in devshop v1.11.0) — the QA-side pair of this UX-side convention

---

### Latency feedback framework — 4-tier decision rule + primitives

Projects keep re-solving the same UX gap: how snappy to make a button / a route nav / an optimistic mutation. Defaults skew either too eager (spinner everywhere, including <250ms ops where it's noise) or too lazy (no feedback, user double-taps). Lalista chapter 1m (`feat/app-snappiness`, PR #49, shipped 2026-05-07) co-developed a 4-tier framework with the user that matches the affordance to the operation's actual latency. Every next project with interactive UI will hit the same decision tree.

**The framework** (lalista's `specs/app-snappiness/spec.md § D1` is canonical until this lifts):

- **5-tier table** (A1 / A2 / B / C / D) — pick by latency + whether we have local state to commit optimistically + whether failure is self-explanatory in context.
- **Decision rule** for picking a tier when adding a new interactive surface.
- **Primitives** (live in `lalista/packages/ui/`, ready to lift):
  - `useSubmitFeedback` — Tier B's 250ms-threshold spinner timer + cleanup state machine.
  - `SubmitButton` — Tier B affordance built on `useSubmitFeedback` + `Button`.
  - `LoadingArea` — Tier C placeholder (soft `animate-pulse` on `bg-muted/40`).
  - `useOptimisticMutation` — Tier A1/A2 hook with `failureMode: 'rollback' | 'banner'` discriminated union, retry sequence with budget check, banner state with retry/undo/dismiss callbacks.
- **Tokens**: `FEEDBACK_THRESHOLD_MS = 250`, `RETRY_BUDGET_MS = 15000`, `RETRY_BACKOFF_MS = [1000, 3000, 7000]`.
- **Load-bearing implementation detail (preserve verbatim if you fork)**: Tier A's `useOptimisticMutation` rollback uses `queueMicrotask` so the optimistic frame paints BEFORE the rollback's setState. React 19's auto-batching otherwise elides the visible "row appeared then disappeared" frame and the user sees no feedback at all. Same pattern lalista's `ListClient.handleAddResponse` realtime-merge race uses. Test coverage in `useOptimisticMutation.test.ts`.

**Implementation surface:**

- `kit/docs/guide/latency-feedback.md` (new) — full framework prose: 5 tiers, decision rule, retry-budget shape, queueMicrotask gotcha, worked examples (generic surfaces, not lalista-specific). Becomes the ground truth.
- `template/CLAUDE.md` — short pointer: "when adding a surface with feedback needs, see `kit/docs/guide/latency-feedback.md`." So new projects inherit by default.
- `.claude/skills/devshop/spec/SKILL.md` — `/ak-spec` consults the guide when the spec involves interactive UI or async ops; spec author produces a project-specific surface tier mapping table as part of `## Decisions` (same shape as PR #49's spec § D1, just systematic).
- **Primitives extraction** (separate PR after the framework doc lands and lalista soaks): lift `useSubmitFeedback` / `SubmitButton` / `LoadingArea` / `useOptimisticMutation` from `lalista/packages/ui/` to a `@devshop-template/ui` package. Lalista refactors to import from the package, deletes the inline copies.

**Why v0 — blocks next-project adoption:**

Same playbook as Auth UX conventions above. Every project with interactive UI hits the same decision tree; without the convention, every project re-derives ad-hoc spinners, miscalibrates the 250ms threshold, or skips optimistic UI entirely because the rollback timing is non-obvious (the React 19 auto-batching gotcha is the load-bearing detail nobody discovers until they ship it). Factoring up now avoids each project re-inventing the wheel.

**Trigger:**

- 2-4 weeks after lalista chapter 1m ships (2026-05-07) — gives the patterns time to surface real-world quirks before extraction. Same "ship inline → soak → extract" sequencing chapter 1l followed.
- OR: a second project adopts the devshop and the operator pushes back on "no convention for tap feedback" (almost guaranteed once anyone ships interactive UI).
- OR: lalista clears its `PRODUCT-ROADMAP.md § v1 § Devshop extraction of validated UX patterns` row by adopting the lifted primitives — the natural verification step.

**Cross-ref:**

- `lalista/specs/app-snappiness/spec.md § D1` — canonical framework + decision rule until this lift makes the devshop guide canonical. Source for the 5-tier table.
- `lalista/CLAUDE.md § Latency feedback tiers` — currently carries the 5-tier table, decision rule, and a lalista-specific surface mapping. After this lifts, lalista CLAUDE.md trims to just the surface mapping with a pointer to `kit/docs/guide/latency-feedback.md`.
- `lalista/DESIGN.md § Motion + feedback` — token values; lifts alongside the components.
- `lalista/PRODUCT-ROADMAP.md § v1 § Devshop extraction of validated UX patterns` (line 347) — the soak-reminder counterpart on the lalista side.
- `lalista/packages/ui/src/{useSubmitFeedback,SubmitButton,LoadingArea,useOptimisticMutation}.{ts,tsx}` — concrete prior art ready to lift.

**Cost/risk:**

- Implementation: ~30 min for the guide doc + ~15 min for the `/ak-spec` SKILL amendment + ~1-2h for the primitives extraction PR (separate, post-soak). Total ~2-3 focused hours across two PRs.
- Risk of premature extraction is the main cost of NOT waiting for the soak; once we've waited, the patterns have already proven themselves on real users. Lalista's CI fix-loop on PR #49 surfaced 4 fix-loop iterations worth of edge cases (overlay-z-index intercept on banner Retry/Undo, React batching defeats observable optimistic frame, schema-drift footguns in test queries) — the doc + primitives codify those lessons so the next project doesn't rediscover them.

[v0, surfaced-by lalista-PR49, 2026-05-07]

---

### PR-B: lalista CLAUDE.md gotcha audit + lift into routing system

Audit lalista's ~25 CLAUDE.md gotchas. For each: classify as (a) generalizable → lift to a routed devshop guide section with a paired routing-row trigger, or (b) project-specific → leave in lalista CLAUDE.md as project-local. Validates the routing system shipped in `feature/context-aware-guideline-routing` (the routing PR; merge SHA filled in when PR-B opens) by exercising it on the canonical gotcha list it was built to absorb.

[v0, follow-on, 2026-05-11]

---

## v1 (after v0 is validated on the first project)

### JIT DB password entry for prod migration deploys via `/ak-go-live`

_Deferred from v0 on 2026-04-27 — no incident forcing it; lalista v0 GA (PR 7 + launch-day seed) ships first._

The just-shipped security-posture cleanup keeps `SUPABASE_DB_PASSWORD` as a GH Secret consumed by `deploy-migrations.yml`. That works but leaves the highest-blast-radius credential (direct Postgres access, bypasses RLS, full DB admin on prod) sitting in CI surface 24/7. Edge function deploys use only `SUPABASE_ACCESS_TOKEN`, so they don't have this concern; the asymmetry between functions and migrations is the lever.

**Shape of the fix** — split auto-deploy by blast radius:

| Surface        | Auto-deploy via GH?                           | Credential surface                                                                         |
| -------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Edge functions | ✅ keep — `deploy-functions.yml`              | Only `SUPABASE_ACCESS_TOKEN`; account-wide blast already in GH Secrets, narrow consumption |
| Migrations     | ❌ remove — operator-driven via `/ak-go-live` | DB password never enters GH; entered just-in-time at deploy moment                         |

**`/ak-go-live` flow change**:

1. After merging the PR, detect if `supabase/migrations/**` changed in the merged commits.
2. If yes, prompt the operator for `SUPABASE_DB_PASSWORD` via one of two paths (operator picks at `/ak-new-project` time + documents in CLAUDE.md):
   - **Path A — password manager CLI** (preferred when available): `op read 'op://Personal/<project>/db_password'` (1Password) / `bw get password '<project> db'` (Bitwarden) / `pass show <project>/db` (pass) / `gpg -d ~/.secrets/<project>-db.gpg` (gpg-encrypted file). Zero prompts; works in non-interactive Bash tool calls.
   - **Path B — `!`-prefix shell escape** (Claude Code session fallback): `/ak-go-live` emits a single `!`-prefixed multi-line block with `read -s -p "DB password: "` + `supabase db push`. The user's CLI has a TTY; `read -s` works; password doesn't enter the transcript because `read -s` doesn't echo and the variable lives in shell state, not stdout. One paste per migration deploy.
3. `/ak-go-live` runs `supabase link --project-ref <derived-from-SUPABASE_PROD_URL> && supabase db push --include-roles` with `SUPABASE_DB_PASSWORD` set inline (env var prefix on the command, never `export`ed; cleared from process state when the command exits).
4. Verify the push succeeded; continue with canary checks. If `supabase/functions/**` also changed, GH Actions' `deploy-functions.yml` already fired in parallel — `/ak-go-live` watches that run for the green check.

**Trade-offs vs the persisted-Secret status quo**:

| Aspect                         | Current (persisted Secret)                               | JIT prompt                                                                                                     |
| ------------------------------ | -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Operator-side friction         | Zero — auto-deploys on merge                             | One paste per migration deploy (Path B) or zero (Path A)                                                       |
| GH Secret exposure window      | Indefinite — Secret sits there 24/7                      | None — DB password never enters GH                                                                             |
| `.devcontainer/.env` exposure  | DB password persisted on disk                            | Password lives only in password manager (Path A) or operator's memory at deploy moment (Path B)                |
| Catches "operator absent" race | Auto-deploys without supervision                         | Requires operator presence (a feature for prod migrations, not a bug; `/ak-go-live` is operator-driven anyway) |
| Failure mode                   | Workflow fails red in GH Actions; operator notices later | `/ak-go-live` reports failure inline; operator addresses immediately                                           |

**Implementation surface**:

Devshop side (`/devshop`):

- Delete `template/.github/workflows/deploy-migrations.yml`. Drop the `[deploy-migrations.yml]` row from any docs that list it.
- Update `/ak-go-live` skill (`.claude/skills/devshop/go-live/SKILL.md`) — add a "detect migration changes + JIT password fetch + local `db push`" phase between merge-complete and canary checks. Reference both Path A (password-manager CLI) and Path B (`!`-prefix), with detection: try Path A's CLI first (e.g. `command -v op`), fall back to Path B's `!`-prefix block if no manager CLI is present.
- Update `/ak-new-project` Step 5 — drop `SUPABASE_DB_PASSWORD` from the GH Secrets list (only `SUPABASE_ACCESS_TOKEN` + `ANTHROPIC_API_KEY_QA` + `ANTHROPIC_API_KEY_PROD` + `SENTRY_*` + `VERCEL_TOKEN` remain as Secrets).
- Update `/ak-new-project` Step 4 — remove `SUPABASE_DB_PASSWORD` from `.devcontainer/.env`. Add a new Step 4 sub-bullet asking the operator which password-manager path they'll use; document the chosen path in CLAUDE.md so `/ak-go-live` knows which to invoke.
- Update `/ak-new-project` § Security Posture — update the blast-radius table row for `SUPABASE_DB_PASSWORD` (now: lives only in password manager + Supabase project; never in GH Secrets / `.devcontainer/.env`).
- Update `/ak-new-project § Migration: existing project to current credential layout` — add a final step "delete `SUPABASE_DB_PASSWORD` GH Secret + `.devcontainer/.env` row; install your password manager CLI in the devcontainer; document the path in CLAUDE.md."
- Update `kit/docs/guide/conventions.md` § Deploy Boundaries — split the migrations row from the functions row in the auto-deploy table; note migrations are operator-driven via `/ak-go-live`.
- Update `kit/docs/guide/security.md` § CI Credential Isolation — add a third structural defense: "DB password is operator-side, entered just-in-time, never persisted in CI or `.env`."

Project side (any project that adopted the cleanup):

- Delete `.github/workflows/deploy-migrations.yml`.
- Update CLAUDE.md gotcha entry to reflect the operator-side migration flow + which password-manager path the operator chose.
- Update PR body's pre-merge actions — drop "Add GH Secret SUPABASE_DB_PASSWORD"; add "Install <password-manager-CLI> in devcontainer + provision the DB password item."
- Optionally rotate the prod DB password at this point — the prior value sat in GH Secrets, so assume it's burned.

**Why v1 (deferred from v0 on 2026-04-27)**:

This is the structural completion of the security-posture cleanup, not a "something is broken" fix. The cleanup closed the prod-service-role-in-CI gap by moving service-role to local-stack defaults; the symmetric move for DB password is to take it out of CI entirely. Without this, the cleanup is "partially structural" — service-role is fully off CI, DB password isn't. Closing the asymmetry is a small skill rewrite + a docs cascade; the cost is low compared to the principal-of-least-privilege payoff.

Demoted to v1 because: (a) lalista v0 GA depends on PR 7 + launch-day seed, neither blocked by this; (b) the existing GH-Secret flow has shipped successfully and there's no incident forcing the JIT move; (c) the docs cascade is cleaner once lalista has actually run a prod migration deploy via the existing flow at least once, so the JIT skill rewrite is informed by live operational experience rather than aspirational design.

**Trigger**:

- Lalista v0 GA ships and the existing auto-deploy migration flow runs at least once on a real prod migration; OR
- A second project adopts the devshop and the operator pushes back on persisting prod DB password in GH Secrets — that's the cue to ship.

**Cross-ref**:

- `kit/ROADMAP.md § Security-posture cleanup` (shipped on `feat/security-posture-cleanup`) — the structural enabler this entry completes.
- `lalista/.github/workflows/deploy-migrations.yml` (5b248d9) — the file to delete project-side.
- `/devshop/.claude/skills/devshop/go-live/SKILL.md` — the skill to extend with the JIT phase.
- 1Password CLI: `op read` docs ([1password.com/downloads/command-line](https://1password.com/downloads/command-line)).
- `kit/docs/guide/security.md § CI Credential Isolation` — the home for the third structural-defense bullet.

**Cost/risk**:

- Implementation: ~2-3 focused hours (skill rewrite + doc cascade across 5 files + project-side mirroring + adversarial reviews × 2-3 cycles).
- Risk during rollout: if the password-manager CLI isn't installed at the moment `/ak-go-live` runs the JIT phase, fall-back to Path B (`!`-prefix) keeps the deploy unblocked — no infrastructure prerequisite.
- Benefit: fully closes the persisted-prod-credential-in-CI risk class; the DB password joins the prod service-role key in "lives in password manager + Supabase project, nowhere else." Combined with the just-shipped cleanup, CI's only prod-grade credential becomes `SUPABASE_ACCESS_TOKEN` (account-wide but narrow consumption — used only by `deploy-functions.yml` for management API auth).

---

### Tiered pre-ship pipeline

Auto-detect change scope and pick a tier:

- **Full** (schema, auth, new API, security): all steps
- **Standard** (UI features, new screens): skip `/cso` and `/benchmark`
- **Light** (bug fixes, styling, docs, config): lint + tests + `/review` + `/ship`

Announce which tier was picked. Override with `--full` or `--light`.

### Cheap-test-gates-local sub-fix 2 stage 2 — per-project `.devshop/test-impact.json` path-pattern map

**Problem.** The shipped `changed-tests-local` gate runs the convention-based smoke-set floor only — `apps/web/e2e/*-qa-walk.spec.ts` ∪ `apps/web/e2e/qa-walk.spec.ts`. A project that doesn't follow that convention gets no smoke set; a project that follows it gets a fixed-cost floor but nothing precision-targeted to the diff. The path-pattern layer is the next precision rung above the floor.

**Shape.** Per-project config at `.devshop/test-impact.json` (or `.devshop/test-impact.toml` — pick one) mapping changed source paths to spec paths via filename regex. Example:

```json
{
  "patterns": [
    {
      "match": "apps/web/components/(.+)\\.tsx",
      "specs": [
        "apps/web/e2e/$1-qa-walk.spec.ts",
        "apps/web/e2e/add-item-banner.spec.ts"
      ]
    },
    {
      "match": "packages/core/src/api/(.+)\\.ts",
      "specs": ["packages/core/src/api/$1.integration.test.ts"]
    }
  ]
}
```

`changed-tests-local.sh` reads the file (when present) AFTER the convention-based smoke set, deduplicates against already-running specs, and adds the resolved patterns to the spec list. Wallclock cap unchanged (specs that exceed the budget defer to CI per the existing triage line).

**Cost/risk.** ~2-3h (file format + reader + dedup + tests). Backward-compatible: projects without the file get the same behavior as today. Risk: false positives (running specs that don't actually exercise the diff) cost wallclock but never silent breakage.

### Cheap-test-gates-local sub-fix 2 stage 3 — import-graph match via `tsc --listFiles` / `madge`

**Problem.** Stage 2's path-pattern map catches the cases the operator can express as a regex; helper changes that ripple into specs without filename overlap escape it. The shipped `changed-tests-local` gate catches this only when the spec itself is in the diff.

**Shape.** For each changed source file, walk the TypeScript reference graph (`tsc --listFiles` or a lightweight tracer like `madge`) to find every spec that transitively imports the changed file. Cache the graph against the diff hash so repeated invocations within the same session don't re-walk. ~5-15s on a typical project.

The new match logic ORs with stage 1 (smoke set) and stage 2 (path-pattern map) — a spec runs locally if any layer surfaces it.

**Cost/risk.** ~3-4h (tsc/madge integration + cache + budget enforcement + tests). Risk: tsc invocation cost can spike on large projects — wallclock cap is the safety valve. Defer until the smoke + path-pattern layers prove insufficient on a real project.

### Lalista adoption of cheap-test-gates-local

**Problem.** The devshop ships the new gate, but lalista — the validation ground — needs an explicit adoption PR to (a) verify the convention-based smoke set fires correctly on a real diff (already organically present: `core-flows-qa-walk.spec.ts`, `disambig-add-new-hero-qa-walk.spec.ts`, `qa-walk.spec.ts`, `ci-slow-job-qa-walk.spec.ts`), (b) exercise sub-fix 3's `blocked` promotion against a real degraded-stack scenario, and (c) verify the bypass flow (`devshop.localTestSkipReason` + adversarial review).

**Shape.** Devshop pull, then a deliberately stack-needing PR (e.g. minor UI change in `apps/web/components/`) with the local stack stopped, observe the preflight emit `blocked:` for the stack-needing diff, fix recipe surfaces, restart the stack, the gate passes. Then a docs-only PR to verify the same degraded stack does NOT block (legacy `pass-with-note:` advisory). Add a short note to the project's CLAUDE.md or ROADMAP about adoption status. ~30 min once the devshop merge has propagated to the project.

**Cost/risk.** Pure validation — no code changes in the project. The risk is the gate firing falsely on a real diff (false positive caught by the validation PR; correctable in devshop if needed). The benefit is empirical confirmation that the convention-based smoke set + the D6 promotion both behave as specified.

### Persona-axis pre-ship gates (designer / backend-eng / frontend-eng / security / data)

**Problem.** Today the "hat" the pipeline reviews under is hardcoded into the gstack skill that runs the gate — `/review` carries the staff-engineer mindset, `/cso` the security mindset, `/design-review` the visual mindset. The operator has no surface for layering opinionated, project-specific philosophies on top: "we always prefer SECURITY DEFINER RPCs over service-role escalation," "our designer never uses centered headlines on long-form pages," "our backend convention is repository pattern, not active record." There's nowhere for those to live and be enforced. Putting them in `CLAUDE.md` (the Phase 1 fallback) makes them background context every skill sees, but doesn't enforce them — gstack's `/review` won't fail a PR for violating a project convention buried in a CLAUDE.md section unless the convention happens to overlap with what `/review` already checks for.

**The load-bearing constraint** — gstack is third-party. We cannot modify `/review`, `/cso`, `/design-review` directly because `/gstack-upgrade` will overwrite the changes. Customization has to live outside the gstack tree.

**Precedent.** `/ak-design-conformance` already solves this shape for one axis: gstack's `/design-review` covers visual hierarchy / typography / spacing / AI-slop patterns; the devshop-owned `/ak-design-conformance` runs alongside it in `/ak-pre-ship` and covers the orthogonal axes (DESIGN.md voice doctrine drift, explicit-token conformance, canonical-example matching, imperative `must/never` rules). Same pattern, applied to more personas.

**Shape of the fix** — per-persona devshop gate, layered defaults:

| Layer               | Path                                           | Inherited by                            | Owner              |
| ------------------- | ---------------------------------------------- | --------------------------------------- | ------------------ |
| 1. Devshop-default  | `/devshop/template/personas/<role>.md`         | every new project via `/ak-new-project` | devshop maintainer |
| 2. Project-override | `/workspace/personas/<role>.md` (project repo) | this project only                       | project operator   |

The devshop-side gate reads layer 1 (always present, ships with the template), then merges/overrides with layer 2 if the project has one. Override semantics: project-override file replaces specific named sections of the devshop-default (per-section override, not whole-file). Sections without a project-side override fall through to the devshop default. Each persona file follows the DESIGN.md template — normative claims expressed as `must / should / always / never` rules, plus canonical examples, scoped by file globs (e.g. `personas/backend-eng.md § Database access` claims apply when the diff touches `apps/web/api/**` or `packages/core/api/**`).

**Personas to ship — initial set:**

| Persona           | Devshop gate                               | Runs alongside                      | Scope (file globs)                                                  |
| ----------------- | ------------------------------------------ | ----------------------------------- | ------------------------------------------------------------------- |
| `designer.md`     | `/ak-design-conformance` (extend existing) | gstack `/design-review`             | `apps/web/components/**`, `packages/ui/**`, `apps/web/app/**/*.tsx` |
| `backend-eng.md`  | `/ak-backend-review` (new)                 | gstack `/review`                    | `apps/web/api/**`, `packages/core/api/**`, `supabase/functions/**`  |
| `frontend-eng.md` | `/ak-frontend-review` (new)                | gstack `/review` + `/design-review` | `apps/web/components/**`, `apps/web/app/**`, `packages/ui/**`       |
| `security.md`     | `/ak-security-conformance` (new)           | gstack `/cso`                       | full diff                                                           |
| `data.md`         | extend existing `rls-coverage` gate        | —                                   | `supabase/migrations/**`, `packages/core/api/**`                    |

**Implementation surface:**

Devshop side (`/devshop`):

- New skills: `/ak-backend-review`, `/ak-frontend-review`, `/ak-security-conformance` under `/devshop/.claude/skills/devshop/`. Each follows the `/ak-design-conformance` template — extract normative claims from `personas/<role>.md` (LLM, cached by sha256 of merged file), verify each against the diff (grep for code-level claims, LLM-judge for prose claims), emit `pass | findings (N) [fixed|pending] | n/a`. Caching key combines devshop-default sha + project-override sha so layer changes invalidate correctly.
- Extend `/ak-design-conformance` to additionally read `personas/designer.md` (today it reads only DESIGN.md). Designer persona content is "philosophies and tendencies"; DESIGN.md is "system tokens and contracts." Both stay separate files; the gate reads both.
- Extend `rls-coverage` gate's helper script (`kit/scripts/preship/rls-coverage-check.sh`) to additionally consult `personas/data.md` rules (e.g. "all migrations must specify ON DELETE explicitly" — already a lalista convention, generalizable).
- New shared helper `kit/scripts/preship/persona-merge.sh` that produces the merged persona file (devshop-default + project-override) the gates read. Merge semantics + sha caching live here so each gate's SKILL.md stays thin.
- Wire all five into `/ak-pre-ship`'s gate ordering. Per `pre-ship/SKILL.md § Gates (canonical order + named IDs)`. Add gate IDs `backend-review (ak)`, `frontend-review (ak)`, `security-conformance (ak)`. Each gate's `n/a` rule fires when no persona file exists at either layer (so projects opt in by writing the file, not by editing the pipeline).
- New template directory `/devshop/template/personas/` with an initial set of stub files (designer, backend-eng, frontend-eng, security, data) — empty headers + the section template, no opinionated content yet. Populated incrementally from real shipping experience (don't pre-fill from imagination).
- Update `/ak-new-project` Phase B — add a step that explains the persona files: "if you have opinions about how backend code should be structured, edit `personas/backend-eng.md` here. Otherwise leave the file empty and the gate returns `n/a`."
- Update `kit/docs/guide/conventions.md` § DESIGN.md as Contract — generalize to "Personas as Contract" with DESIGN.md and personas listed as concrete instances of the same pattern.
- Update `kit/docs/guide/workflow.md` § Pre-ship gate map + the gate count (currently 14 → 16 after backend-review + frontend-review land; security-conformance is wired into the existing `cso` slot rather than as a new gate).
- Update `/devshop/CLAUDE.md` Tier 1 — add a "Persona-axis customization" entry explaining the layering so the rule is in always-loaded context.
- BATS test coverage in `kit/tests/` — at minimum a smoke test that the merge helper produces a stable output across `(default-only, override-only, both, neither)` permutations and that the cache invalidates on either file's sha change.

Project side (any project that adopts):

- Create `personas/` at repo root (gitignore nothing — personas are project-tracked).
- Edit `personas/<role>.md` files only when there's an actual opinion to enforce. Empty files → gate is `n/a`. Don't fill in slop just because the file exists.
- Phase 1 (CLAUDE.md sections) is **not deprecated** — it remains the cheap channel for cross-cutting rules that don't fit a single persona axis. Personas are for axis-scoped opinionated guardrails; CLAUDE.md is for everything else.

**Trade-offs vs the Phase 1 (CLAUDE.md sections) status quo:**

| Aspect                             | Phase 1 — CLAUDE.md sections                                                      | Phase 2 — persona files + gates                           |
| ---------------------------------- | --------------------------------------------------------------------------------- | --------------------------------------------------------- |
| Setup cost                         | Zero — append a section to `CLAUDE.md`                                            | New skills + helper + template + gate wiring              |
| Enforcement                        | Background context only — gstack skills "see" it but don't fail PRs on violations | Gate-level enforcement; PRs blocked on violations         |
| Scoping                            | Loaded for every action regardless of relevance                                   | Loaded per-gate, scoped by file globs                     |
| Per-project override               | One `CLAUDE.md` per project (no devshop default to inherit from)                  | Devshop-default inherited; project-override layers on top |
| Cross-`/gstack-upgrade` durability | Safe (gstack doesn't touch `CLAUDE.md`)                                           | Safe (devshop-owned skills outside gstack tree)           |
| Failure granularity                | None — convention-violation just doesn't surface                                  | `findings (N)` with line-level diffs                      |

**Why v1 (not v0):**

Doesn't block next-project adoption. The first project (lalista) shipped successfully with no persona enforcement; gstack's general gates plus per-project `CLAUDE.md` covered the ground. The persona axis is "valuable opinionated layer," not "structural gap." Phase 1 (CLAUDE.md persona sections in `/devshop/CLAUDE.md`) gives 60% of the value at 5% of the cost — that should ship first as a v0 entry if the operator wants the surface immediately, leaving this v1 entry for promotion to enforcing gates.

**Trigger:**

- Phase 1 (CLAUDE.md persona sections) ships and the operator finds the rules getting ignored by gstack skills (because background-context isn't enforcement); OR
- A second project adopts the devshop and the operator wants to ship project-specific philosophies that the first project doesn't share (proves the override layer is needed); OR
- A specific class of bug ships through pre-ship that a persona rule would have caught — that's the case study justifying a new gate.

**Cost/risk:**

- Implementation: ~1 focused day per new gate (3 new gates + 2 extensions ≈ 4-5 days total). Each new gate is a SKILL.md + extraction script + adversarial review wiring + pre-ship registration, following `/ak-design-conformance` as the template.
- Risk during rollout: an over-eager persona file produces noisy `findings (N) pending` blocking PRs. Mitigation — every persona gate's `n/a` rule fires when the file is empty (just like DESIGN.md today), so adoption is opt-in section-by-section. Operator writes one rule, ships it, sees it fire, decides whether to keep going. No big-bang.
- Benefit: enforces project taste at the pipeline level, not just as background context. Per-role mindsets become first-class artifacts the operator can read, edit, version-control, and override per-project. The 3-layer model (gstack toolbox / devshop workshop / project) gets symmetric enforcement on each layer.

**Cross-ref:**

- `/devshop/.claude/skills/devshop/design-conformance/SKILL.md` — the working template for "devshop gate that reads a project-side contract file and runs alongside a gstack gate." All new persona gates copy this shape.
- `kit/docs/guide/conventions.md § DESIGN.md as Contract` — the convention that this entry generalizes from one file (DESIGN.md) to N files (personas/\*.md).
- `pre-ship/SKILL.md § Gates (canonical order + named IDs)` — the gate ordering registry that needs three new entries.
- `/devshop/template/personas/` — the new template directory this entry creates; new projects inherit it via `/ak-new-project`.

### Adversarial reviewer Phase 5 — tool-use grep for `dismissalLog`

_Deferred from the doc-inlining-architecture RFC (`kit/notes/roadmap/adversarial-review-doc-inlining.md` § Phase 5). Phases 1+2+open-Q1+open-Q4 shipped 2026-05-01 (commits 0fcd4c5, 9b18f46, 889c883). See [`kit/notes/roadmap/adversarial-review-doc-inlining-followups.md`](notes/roadmap/adversarial-review-doc-inlining-followups.md) for related deferred items (operational follow-ups, open Q2/Q3/Q5)._

Today the adversarial reviewer is no-tool (LLM gets a context block, returns PASS/FAIL). Rule 1(a)'s named-edits requirement is verified by the LLM scanning the inlined diff text — fast but bounded by what was inlined. For commit-time check-types this is fine (the diff is small, fully inlined). For pre-ship `dismissalLog` it's the wrong shape: each gate-run can fire up to 11 reviews, each reviewing claims like "covered by spec § In scope" or "this RLS policy is intentional per ARCHITECTURE.md § Auth" — the reviewer needs to verify those claims against current state on disk, not just what was pre-inlined.

**Shape of the fix** — equip the `dismissalLog` reviewer (only that check-type) with a `grep <pattern> <path>` tool. Branch on `case "$CHECK_TYPE" in dismissalLog) <use tool-equipped path> ;; esac` in `adversarial-review.sh`. Add a prompt instruction: "before passing a dismissal, verify the cited spec/doc claim by greping current state on disk." Commit-time check-types (`docsReviewed`, `dirtyTreeReason`, etc.) keep the no-tool fast path.

**Why deferred** — pre-ship pipeline already runs many gates serially with their own LLM calls; an extra tool-use round-trip per dismissal is negligible. Commit-time can't afford the variance because the user is waiting at the prompt. Splitting is correct, not premature.

**Implementation surface** — `kit/scripts/adversarial-review.sh` (case branch + prompt edit + tool wiring), `kit/docs/guide/hooks.md § Dismissal Log` (document the new tool), bats tests in `kit/tests/util-adversarial-review*.bats` (verify tool is wired only for dismissalLog).

**Sequencing** — wait for one cycle of real `dismissalLog` rejections that would have caught real drift if the reviewer could grep. Build the case in incidents, not speculation.

### Adversarial reviewer Phase 6 — out-of-band coherence sweep

_Deferred from the doc-inlining-architecture RFC (`kit/notes/roadmap/adversarial-review-doc-inlining.md` § Phase 6 / § 10). See [`kit/notes/roadmap/adversarial-review-doc-inlining-followups.md`](notes/roadmap/adversarial-review-doc-inlining-followups.md) for related deferred items (operational follow-ups, open Q2/Q3/Q5)._

Commit-time `docsReviewed` catches drift introduced **by** a commit. It can't catch drift that existed before the commit and survived. Across many commits, the doc set silently degrades — one entry says N, another says M, neither commit alone touched both. Today's only catch-mechanism is rule 1(c)'s cross-file-coherence sweep when reference docs are co-staged, which only fires on overlap.

**Shape of the fix** — periodic gate (e.g., weekly cron via `/schedule`) that reads all reference docs and asks the reviewer to flag contradictions across them. Output: a checklist of "X says A, Y says B — pick one." Operator (or a follow-up agent) reconciles.

**Why deferred** — the rule 1(a) sharpening landed in PR 9b18f46 already raises the per-commit catch rate substantially (validated by the reviewer catching three real coherence issues against this same RFC's own commits). Out-of-band sweep is a backstop, not the primary defense. Build it once we have data on what slips through despite rule 1.

**Implementation surface** — a new skill or scheduled agent (`/coherence-sweep` candidate name); reads all reference docs, drives the existing `adversarial-review.sh` engine in a "compare across all" mode (or builds a parallel one); reports out via Slack / Linear / a dedicated `kit/notes/coherence/<date>.md`.

**Sequencing** — also gated on Phase 5 landing first. Tool-use grep makes the coherence reviewer materially better at verifying claims across many docs in one pass; without it, a coherence sweep is a much more expensive token-burn.

### Weekly pg_dump backup (beyond pre-migration dumps)

Pre-migration `pg_dump` lands in Phase 1c. This v1 item adds a weekly scheduled
backup independent of deploys — catches data corruption that isn't tied to a
migration. GitHub Action cron → `pg_dump` → artifact or private gist.

### Devshop observability — skill invocation log

Each devshop skill appends one line to `kit/log.csv`:
timestamp, skill name, duration, outcome (pass/fail/paused), notes.
`/retro` reads it to inform retrospectives with real data instead of opinions.

### Migration rollback integration testing

CI runs migration forward → rollback → re-apply to prove rollback SQL actually
works against real data. Currently only syntax-validated (v0). Full forward+backward
testing catches data-dependent rollback failures.

### Automated service quota monitoring

GitHub Action cron (weekly or monthly) that checks usage against quotas for
Supabase, Sentry, PostHog, GitHub Actions, and Vercel. Warns when usage > 80%.
v0 has manual dashboard links in the guide; this automates the check.

### Local integration test alternatives to DinD

v0 uses Docker-in-Docker for `supabase start` inside the devcontainer (16GB+ RAM).
If DinD proves too heavy, evaluate alternatives: host-side Supabase with devcontainer
connecting via `host.docker.internal`, or optimized CI-only workflow.
Full research: `kit/notes/integration-test-local-alternatives.md`

### Subagent architecture for `/implement`

v0 uses single-agent implementation (full spec in one context, 1M model).
When context pressure is observed (agent losing track of earlier tasks, hitting
limits on large features), switch to orchestrator + per-task subagents.
Design: main agent manages TASKS.md, spawns subagent per task with task description,
relevant spec sections, hat principles, and a shared context summary file
(`CONTEXT.md`) that grows as tasks complete.
Trigger: when `/implement` starts losing context on features with 10+ tasks.

### Changesets

`@changesets/cli` + `.changeset/config.json` — automated changelog generation in PRs.
Removes manual CHANGELOG maintenance. Each PR includes a changeset file describing
the change; on merge, changesets auto-generates the changelog entry.

### `/ak-commit` skill + husky gate

Replace raw `git commit` with an `/ak-commit` skill that owns the full commit loop:
assess dirty state in both repos → classify files → plan commits → execute → verify
clean → repeat until done (or ask user for unknowns). Enforced by a husky pre-commit
gate (`check-ak-commit.sh`) that blocks raw commits — bypass requires a descriptive
reason, adversarially reviewed. Same pattern as `dirtyTreeReason` and `docsReviewed`.

Problem it solves: raw `git commit` has no skill-level orchestration of the
assess → classify → plan → commit → verify loop. The pre-commit husky gates
block bad commits and the pre-push gate blocks stale PRs / dirty pushes (since
the 2026-04-19 hook architecture migration), but neither plans multi-commit
sequences. `/ak-commit` would own the commit loop end-to-end, replacing raw
`git commit` for anything beyond a single-file change.

Full design: `kit/notes/ak-commit-design.md`

### PR-description staleness check — layer + approach decision

**Context:** The 2026-04-19 hook architecture migration replaced the old PostToolUse `check-pr-description.sh` with a blocking `.husky/pre-push` check (`prDescStaleReason`). It catches a real observed bug — Claude has been seen pushing new commits without updating the open PR's title/body. But the current implementation fires the adversarial reviewer on EVERY non-trivial push, and a blank bypass reason auto-rejects regardless of whether the description is actually aligned → per-push friction even when the description matches. Tactical TODO + inline options captured in `kit/TODOS.md`.

**Alternatives considered (2026-04-19 session):**

- **(A) Prompt tune.** In `kit/scripts/adversarial-review.sh`, run item 8(a) "PR description genuinely matches the commits" alignment check BEFORE the generic blank-reason auto-reject path. Keeps the reviewer always-on; reduces false positives on aligned descriptions. ~10 LoC. Risk: shared-engine regression on other check types that rely on the "blank reason → generic → reject" semantics.
- **(B) Symptom detection in the hook** ("reframe-B"). Short-circuit when PR title prefix matches the highest-impact commit prefix + no bypass reason set → skip reviewer. Fire reviewer only on prefix mismatch OR explicit bypass. Parallels the `check-clean-tree.sh` pattern — deterministic symptom gate, reviewer only for edge cases. ~15-20 LoC in `.husky/pre-push`. False negative: title-aligned-but-body-stale slips through — same miss rate as the old advisory-hook era. Acceptable tradeoff per hook-migration precedent.
- **(C) Both A + B.** Most robust. Moderate effort.
- **(D) Drop the hook check entirely.** Rejected — the forget-to-update-PR bug has been observed in practice; the hook is earning its place.
- **(E) Move to skill layer.** Remove from the hook; add "verify + update PR description" step to skills that own PR operations (`/ship` gstack, `/ak-build` Phase 5 devshop, future `/ak-ship-devshop`). Architecturally cleaner: workflow concerns in workflow-owning skills, hook layer reserved for safety invariants (dirty tree, stash, release-coverage). Gap: ad-hoc `git push` from Claude outside pipeline-driven skills would have no check. Could combine with (B) as "hook = safety net for ad-hoc pushes, skill = active workflow step."

**Current lean:** (B) as the hook tune + (E) added to `/ak-build` Phase 5 in a separate follow-up. Hook stays as the belt-and-suspenders safety net for ad-hoc pushes; skill step is the active reminder where most PR operations actually happen.

**Decision trigger:** after PR 3 (`/ak-build core-flows`) has surfaced real data on (a) the false-positive rate of the current always-fires implementation, (b) whether the prefix-match heuristic holds up against real PR-desc patterns, (c) whether Claude's forget-to-update bug recurs during PR 3's pushes. Decide between A / B / C / E / hybrid with evidence.

**Cross-refs:** `kit/TODOS.md` (tactical TODO — compressed to a pointer back to this section). Origin in the 2026-04-19 hook architecture migration — see git log around v1.10.0.

### `/ak-merge-devshop` skill — audit + ff-merge + push + cleanup

**Problem.** Devshop has no GitHub PRs and no `/ak-go-live` equivalent. The merge moment today is multi-step and entirely manual: invoke `/ak-check-docs-and-tests` before each ff-merge, react to high/medium findings on the branch, ff-merge to main, push, delete the merged branch local + remote, optionally hand off to `/ak-release-devshop` if a tag is warranted. Skipping the audit step is silent — pre-commit Layer 1 has no concept of "merge moment" and won't catch the omission.

The PR-A+B+C inaugural devshop run (2026-05-07) made the gap concrete: the operator ran `/ak-check-docs-and-tests` manually, the audit caught 7 medium drift findings against a clean-attestation bypass body, the operator iterated on the branch (a fix commit), re-ran the audit (Audit 2 clean), then ff-merged. Every step was correct but every step was hand-driven. The skill captures that exact sequence so the next devshop merge doesn't depend on operator memory.

**Shape.** Closer to `/ak-go-live` than `/ak-build`. `/ak-build` is the build pipeline (spec → implement → ship); `/ak-go-live` lands what the build produced (land → deploy → verify). The devshop analog of `/ak-go-live` is "audit → ff-merge → push → cleanup → optional release" — that's this skill. Naming `/ak-merge-devshop` mirrors the existing `/ak-release-devshop` suffix pattern.

**Scope (skill steps):**

1. **Sanity preconditions.** Assert: on a non-`main`/`master` branch (audit is feature-level — `/ak-check-docs-and-tests` already errors out on `main`, but catching it here surfaces the misuse with the right framing); working tree clean (no unstaged changes — operator's stashable WIP is theirs to manage before invoking, not the skill's to handle implicitly); branch fast-forward-able onto `origin/main` (no divergent history).
2. **Run `/ak-check-docs-and-tests`** over `origin/main..HEAD` (skill computes the range itself; this skill just invokes it). Halt on any high-severity finding — surface them and exit with a fix-then-rerun message. On medium-only findings, surface them and ask: fix on branch, accept and continue, or abort. Default to "ask" — the convention I wrote into `CLAUDE.md` says "before each ff-merge"; the skill enforces by making the audit non-skippable, not by auto-deciding what to do with mediums (they're judgment calls). Pre-PR-C the project-side equivalent decision was the human-driven "review the PR" step; devshop has no PR review surface, so the skill's medium-handling IS the review surface.
3. **ff-merge to main + push.** `git checkout main && git merge --ff-only <branch> && git push origin main`. The pre-push hook's devshop-mode short-circuits on push to main (no PR-desc check, no main-block) so no friction. Idempotent: if main is already at branch HEAD (operator already merged manually), step is a no-op rather than an error.
4. **Branch cleanup.** `git branch -d <branch>` + `git push origin --delete <branch>` if the remote ref exists (silently no-op if it doesn't — the inaugural PR-C run exercised this; the branch never had an origin counterpart).
5. **Release suggestion (chained, not auto-run).** Run the same logic `/ak-release-devshop` Phase 0 uses to decide if a bump is warranted (commits since last tag include `feat:` / `fix:` / `BREAKING CHANGE:`). If yes, surface the suggestion + the proposed bump tier, but do NOT auto-invoke `/ak-release-devshop` — release is a deliberate decision per the existing convention. Operator decides whether to chain it. (Compare to `/ak-go-live`'s decision to chain `/canary` automatically: there, the deploy is non-optional once the merge lands; here, the release is optional even when there are shippable commits.)

**Cost/risk.**

- Implementation: ~3–5h. Most of the logic exists — `/ak-check-docs-and-tests` is the heavy lifting and already shipped in PR-A; the merge / push / cleanup sequence is 4 git commands; the release-suggestion logic lifts the existing `release.sh` tag-derivation. The skill body is mostly orchestration + UX (medium-finding decision prompt, halt messages, idempotence checks).
- Risk: medium-finding handling is the load-bearing UX call. Auto-accepting mediums would defeat the audit's purpose ("the audit is the review"); auto-blocking on any medium would over-correct and produce a "kit/notes/\*\* mention is medium because grep matched it" friction loop. Defaulting to "ask" is the right escape hatch for a single-developer flow but means the skill can't run unattended in a CI-like context (devshop has no CI; this constraint is acceptable).
- Benefit: makes the convention enforceable rather than aspirational. Shifts the audit from "operator remembers to run it" to "the merge entry point IS the audit." The PR-C session's manual sequence becomes one command.

**Out of scope (separate roadmap entries):**

- **Mode-aware `/ak-build` for devshop** — covered by the next entry (`Devshop self-build pipeline`). That's the build-side counterpart; this is the merge-side counterpart. Ship them independently if at all.
- **Auto-chain to `/ak-release-devshop`** — release deliberation has historically been non-automatic; that stays. The skill suggests, doesn't act.
- **Auto-fix medium findings** — categorically not the skill's job. Audit-time review surfaces; operator decides; skill records the decision (via the audit's `## Audit N` section + the merge commit's audit pointer). Auto-fix would re-introduce the per-commit Sonnet pattern PR-C just removed.

**Trigger.** Lands when the next devshop merge is queued — the inaugural PR-C run is the validating use case behind this entry; the next devshop merge is the trigger to ship the skill rather than re-run the manual sequence.

**Cross-refs:**

- `/ak-go-live` (project-side analog).
- `/ak-release-devshop` (chained from this skill's step 5).
- `/devshop/CLAUDE.md § Devshop shipping flow` (the convention the skill enforces).
- `kit/ROADMAP.md § Move adversarial Layer 2 reviews from per-commit to audit-time` § PR-C convention block (the "before each ff-merge" rule the skill operationalizes).

### Devshop self-build pipeline

Use the project build machinery (`/ak-build`) for devshop changes themselves.
Currently devshop work is manual: branch, edit, commit, push, PR. The project pipeline (spec → implement → quality gates → ship) is
tightly coupled to project conventions (specs/ dir, metrics, responsive/theme
checks) and doesn't fit devshop changes.

**Options (pick at implementation time):**

- **`/ak-devshop-build`** — lighter devshop-specific pipeline: branch → edit →
  commit guard → docs consistency check → push → PR. Reuses `/ship` for the PR
  step. Skips specs, metrics, responsive checks.
- **Mode-aware `/ak-build`** — detect devshop branch prefix → swap in devshop
  conventions (devshop commit prefix, docs drift checks, script tests) instead of
  project ones. Single entry point but more complex.

**Devshop quality gates (different from project):**

- Commit guard passes (no mixed commits)
- Docs consistency (three-way: CLAUDE.md ↔ README ↔ GUIDE)
- Script tests (when they exist — see TODOS.md)
- No responsive/theme/metrics checks

**Trigger:** when devshop changes become frequent enough that the manual
branch-edit-commit-push flow feels like friction.

### CLAUDE.md block assembly

Template snippets in `kit/templates/claude-blocks/` — one per technology choice
(`supabase.md`, `vercel.md`, `posthog.md`, `sentry.md`, etc.). Each block contains the
env vars, migration commands, file path patterns, and conventions for that tool.

`/ak-init` assembles the project's `CLAUDE.md` from the relevant blocks based on which
services are set up (steps 3-6 already know). Same content across all projects using
the same stack; different for projects with different tech choices.

`/document-release` maintains "Where Things Happen" as paths get added post-init.

### Staging migration validation

Local `supabase start` and CI both run migrations against fresh DBs from seed.sql.
Neither tests against production data shapes. Data-dependent migration failures
(NOT NULL on columns with legacy nulls, table locks on large tables) only surface
in production. `-- ROLLBACK` and `pg_dump` are recovery, not prevention.

Options:

- Restore latest pg_dump into temporary local Supabase, run new migration against it
  before deploying (automated in `/post-merge`)
- At minimum, make every migration a "stop and ask" item with human review against
  production schema (already the convention — this automates verification)

### Accessibility testing in E2E (axe-core)

`eslint-plugin-jsx-a11y` already runs via `eslint-config-next`. Add runtime a11y
testing with `@axe-core/playwright` in E2E tests — catches issues that static
analysis misses (dynamic content, focus management, ARIA state). Wire into Playwright
test setup so every E2E page visit runs an axe scan.

Trigger: when the first E2E-testable flow exists (Phase 1e or equivalent).

### Sync script improvements

Current: simple `cp` guided by `manifest.txt`. Improve to:

- Diff before overwrite — show what changed, ask for confirmation
- Create PR on the devshop repo instead of direct push
- Conflict detection with abort + diff shown

### `/ak-collateral` skill — marketing / landing-page asset composer

Devshop has design-ops skills (`/design-consultation`, `/design-review`, `/plan-design-review`) but nothing that composes marketing collateral. Produce README banners and landing-page imagery from assets the pipeline already generates.

**Shape (not final):**

- Inputs: latest `specs/<feature>/hero/*.png` across merged features, project `README.md`, `DESIGN.md` tokens, optional `PRODUCT-ROADMAP.md` teaser line.
- Output: one or more composed PNGs (README banner, social card, hero strip) + an HTML landing-page layout (one page, static, design-system-consistent) in `docs/collateral/` or similar.
- Related: similar compositional pattern to `/design-html` + `/design-shotgun` — reuse that infrastructure if possible.

**Why not now:**

Projects need something to showcase before showcase tooling matters. lalista is pre-MVP (PR 2 = auth, PR 3 = core flows) — nothing to feature yet. The `guide/conventions.md § Screenshot Routing` table explicitly defers README-banner / marketing imagery until "the first project needs one." When the first flow ships with a visible product surface, that's the signal to build this.

**Trigger:**

- First project has at least one merged feature with committed `hero/*.png` showing end-user value (not just an auth gate).
- OR: user explicitly asks for a README banner and we realize this is the fourth ad-hoc composition request.

**First-pass design work:**

- Whether to reuse `/design-html`'s Playwright + screenshot pipeline vs. a new sharp/canvas-based compositor.
- Whether output lives in `docs/collateral/` (per project) or `specs/_collateral/` (spec-adjacent).
- How to handle brand assets (logo, fonts) — point at `DESIGN.md` token set or require a separate brand kit.

### Invite-code signup control — opt-in at `/ak-new-project`

Some projects launch invite-only (private beta, controlled rollout, reputation-protection while testing). Supabase's built-in signup is open by default; the only lever is `disable_signup: True` which blocks everyone indiscriminately. Invite-code gating is the common middle-ground and will be a repeat request.

**Shape (not final):**

- **Migration**: `invite_codes` table — `id uuid`, `code text unique not null`, `created_by uuid references auth.users(id)`, `used_by_user_id uuid references auth.users(id)`, `created_at`, `expires_at`, `invalidated_at`, `notes text`. RLS: service_role full access; authed users can only SELECT their own redeemed code (for UI confirmation).
- **Admin RPCs** (SECURITY DEFINER, grant to `authenticated` with admin check inside):
  - `create_invite_code(p_notes text, p_expires_in interval default '30 days')` returns `text` (the new code).
  - `invalidate_invite_code(p_id uuid)` returns `void`.
  - `list_active_invite_codes()` returns `setof invite_codes`.
- **Edge function `signup-with-invite`** (public endpoint) — accepts `{email, password, invite_code}`, validates the code against the table, marks it used atomically, calls `auth.admin.createUser` with service role. All in one transaction so a failed `createUser` doesn't burn the code.
- **Supabase auth config**: `disable_signup: True` to force all signups through the edge function.
- **Optional admin surface**: simple CLI script under `kit/scripts/invite-codes.sh` (list/generate/invalidate). A full UI page is project-specific — out of scope for the devshop template.

**Integration pattern:**

- `/ak-new-project` Phase B: interactive prompt "enable invite-code signup control? [y/N, default N]". If yes, run an `ak-scaffold-invites` sub-step that:
  1. Drops the migration into `supabase/migrations/`
  2. Drops the edge function into `supabase/functions/signup-with-invite/`
  3. Patches auth config to `disable_signup: True`
  4. Drops the CLI script + seed invite code into `kit/scripts/`
  5. Updates project `README.md` with a "Closed beta — signups require an invite code" note
- If no, skip — open signup stays default. Projects can opt in later by running the same scaffold-invites step manually (or via a future `/ak-add-invites` skill).
- Existing projects (like lalista) that want to adopt invite-only post-launch: point them at this scaffold flow.

**Why v1, not v+:**

This was the second auth-hardening request in one conversation (password_min_length: 8 was first, now invite-code gating). Paired with the Supabase hardening step shipping in Step 2 — the auth-defaults story is incomplete without a controlled-signup option. Invite-only is table stakes for any serious closed-beta launch; waiting until v+ means the first project needing it gets an ad-hoc implementation.

**Trigger:**

- First project explicitly asks for invite-only signup (lalista might; future projects very likely when launching)
- OR: second project adopts the devshop and hits the same "bots will hammer the site" concern — that's the "don't forget reviewing this again on next project" moment

**Cross-ref:**

- The `/ak-new-project` Phase B auth-hardening step (landed in devshop v1.11.0) — mandatory password-length + interactive CAPTCHA ship first; invite-code gating is the next layer up for projects that need it.

### `/setup-email` skill — custom-domain transactional emails (Resend + Supabase Auth SMTP)

Devshop projects ship on Supabase's default sender (`*.mail.app.supabase.io`) for v0 — fine for closed dogfood behind a "we're early" footer note, looks like phishing the moment unfamiliar users see it. The cutover to a branded `from:` address is a multi-surface operator dance: domain at the registrar, Resend signup + SPF/DKIM/DMARC, Supabase dashboard SMTP + templates + URL allow-list, plus repo-side edits (config.toml SMTP block, email-template logo URL, drop "Supabase is the messenger" footer, CLAUDE.md gotcha for the three-surface dance). Each piece is small but the orchestration is non-obvious, especially "templates in `supabase/templates/*.html` don't auto-deploy — you must paste into the prod dashboard" (this trap caught lalista at chapter 1l ship time).

**Why a dedicated skill instead of folding into `/ak-new-project` Step 3 (account creation):**

- Resend earns its keep ONLY after a custom domain is provisioned. At new-project time, projects are on `<project>.vercel.app` and don't have a domain yet — Resend signup at day 1 just leaves an unverified domain on their dashboard.
- DNS verification is async (5min–2hr); the new-project flow can't block on it, so half the setup gets deferred anyway.
- Not every project needs transactional email (internal tools, B2B with SSO, CLI products) — making it a Step 3 line item adds friction with no payoff for those.
- The trigger isn't "creating a project"; it's "you have a domain and want branded emails." Those are decoupled in time. Lalista hit the email-cutover moment ~6 months after `/ak-new-project` ran.

**Shape (not final):**

- Precondition check: project has a verified custom domain (read from CLAUDE.md § Deploy Configuration, or prompt). Block + pointer to "buy a domain first" if not.
- Walk the operator through Resend: sign up at resend.com, add domain, copy 3 DNS records (SPF `TXT @ "v=spf1 include:_spf.resend.com ~all"`, DKIM `TXT resend._domainkey ...`, DMARC `TXT _dmarc "v=DMARC1; p=none; rua=mailto:dmarc@<domain>"`), wait for verification, mint API key, **1Password reminder** (never local disk, never `.env`).
- Walk the Supabase dashboard:
  - Auth → SMTP Settings: paste host `smtp.resend.com`, port `465`, user `resend`, password `<API key>`, sender email `noreply@<domain>`, sender name = project name.
  - Auth → Templates: paste each `supabase/templates/*.html` body + subject (the dashboard does NOT pull from the repo — this is the trap).
  - Auth → URL Configuration: Site URL = canonical custom domain; allow-list includes `https://<domain>/auth/callback?**`.
- Repo edits: uncomment-form update to `supabase/config.toml [auth.email.smtp]` block (Resend recipe, kept commented — local-dev still mailpit, prevents test traffic burning the free tier); drop "Supabase is the messenger" footer from email templates; swap email-logo URL from `*.vercel.app` to custom domain; add CLAUDE.md gotcha capturing the three-surface dance + the "templates don't auto-deploy" trap.
- Smoke test from a clean inbox: confirmation + forgot-password emails. Verify `from:` reads project name, DKIM=PASS in Gmail "Show original", inbox placement = primary tab, links land on canonical domain natively (no redirect hop).
- Optional commit + PR.

**Trigger:**

- Second project adopts devshop and hits the "default sender looks like phishing past first users" gap — that's the moment to encode the skill.
- OR: lalista hits the cutover a second time on a future project, or has to repeat any part of the dance (unlikely — it's mostly one-shot per project).

**Why v1, not v+:**

The diff is well-understood now (lalista ran it 2026-05-05). Encoding is cheap relative to the payoff — every project past closed dogfood needs this, and the operator-time cost of doing it ad-hoc each time is meaningful. Deferred to v1 (not v0) because no project is currently in the "second time" state — lalista's first run IS the reference implementation, and the skill earns its keep on project #2.

**Cross-ref:**

- Pattern reference: lalista's cutover branch (commit lands as the canonical diff template the skill applies elsewhere). Touched files: `supabase/templates/{confirmation,recovery}.html`, `supabase/config.toml`, `OVERVIEW.md`, `PRODUCT-ROADMAP.md`, `CLAUDE.md`.
- Related skill shape: `/setup-deploy` is the precedent — "you have a thing (deploy target), walk through configuring it." Same skeleton applies here.
- Related v1 dependent (lalista-side): `PRODUCT-ROADMAP.md § v1 § Existing-account sign-up nudge email` has a hard dep on custom-domain SMTP being live. `/setup-email` is the prerequisite that unblocks it.
- `/ak-new-project` Step 3 (account creation) deliberately does NOT include Resend per the rationale above; instead, Step 23-equivalent (deferred/post-launch items) gains a pointer: "When you have a custom domain and want branded emails, run `/setup-email`."

**Source:**

- This entry surfaced 2026-05-05 in the lalista cutover conversation. Operator asked "should we add Resend to `/ak-new-project`'s services list?" — recommendation was a separate `/setup-email` skill rather than bundling into new-project, for the reasons above. Filed for v1 per operator direction in same conversation.

---

### Project-side devshop version tracking + upgrade-gap surfacing

**Problem.** Today there's no mechanism for a project (lalista et al.) to know which devshop version it was scaffolded against, nor for `init-devshop.sh` (or any session-start hook) to surface "your project is N versions behind the live devshop; here's what's changed in between." The devshop ships releases (`/ak-release-devshop` cuts tags from `kit/version`); projects pin nothing and discover drift only when a skill behaves unexpectedly or a convention referenced in a doc no longer matches the current devshop. The asymmetry is: devshop knows its own version; projects don't know the devshop version they're built against.

A second problem: there's no ambient pressure to propagate devshop improvements to existing projects. A new convention codified in `/devshop/CLAUDE.md § Foo` only lands in the projects that happen to have a session active when the convention ships — older projects keep operating on stale assumptions until their operator manually re-reads devshop docs (rare). The result: each project's behavior drifts from the current devshop's assumed-shared baseline at a rate that scales with elapsed time, and the only recovery is post-hoc "why is this skill failing on lalista but not abracadabra" debugging.

**Shape of the fix:**

1. **Project records the devshop version it was built against.** `/ak-new-project` writes `<project>/.devshop-version` (or a JSON `<project>/.devshop/state.json` if multiple state fields accumulate) at scaffold time, containing the `kit/version` of the devshop release used. Tracked in git; explicitly NOT a generated artifact.

2. **Session-start hook diff.** The existing `kit/scripts/session-start.sh` (which already injects different context for project vs devshop sessions) reads `.devshop-version` and compares to `/devshop/kit/version`. When the project is behind:
   - One-line at session start: `📦 Project on devshop v0.7.2 → live is v0.9.1 (N releases behind). See /devshop/kit/docs/CHANGELOG.md for what's changed.`
   - Don't block; don't auto-upgrade — surface only.

3. **`/ak-upgrade-devshop` skill (new).** Operator-invoked when they're ready to bring a project's conventions / template files / skill assumptions up to current. The skill:
   - Reads the project's pinned version + devshop's current version.
   - Walks `kit/docs/CHANGELOG.md` entries between them, classifying which entries imply project-side action (e.g., "new convention X in `/devshop/CLAUDE.md` — rewrite project's Y to match") vs project-irrelevant (e.g., "internal devshop refactor").
   - Surfaces the action items as a checklist; operator approves or skips each. Skill applies the approved diffs.
   - On completion, bumps `<project>/.devshop-version` to the new version + commits.

4. **Decoupled from `/ak-merge-devshop`.** Deliberately. Merging a feature on the devshop side does not auto-propagate to projects — projects could be many, and coordinating each devshop release with active project work breaks the user's scaling assumption ("we shouldn't on every devshop release ask about this"). Upgrade is operator-initiated per-project, on the project's schedule.

**Why deferred to v1:** the gap is real but not blocking next-project adoption. The first project (lalista) is on the devshop's working tree directly via the `.devshopkit/` symlink; there's no "version pinning" — every devshop change is immediately visible to lalista. The convention drift problem only emerges when a second project exists AND that second project is decoupled from devshop main (e.g., scaffolded against a tagged release). v0 work doesn't hit this; v1 onboarding of a second project will.

**Implementation surface (when picked up):**

- New file: `/devshop/template/.devshop-version` template (just contains the placeholder `__DEVSHOP_VERSION__` that `/ak-new-project` substitutes).
- Edit `/ak-new-project` Step N (scaffold time): write `.devshop-version` with current `cat /devshop/kit/version`.
- Edit `kit/scripts/session-start.sh` (project session branch): read + diff + emit upgrade-gap line.
- New skill: `/devshop/.claude/skills/ak-upgrade-devshop/SKILL.md`.
- `kit/docs/CHANGELOG.md` discipline: entries that imply project action need a structured marker (e.g., `**Project action:** rewrite X to match Y`) so the upgrade skill can extract them. `/ak-release-devshop` Phase 2 (changelog generation) is the right place to enforce the marker convention.

**Source:**

- Surfaced 2026-05-07 during the `/ak-merge-devshop` design conversation. Operator pushed back on a coordinated-change check at merge time, observing: "in the case we need to do changes on the projectS (plural) side so they support the newest version of the devshop... seems like we should have a way that when we open the project, the init-devshop brings it up to date. Perhaps we'll need some tracking of the devshop version a project has been built with so far. But definitely we shouldn't on every devshop release ask about this, since projects could be many." This entry captures that idea verbatim before it's lost.

---

## v+ (future — when the need is felt)

### Full Finding Router — structured `disposition:` per gate dismissal

**What this is** — an extension of the Dismissal Log (see `.claude/skills/devshop/pre-ship/SKILL.md § Dismissal Log`). Today every `/ak-pre-ship` gate's report includes a `## Dismissals` section where findings the gate chose not to fix get a free-text `rationale:` field. The Finding Router adds a **structured `disposition:` field next to each rationale**, turning "here's why I dismissed this" into "here's what should happen with this finding" — and then the pipeline does the appropriate thing with each.

**Background — why it's deferred until now**

The 3-PR gstack-guidance-enforcement work (landed in devshop v1.16 as `feat/preship-dismissal-log` + `feat/preship-core-user-story` + `feat/preship-design-conformance`) sized the Finding Router as the fourth and largest piece, intentionally cut out to land the other three first:

- Dismissal Log (the scaffolding) forces every gate to make triage explicit and gives us an adversarial-reviewed `rationale:` field — catches silent dismissals now.
- Core User Story + Gate 9 artifact assertion — catches silent no-ops (the original `add-sheet open+Escape` failure mode).
- Design-conformance gate — catches DESIGN.md drift the visual `/design-review` gate doesn't check.

All three closed the concrete bugs that motivated the work. The Finding Router is the clean-up layer: it takes the `rationale:` data the other three produce and routes it into concrete actions.

**What the router adds**

Five dispositions, each mapped to a pipeline action:

| `disposition:`    | Meaning                                                  | Pipeline action when the gate emits this                                                                                                          |
| ----------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fix-now`         | Real bug, must resolve in this PR                        | Agent fixes inline, commits (atomic per finding), gate re-runs                                                                                    |
| `fix-before-ship` | Must resolve before merge, but not necessarily right now | Appends a must-fix checkbox to the PR body; `/ak-build` Phase 6 verifies these are checked before declaring ready-for-review                      |
| `TODO`            | Valid concern, out of scope for this PR                  | Auto-append to `TODOS.md` with source tag (`[gate-name]`) so the next `/ak-status` surfaces it                                                    |
| `spec-amendment`  | Spec was ambiguous, not a real implementation gap        | Auto-amend `specs/<name>/spec.md` with the clarification + commit; gate re-runs against the clarified spec                                        |
| `ignore`          | Not actionable (false positive, out-of-scope-forever)    | Noted in `review.md` with reasoning — stays searchable but takes no pipeline action. This is the ONLY disposition Phase 3's MVP implements today. |

**How it composes with Phase 3's Dismissal Log**

Today's `rationale:` bullets stay exactly as-is. A Phase 4 dismissal just gains a `disposition:` line adjacent to the `rationale:`:

```markdown
## Dismissals

- polish-tier visual tweak on settings page
  - rationale: nits a designer would fuss over, but off-path for PR 3's core-flows scope
  - disposition: TODO
```

Dismissal-Log entries written before Phase 4 still parse — they just lack `disposition:` and route through the `ignore` path by default (current behavior). Net effect: additive, not migrational.

**Per-gate routing rules — where incremental lands**

This is where "Phase 4 wires gates incrementally" makes sense. Each gate has different severity taxonomies, and the mapping from a gstack finding to a `disposition:` isn't one-size-fits-all:

| Gate                 | Finding source                                          | Mechanical mapping possible?                                                                                   | Suggested landing order                     |
| -------------------- | ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| `/cso`               | JSON with `severity: CRITICAL\|HIGH\|MEDIUM\|TENTATIVE` | Yes — CRITICAL/HIGH → fix-now, MEDIUM → TODO, TENTATIVE already auto-dismisses via the Phase 3 shim            | 5th (mechanical, easy win)                  |
| `/benchmark`         | Metrics + thresholds (LCP, CLS, bundle size)            | Yes — threshold-based routing; above-threshold → fix-now, borderline → TODO, within-threshold already filtered | 6th                                         |
| `/qa`                | Prose findings with Critical/High/Medium/Low severity   | No — needs LLM judgment ("is this High severity blocker for this PR or not?")                                  | **1st (highest subjective-judgment value)** |
| `/design-review`     | Visual issues with impact rating (High/Medium/Polish)   | No — same reason as `/qa`                                                                                      | 2nd                                         |
| `/ak-test-review`    | Prose findings about test quality                       | No — needs judgment                                                                                            | 3rd                                         |
| `/review`            | Inline code-review comments + Greptile triage           | No — needs judgment                                                                                            | 4th                                         |
| `/simplify`          | Duplications / over-abstractions                        | Mostly auto-fixes inline today; router handles the residual                                                    | 7th                                         |
| `design-conformance` | Per-claim `needs_review` entries                        | No — needs judgment against DESIGN.md                                                                          | Bundle with `/design-review` (2nd)          |

Each gate's routing rules live in a small file under `kit/scripts/finding-router-rules/<gate>.sh` or similar — a per-gate mapping function that takes a finding (with severity + description) and returns a disposition.

**Adversarial review expansion**

The existing `dismissalLog` check-type in `kit/scripts/adversarial-review.sh` (landed in Phase 3) judges `rationale:` quality. Phase 4 extends the same check-type — or adds a sibling `dispositionRouting` check-type — that also judges whether the chosen `disposition:` is plausible given the rationale + the spec's `## Core user story` + `## In scope`. E.g., dismissing a core-story-touching finding as `ignore` with a vague rationale should be rejected.

**Concrete implementation sketch**

When Phase 4 lands:

1. **`kit/scripts/finding-router.sh`** — new script with subcommands: `route <gate> <findings.json>` (apply gate-specific rules + emit dispositions), `execute <disposition-plan.json>` (perform the pipeline action per entry), `verify <feature>` (confirm every fix-before-ship entry is actually resolved before declaring gate pass).
2. **`kit/scripts/finding-router-rules/<gate>.sh`** — per-gate mapping functions, starting with `/qa` and `/design-review` as the first wired gates. Other gates route everything through `ignore` by default until their rule file lands.
3. **`.claude/skills/devshop/pre-ship/SKILL.md § Dismissal Log`** — extended with the `disposition:` field spec + invocation of `finding-router.sh` after each gate's report is produced.
4. **Adversarial review prompt** — rule #11 added alongside rule #10 (dismissalLog) in `kit/scripts/adversarial-review.sh` for routing-plausibility judgment.
5. **Integration tests** — new `kit/tests/finding-router.bats` + per-rule fixtures under `kit/tests/fixtures/finding-router/` exercising each gate's routing.
6. **Docs** — `kit/docs/guide/workflow.md` Phase 3 pre-ship paragraph extended; `kit/docs/guide/hooks.md` § Dismissal Log subsection upgraded to § Finding Router; `CLAUDE.md` Known Footguns entry updated for the new dismissal-log contract.

**Ship size estimate**: ~250 lines for the router core + ~60 lines per wired gate + ~80 lines per bats test file. Landing the first two gates (`/qa` + `/design-review`) is roughly ~500 LOC. Subsequent gates are smaller as patterns emerge.

**Cost breakdown (2026-04-22 estimate)**

- **Phase 4a — router scaffold + first two gates (`/qa` + `/design-review`)**: ~500 LOC across ~5 files. Realistically 2 PRs (scaffolding PR: router core + adversarial-review extension + bats tests; then gate-wiring PR). Several focused sessions, not a single sitting.
- **Phase 4b — remaining 5 gates (`/ak-test-review`, `/review`, `/cso`, `/benchmark`, `/simplify`)**: ~60–100 LOC per gate for the rule file + tests. ~400 LOC total. Can be incremental over weeks as patterns emerge.
- **Full program**: ~900 LOC, 3–5 PRs, spread over multiple working days.
- **Doubled adversarial-review load**: every non-`None` dismissal goes through TWO LLM calls (rationale-quality + disposition-plausibility). Cost per pipeline run doubles for dismissal review specifically; the short-circuit on `None` bodies (Phase 3's scoped parse) keeps default runs at zero cost.

**Risk breakdown (2026-04-22 estimate)**

Medium-to-high overall. Four distinct risk classes:

1. **Automated `fix-now` is a real risk.** The pipeline decides "this is a bug, fix it now" and commits inline. If the routing is wrong (finding is a false positive) or the fix is wrong, bad code lands without human review. The existing `/ak-implement` stuck protocol + tests-must-pass gate help but don't eliminate this — layering "pipeline decides to fix" on top of "pipeline tries to fix" is a new compound failure mode. Mitigation: require `fix-now` to route through `/ak-implement`'s atomic commit pattern; never allow `fix-now` to skip test verification.

2. **Automated `spec-amendment` is worse.** The pipeline decides "the spec was ambiguous, let me amend it" and edits `spec.md` mid-run. That invalidates earlier agent decisions made against the old spec, may contradict things the user already approved at Phase 0 of /ak-build. Safe design: `spec-amendment` PAUSES and asks the user rather than auto-amending. Which reduces the automation value — you've added ceremony without speed. Probably right to require human confirmation on this disposition specifically.

3. **Opacity vs. transparency.** Today the human reads `review.md` and sees findings + rationales. With Phase 4, many findings auto-route and the human sees "pipeline did X with Y finding." Harder to audit retrospectively ("why did it choose TODO over fix-before-ship?"). The project's strength has been human-in-the-loop visibility; heavy automation here works against that. Mitigation: every routing decision writes an audit-trail entry with the chosen disposition + its rationale, not just the outcome.

4. **Secondary risks**:
   - **Per-gate rule drift** — six+ mapping functions (one per wired gate) that can subtly differ over time without shared conventions. Mitigation: a shared `kit/scripts/finding-router-rules/_common.sh` for severity-agnostic logic; per-gate files only hold gate-specific mappings.
   - **Regression surface** — if Phase 4 code has bugs, it can block pipelines Phase 3 handles fine. Mitigation: feature-flag per-gate wiring so each gate's router can be disabled independently; phase-in matches the incremental landing order.
   - **Adversarial-reviewer false-rejection rate** — the disposition plausibility judgment adds a new rejection surface. If the reviewer is too strict, pipelines grind on edge cases. Mitigation: the same `DEVSHOP_SKIP_ADVERSARIAL=1` escape hatch Phase 3 already has.

**Trigger — when to build this**

After v1.16 has been used in anger for a month or two on a real project. The signal to land: a Phase 3 review.md surfaces dismissals with weak rationales that an adversarial reviewer can't cleanly accept or reject because the finding would clearly be `fix-now` / `TODO` / `spec-amendment` if only we had that vocabulary. That's when the current `rationale:`-only vocabulary is hitting its ceiling; Phase 4 unblocks further automation.

**What NOT to do while deferred**

- Don't add ad-hoc `disposition`-like fields to Phase 3's `rationale:` section — that fragments the format before Phase 4 can unify it.
- Don't wire routing for one gate without the reusable `finding-router.sh` substrate — per-gate one-offs are how the devshop would end up with 7 subtly different routing implementations.
- Don't treat deferring this as technical debt. The three landed phases cover the concrete failure modes that motivated the work; Phase 4 is an efficiency / hygiene upgrade for the triage step, not a correctness fix. Current Phase-3 users get adversarial review of rationales; Phase 4 is how routing becomes mechanical after those rationales pile up.

### Git hook symlink recovery (post-checkout / post-merge)

Add husky `post-checkout` and `post-merge` hooks that call
`create-devshop-symlinks.sh` to proactively recreate symlinks after git
operations that can lose them. Currently symlinks are recreated reactively
(at session start and before commits). Proactive recovery would mean
symlinks are restored immediately after `git checkout`, `git merge`, and
`git pull` — no waiting for the next session or commit.

Trigger: after the symlink fragility TODO is resolved (settings.json copy
vs symlink decision), reassess whether proactive recovery is still needed.

### Native/mobile devshop support

Extend the devshop to support React Native (Expo) apps alongside web. Adds `apps/mobile/`,
EAS CLI, Maestro E2E, mobile Sentry/PostHog, App Store/Play Store deployment.
Full build blueprint: `kit/notes/bootstrap/v+-native.md`.

### Fakeowner + Bash bypass hardening

Two known security gaps in the file protection model:

1. **Fakeowner**: Docker Desktop bind mounts from macOS use `fakeowner`, where `chown`/`chmod` are cosmetic — Layer 2 (root ownership) doesn't enforce on these mounts.
2. **Bash bypass**: Edit/Write deny rules don't prevent Bash commands from modifying protected files (e.g., `python3 -c "open('file','w')"`). On fakeowner mounts, root ownership doesn't help either.

**Current protection (v0):**

1. Deny rules in `settings.json` block Edit/Write tools
2. `init-devshop.sh` chowns files to root on container start (cosmetic on fakeowner)

**Known gap:** Bash commands can modify any file on the fakeowner mount regardless of
displayed ownership. Deny rules only cover Edit/Write tools, not Bash.

**Attempted fix: DCG custom block rules** — added `[overrides] block` patterns in
`.dcg.toml` matching protected filenames. Problem: DCG pattern-matches against the full
command string, so `git add .claude/settings.json` and `git commit` mentioning protected
files in messages trigger false positives. DCG's `allow` override precedence vs pack rules
(e.g., `core.git` blocking `git reset --hard`) is undocumented — blanket git allowlisting
might weaken existing protections. Reverted.

**Option A: DCG with surgical patterns** — instead of filename-only patterns, use
write-verb + filename combos (`> .*settings.json`, `tee .*settings.json`, `python.*settings.json`).
Avoids git false positives but requires enumerating all write verbs — misses novel ones
(`dd`, `perl`, `ruby`, `node -e`, etc.). Weaker net than broad filename matching.

**Option B: Symlink to ext4 volume** — move protected files to `/home/node/.claude/`
(real ext4 Docker named volume where permissions are kernel-enforced), symlink from
workspace. `init-devshop.sh` copies latest from git → volume target, then
`chown root:root` — kernel enforces it. Real protection, not pattern-matching.
Complexity: lifecycle management (git updates must flow through copy step), container
rebuild vs volume persistence timing, Claude Code must follow symlinks for settings
loading (likely works, untested).

**Option C: Custom PreToolUse hook** — a bash script (not DCG) that parses the command
from stdin JSON and checks if it would write to protected paths. More flexible than DCG
patterns, can do path resolution, but same fundamental limitation: pattern matching is
bypassable with sufficient creativity.

**Trigger:** When a Bash bypass is observed in practice (not just theoretical).

### Symlink replacement protection

The `.devshopkit` symlink (and other injected symlinks like `.claude/commands`,
`.claude/skills/*`) are node-owned and have no deny rules. A single `mv` command
(which is in the Bash allow list) could replace `.devshopkit` with a symlink to an
attacker-controlled directory. All guard scripts (`bash kit/scripts/...`)
and PreToolUse hooks would then execute from the new target.

**Current mitigations:**

1. `create-devshop-symlinks.sh` recovers symlinks at pre-commit and session start
2. Detection window is one tool call (the next PreToolUse hook fires from the wrong location)
3. `ln` is not in the Bash allow list — only `mv` could replace a symlink without prompt

**Why not fixed now:** The attack requires `mv` (allowed), has a one-tool-call
detection window, and self-heals at the next checkpoint. Practical risk is low.

**Options when hardening:**

- PreToolUse hook that validates `.devshopkit` symlink target before executing any
  command that references `kit/` paths
- Integrity check in DCG that verifies symlink targets haven't changed
- Root-owned wrapper script at a fixed path (not a symlink) that hooks call
  instead of relying on the `.devshopkit` symlink path

**Trigger:** When a symlink replacement is observed in practice, or when
hardening the Bash bypass gap (above) — both share the same attack surface.

### CI slow job expansion

The `slow` job in `.github/workflows/ci.yml` is commented out at scaffold time. It gets
built incrementally, tied to feature milestones. Each expansion lands in the same PR as the
code it tests — no gap between "tests exist" and "CI runs them."

**Trigger 1: First DB-backed feature** (e.g., auth, data queries):

Uncomment the `slow:` job in `.github/workflows/ci.yml`. The template stub already ships the canonical shape:

- `supabase/setup-cli` step + `supabase start` (GitHub Actions has native Docker — no DinD)
- The lalista-PR-26 `supabase_edge_runtime` health-check retry loop (preserve it; don't strip)
- `scripts/ci-type-drift.sh` — regenerates `packages/core/src/supabase.types.ts` against the local stack and fails on drift (helper ships in `template/scripts/`; copied verbatim into every project)
- `scripts/ci-rollback-explain.sh` — for each migration with `-- ROLLBACK:`, applies the rollback then re-applies forward (round-trip), catching syntax errors before they bite during a real outage (also ships in `template/scripts/`)

Per-project wiring (the only operator-facing work):

- Add `SUPABASE_SERVICE_ROLE_KEY` to CI Variables — value is the local-stack default JWT (published; same value across every Supabase install). Per the security-posture cleanup, prod service-role NEVER goes here.
- Add `ANTHROPIC_API_KEY_QA` to CI Secrets if edge functions call Claude — re-exported as `ANTHROPIC_API_KEY` inside the test step's env block. `ANTHROPIC_API_KEY_PROD` is unrelated to CI; it's pushed to Supabase by `deploy-functions.yml`.
- Update branch protection to require `slow` alongside `fast`.

Full lifecycle convention (when the threshold is crossed, structural enforcement, codified prior art): `kit/docs/guide/conventions.md § Slow-Job Lifecycle`. The `/ak-pre-ship` gate `slow-job-lifecycle` (fires when `*.integration.test.ts` or `apps/web/e2e/*.spec.ts` exists) catches misconfigurations: stub still commented, wrong `if:` predicate, retry pattern stripped, branch protection missing, slow-job runs zero tests.

**Trigger 2: First E2E-testable flow** (e.g., sign-in → core action → verify):

Add to the `slow` job:

- Install browsers: `npx playwright install --with-deps chromium`
- Build and start app: `pnpm turbo run build --filter apps/web` then `npx next start` against local Supabase
- Run E2E at both viewports: `npx playwright test --project=mobile --project=desktop`
- Upload trace artifacts on failure via `actions/upload-artifact` for debugging
- Cache Playwright browsers using lockfile hash

**Additional secrets for slow job**: `SUPABASE_SERVICE_ROLE_KEY` (integration tests need admin access) and `ANTHROPIC_API_KEY_QA` (if edge function integration tests call Anthropic — re-exported as `ANTHROPIC_API_KEY` inside the integration-test step's env block; the canonical name stays inside the function process). Add to GitHub Secrets when wiring up the slow job. The corresponding prod-traffic key (`ANTHROPIC_API_KEY_PROD`) is unrelated to slow-job — it's pushed to Supabase by `deploy-functions.yml` for real-user runtime.

**After both expansions**: update branch protection to require `slow` as a required status check alongside `fast`.

**Caching** (both jobs): pnpm store (`actions/cache`), Turborepo outputs, Playwright browsers. Cache keys use lockfile hash.

**Expected CI minutes**: ~260 min/month for 10 PRs (20 fast jobs × 4 min + 10 slow jobs × 15 min). GitHub Actions free tier: 2000 min/month.

### Backend alternatives and self-hosting evaluation

Evaluate alternatives to Supabase hosted for cost-conscious multi-project use:

- **Neon + Auth.js + Vercel functions**: free database branching, $0/mo, medium assembly
- **Self-hosted Supabase via Coolify + Hetzner**: ~€15/mo for multiple projects, higher ops burden
- **Backend-agnostic init**: `/ak-init` asks which backend and wires accordingly

Trigger: when monthly Supabase bills exceed ~€15/mo across projects, or when
staging/branching becomes a real bottleneck.

Full research: `kit/notes/backend-alternatives-research.md`

### `/rollback` skill

Dedicated skill that: reverts Vercel deployment (`vercel rollback`), warns about
migration state, walks through manual data recovery. Build when you've had your
first production incident and know what the workflow should actually be.

### Visual regression testing

Playwright screenshot comparison for key screens. Store baseline screenshots in
`tests/screenshots/`. CI step compares current vs baseline, fails if diff exceeds
threshold. Catches unintended visual changes that unit tests miss.

### Test-impact analysis (TIA) — runtime-instrumented test selection

Real TIA platforms (Gradle Enterprise, Datadog Test Optimization, NCrunch, Bazel's `bazel test --runs_per_test`-style pruning) instrument test runs to record which production code each test actually exercises, store the mapping in a coverage database, then on a diff re-run only tests whose recorded coverage intersects the changed lines. The precise version of `/ak-pre-ship`'s `changed-tests-local (ak)` gate's heuristic layers (smoke set + path-pattern map + import-graph match) — a heuristic catches what filename + reference-graph traversal can find; TIA catches what the code actually executed.

The heuristics are an approximation that doesn't require infra. TIA requires:

- A runtime instrumentation hook (Istanbul / V8 coverage / Playwright's coverage API) wired into every test run.
- A coverage database keyed on test ID × file:line (per-commit or per-test-suite).
- A diff-resolver that maps changed lines back to test IDs, with cache invalidation when test files themselves change.
- A "first-run-after-test-change" path that runs the changed test fresh (no recorded coverage yet).

**When to revisit.** Move to TIA only if the heuristic layers' false-negative rate becomes painful — e.g., a project ships a behavior bug that would have been caught by a spec the heuristics missed but TIA would have surfaced. Until that happens, the heuristics are the right cost/benefit point: zero infra, false positives only cost wallclock, false negatives are caught by CI.

**Cost/risk.** Multi-week build (instrumentation + DB + resolver + cache invalidation + project-template wiring + BATS coverage). Risk: instrumentation overhead can be 10–30% per test run depending on the engine; coverage-DB drift if test files refactor without invalidation. Mitigation — TIA platforms run in-process; cost is amortized across the savings on subsequent runs.

Source: queued by abra-kadabra PR #27 (was an "out of scope" bullet on the cheap-test-gates source v1 entry that PR #27 deletes; promoted to v+ here per operator direction — no current need, theoretical upper bound on what cheap-test-gates can become).

### `/ak-migrate-project` skill

Skeleton exists (`.claude/skills/devshop/migrate-project/SKILL.md`). Two tiers:

- **Lightweight (same stack)**: existing Node/Next.js project, just needs devshop
  tooling. Merge configs (`.prettierrc`, `eslint.config.mjs`, `tsconfig.base.json`,
  etc.) instead of replacing, create/adapt `.devcontainer/`, skip N/A steps
  (no Supabase, no PostHog, etc.), don't delete existing `apps/`/`packages/`.
- **Full (different stack)**: migration from another framework (e.g., Swift → React,
  Django → Next.js). Archive old code for reference, port design system, set up
  backend integration, rebuild screens, full test pass.

`/ak-init` assumes a fresh template clone. `/ak-migrate` handles the cases where
that assumption doesn't hold. Reference: Phase 1 execution in
`kit/notes/bootstrap/v0-web.md` as the first data point for parametrization.

Trigger: when a second project needs to adopt the devshop.

### Parallel implementation loops via worktrees

Two `/implement` sessions running simultaneously on different features using
git worktrees (separate working directories, each on its own branch).

**What it would achieve**: True parallel feature development. Two Claude Code
sessions, each with its own worktree, spec, and task list. Merge when both
are done.

**What it would require**: Worktree management tooling, resource budget (two
sessions + potentially two local Supabase instances), merge conflict strategy
for shared files (tokens.ts, shared components), and a way to coordinate
when both features touch the same package.

**When to build**: When single-loop development feels like a bottleneck — likely
when the app has 10+ screens and features can be cleanly isolated.

### Auto-trigger `/go-live` on PR approval

Currently: user approves PR on GitHub, comes back to terminal, says `/go-live`.
Goal: approving the PR on GitHub automatically triggers merge + deploy + canary +
reflection — no manual second step.

Options to explore: GitHub Actions on `pull_request_review` (approved) that calls
Claude Code remotely, or GitHub auto-merge + a webhook/scheduled agent that detects
newly merged PRs and runs the post-merge pipeline. Lightest option may be GitHub
auto-merge (PR merges when CI passes + approved) combined with a deploy workflow
that runs canary checks — but loses Claude's structured reflection step.

### Devshop testing

Test infrastructure for the devshop itself — scripts, hooks, and sync tooling.
Currently the devshop has no automated tests; correctness relies on manual
verification during use.

#### Hook tests (commit guard)

Automated tests for `commit-guard.sh` and other commit hooks. Set up
temp git repos, stage specific file combinations, and assert correct blocking
behavior. Key invariant: **no auto-pass** — checks must never silently pass
because the "right" files happen to be co-staged. Every blocking check must
require an explicit reason, regardless of what else is in the commit.

Test cases: mixed commit detection (project repo only), docs drift with/without
co-staged docs, doc consistency with 1/2/3 docs staged, bypass flag parsing
from stdin JSON, exit code 2 on failure, repo detection.

#### Sync script tests

Tests for `sync-from-devshop.sh` and `sync-to-devshop.sh`. Create two temp
repos, run sync in both directions, verify correct files copied and exclusions
honored.

#### init-devshop.sh tests

Verify symlinks created, security lockdown applied, BUILD-LOG.md created when
missing, skill symlinks resolve.

### Structured logging for edge functions

Sentry catches crashes. PostHog tracks user actions. Gap: application-level
operational logging. When a user reports "my item didn't appear," you need edge
function logs, query timing, auth flow steps. Supabase has logging but it's not
structured or correlated with user-facing issues.

Consider structured console.log in edge functions with a standard format
(timestamp, request ID, user ID, action, duration). Revisit after first
production debugging session reveals what's actually needed.

### ~~Repo layout clarification~~ — RESOLVED

Resolved: created `template/` directory at devshop root containing the project
skeleton. Root simplified to devshop-only needs (no turbo, no pnpm-workspace).
`init-devshop.sh` moved to `kit/scripts/`. `/ak-init` replaced by
`/ak-new-project` (two-phase: create repo + setup) and `/ak-migrate-project`
(skeleton). Init checklist moved from GUIDE.md to per-project `INIT-TRACKER.md`.

### Standalone devcontainer for abra-kadabra

Open the abra-kadabra repo directly in a devcontainer for devshop-only work — no
project repo required. Currently the devcontainer assumes a project repo at
`/workspace`; opening abra-kadabra alone leaves `/workspace` empty and
`init-devshop.sh` fails.

Add a second devcontainer profile (e.g., `.devcontainer/devshop-only/`) that
mounts abra-kadabra as the workspace, skips project injection, and provides a
working Claude Code environment for editing devshop scripts, skills, docs, and
GUIDE.md without needing a sibling project repo.

Trigger: when devshop-only work sessions become frequent enough to justify the
setup.

Related: the devshop's root `CLAUDE.md` contains conventions that span both
devshop and project work (e.g., metrics, responsive, edge function rules). In
devshop-only sessions those project-oriented sections are harmless noise, but
over time consider splitting into universal devshop conventions vs.
project-template conventions — or just accepting the noise as low-cost.

### CODEOWNERS + branch protection

Add `CODEOWNERS` to both repos requiring review approval for changes to
`.devshopkit/`, `.claude/`, `.devcontainer/`, and hook files. Pair with GitHub
branch protection on `main` (require PR reviews, block direct pushes).

Currently all guards are local (hooks, file ownership, deny lists). A force
push to main bypasses everything. CODEOWNERS + branch protection adds
server-side enforcement that survives local bypass.

Not needed for solo development — the local guards handle the actual threat
model (Claude bypassing checks). Becomes relevant when a second contributor
joins or when the devshop is used across multiple projects with different
maintainers.

Trigger: when a second human contributor needs commit access.

### DNS wildcard firewall rules

Current firewall resolves each domain to IPs via `dig` + `ipset`. Every subdomain
needs its own entry (e.g., `sentry.io` and `o123456.ingest.sentry.io` resolve to
different IPs). This works but means more entries to maintain per project.

Alternative: use a DNS-aware proxy (e.g., `squid` or `dnsmasq` with filtering) that
supports wildcards like `*.supabase.co`. Fewer entries, survives subdomain changes.
Trade-off: adds a proxy process and config — more moving parts than the current
plain `iptables` + `ipset` approach.

Trigger: when the firewall domain list grows unwieldy across multiple projects.

### Self-correcting workflow patterns

The 2026-04-18 hook architecture migration (`kit/notes/roadmap/hook-migration-plan.md`) moved
workflow nudges from `PostToolUse Bash` (audience-confused, fires in subagents) to
the husky pre-push layer (agent-agnostic, blocking with adversarial review). That
fix solves the audience problem and strengthens enforcement, but it preserves the
existing pattern: hooks DETECT a problem, AGENT/HUMAN must ACT on it.

The deeper architectural reframe — deferred to v+ — is **self-correcting workflow**:
hooks (or skills) take the action themselves, with the agent/human just confirming
substantive decisions. Examples:

- **Auto-update PR description**: pre-push hook detects staleness, regenerates
  description from commit log via `gh pr edit`, asks user to confirm only if the
  diff is substantive (renames, removals, scope changes). Trivial appends auto-apply.
- **Auto-stage leftover files**: post-commit detects untracked/unstaged files, asks
  "stage these as a follow-up commit?" with one-key confirmation. Cleaner than
  warning + agent-must-remember.
- **Auto-invoke `/ak-release-devshop`**: post-merge to abra-kadabra `main` with
  `feat:`/`fix:` commits → automatically suggest the release skill via skill chain.
- **Auto-stash on dirty session start**: SessionStart detects WIP from prior session,
  offers to stash it under a labeled stash so the new session starts clean. Reversible
  via `git stash pop`.

**Why deferred from the 2026-04-18 migration**: each pattern is its own design
decision (substantive-vs-trivial threshold, confirmation flow, reversal-on-error,
edge cases like concurrent edits). Bundling all of them was multi-PR work that would
have delayed PR 3 of the lalista migration. The current adversarial-review pattern
captures most of B's enforcement value (LLM judges the bypass reason) without the
auto-action complexity.

**Why this is worth doing eventually**: the persistent failure mode of "agent
ignores advisory" remains, even with strong adversarial gates. Auto-action removes
the agent-discipline dependency entirely. Particularly valuable for high-frequency
workflow concerns where reading and acting on each warning is a tax.

**Structural concerns to design through**:

1. **Confirmation UX for auto-actions in git hooks**: husky hooks run during git
   operations. Interactive confirmation requires tty/stdin handling that's clunky
   in some shell contexts. Self-correcting actions are more naturally implemented
   in skills (where confirmation flows are first-class) than in pure git hooks.
   May lead to a hybrid: husky detects, signals to next skill invocation to act.
2. **Reversal**: every auto-action needs a clear undo path (`git restore --staged`,
   `git stash pop`, `gh pr edit` to revert description). Design must surface the
   undo at the moment of action.
3. **Substantive-vs-trivial threshold**: "auto-apply trivial, confirm substantive"
   only works if "substantive" is reliably detectable. Likely needs adversarial
   LLM review as the discriminator (matches existing pattern).
4. **Failure modes**: what if `gh pr edit` fails mid-update? What if auto-staging
   stages files the user didn't want? Each auto-action needs failure-safe defaults.

**Trigger**: when the persistent "agent ignores advisory" failure mode is observed
in practice often enough that adversarial-gate enforcement isn't sufficient. Or when
specific auto-action candidates (PR description sync, post-merge release prompts)
become high-frequency enough to justify per-pattern design work.

**Migration path from current**: each candidate auto-action can be implemented
incrementally — no need to do them all at once. Likely first candidate: auto-update
PR description on push (extends the existing pre-push staleness check from "block
with reason" to "regenerate + confirm if substantive").

Related: `kit/notes/roadmap/hook-migration-plan.md` § "Architectural shift" for the
why-not-now rationale.
