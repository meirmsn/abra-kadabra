# Conventions

Tier 3 reference for the devshop's operational conventions. Human-browseable encyclopedia and cross-reference index.

### Convention placement rule

Operational rules live where they fire:

| Tier | Home | Loaded when | Content shape |
| ---- | ---- | ----------- | ------------- |
| 1 | `/devshop/CLAUDE.md` | Every session start | Cross-cutting principles (confidence calibration, TODO protocol, non-negotiables) |
| 2 | Skill `SKILL.md` files | Skill invocation | Skill-specific actions (spec checklist, test assertion depth, deploy surface table) |
| 3 | `kit/docs/guide/**` (this file) | On-demand read/grep | Multi-skill reference, rationale, worked examples, background |

When a section here has a single consuming skill that replicates its content, the **skill copy is canonical**. This file keeps a one-line stub pointing there. When no single skill owns the content (multi-skill lifecycle, reference taxonomy, background rationale), this file is the canonical home.

## Contents

- [Metrics Lifecycle](#metrics-lifecycle)
- [Events](#events)
- [Feature Flags](#feature-flags)
- [TASKS.md Format](#tasksmd-format) — _stub → implement/SKILL.md_
- [SPEC.md Quality Checklist](#specmd-quality-checklist) — _stub → spec/SKILL.md_
- [DESIGN.md as Contract](#designmd-as-contract-design-conformance-ak-gate) — _stub → pre-ship + design-conformance/SKILL.md_
- [Screenshot Routing](#screenshot-routing) — _stub → pre-ship/SKILL.md_
- [Deploy Boundaries](#deploy-boundaries) — _stub → go-live/SKILL.md_
- [Slow-Job Lifecycle](#slow-job-lifecycle)
  - [Why active from day one](#why-active-from-day-one)
  - [Per-step empty-state guards](#per-step-empty-state-guards)
  - [Helper scripts](#helper-scripts)
  - [Extending the active stub](#extending-the-active-stub)
  - [Structural enforcement (regression guard)](#structural-enforcement-regression-guard)
  - [Skip-on-docs-only filter](#skip-on-docs-only-filter)
  - [Codified prior art](#codified-prior-art)
  - [Cross-reference: Local Pre-Push Test Gates](#cross-reference-local-pre-push-test-gates)
- [Local Pre-Push Test Gates](#local-pre-push-test-gates)
- [Long-running processes in the Claude Code harness](#long-running-processes-in-the-claude-code-harness)
- [Supabase Hardening Defaults](#supabase-hardening-defaults) — _moved to [`migrations.md`](./migrations.md)_
- [Runtime Validation at LLM / Edge-Function Boundaries](#runtime-validation-at-llm--edge-function-boundaries) — _moved to [`wrapper-boundaries.md`](./wrapper-boundaries.md)_
- [Wrapper API design](#wrapper-api-design) — _moved to [`wrapper-boundaries.md`](./wrapper-boundaries.md)_
- [Database queries](#database-queries) — _moved to [`database-queries.md`](./database-queries.md)_
- [Confidence Calibration](#confidence-calibration)
- [TODO Protocol](#todo-protocol) — _stub → CLAUDE.md_
- [Backlog Routing Guide](#backlog-routing-guide) — _stub → CLAUDE.md § TODO Protocol_
- [Commit + PR Text Style](#commit--pr-text-style)
- [Existing-Project Migration Block](#existing-project-migration-block)
- [Non-Negotiables](#non-negotiables)
  - [Testing](#testing)
  - [Test Assertion Depth](#test-assertion-depth) — _stub → tests-review/SKILL.md_
  - [Playwright + controlled inputs on WebKit](#playwright--controlled-inputs-on-webkit)
  - [Supabase auth E2E patterns](#supabase-auth-e2e-patterns)
  - [Testing Lifecycle](#testing-lifecycle) — _stub → implement/SKILL.md_
  - [Kit Testing (devshop infrastructure)](#kit-testing-devshop-infrastructure)
  - [Metrics](#metrics-1)
  - [Responsive + Theme](#responsive--theme)
  - [PWA](#pwa)
  - [Code Structure](#code-structure)
- [Test Presence](#test-presence)
- [Project Docs Coverage](#project-docs-coverage)
- [Bypass trailers](#bypass-trailers)
- [Exempt-File Additions](#exempt-file-additions)
- [Project Docs Hierarchy](#project-docs-hierarchy)

## Metrics Lifecycle

Metrics flow through the devshop at four points:

1. **`/ak-spec` creates `METRICS.md`** on first run — drafts taxonomy from autoplan output, asks user to confirm. On subsequent runs: proposes new events when features introduce new user actions. New event definitions are always a "stop and ask" item.
2. **`/ak-implement` instruments** — `posthog.capture()` calls for events referenced in the spec's Metrics section. Instrumented alongside code, never after.
3. **`/ak-pre-ship` validates** — cross-references user-facing code against `METRICS.md`. Pauses if a user-facing PR is missing instrumentation.
4. **You confirm new events** — never auto-added without review.

### Metrics principles (for drafting/updating `METRICS.md`)

1. Every event must answer a question you'd act on. Can't name the decision? Don't track it.
2. Track outcomes, not clicks. Prefer `item_added` over `add_button_clicked`. Exception: funnel drop-off needs start + end events.
3. One event per user intent, not per UI element. Multiple paths to same action = one event with a `method` property.
4. Properties carry context, not event names. Stable names, filterable properties.
5. Error events must include enough to reproduce: `error_type`, `screen`, `user_action_before`.
6. Instrument boundaries, not internals. Entry/exit of flows, not every state. Internals are for logs.
7. Start sparse, add when you have questions. Launch with 5-10 events covering core flows.

### `METRICS.md` structure

```markdown
# Metrics

## Events

| Event | When it fires | Key properties | Why we care |
| ----- | ------------- | -------------- | ----------- |

## Feature Flags

| Flag | Controls | Default |
| ---- | -------- | ------- |
```

## TASKS.md Format

Owned by `/ak-implement` — see `.claude/skills/devshop/implement/SKILL.md` for the task format template and resume pattern.

## SPEC.md Quality Checklist

Owned by `/ak-spec` — see `.claude/skills/devshop/spec/SKILL.md § Quality checklist` for the full checklist.

## DESIGN.md as Contract (`design-conformance` (ak) gate)

Owned by `/ak-pre-ship` — see `.claude/skills/devshop/pre-ship/SKILL.md § Gate design-conformance` and `.claude/skills/devshop/design-conformance/SKILL.md` for claim types, caching, extraction prompt, and outcome semantics.

## Screenshot Routing

Owned by `/ak-pre-ship` — see `.claude/skills/devshop/pre-ship/SKILL.md § Screenshot Routing` for the location table and decision flow.

**Gitignore enforcement of the table.** `template/.gitignore` ships both `specs/*/screenshots/` and `specs/*/qa-walk/` as exclusion patterns — the table's "❌ Tracked?" rows are enforced at the file-system level, not just documented. `kit/tests/structural-invariants.bats § wiring: template .gitignore matches Screenshot Routing convention` asserts both lines are present so a future template refactor can't silently drop the exclusion. Regression context: `specs/*/screenshots/` was missing from the template through 2026-05-22 — projects added it locally and lost it on first `from-devshop.sh` sync.

## Deploy Boundaries

Owned by `/ak-go-live` — see `.claude/skills/devshop/go-live/SKILL.md § Deploy surfaces` for the surface table, schema-mutation safety, rollback semantics, and CI-vs-prod credential separation.

## Slow-Job Lifecycle

CI's `slow:` job is the home for tests that need a real Supabase stack: integration tests (`*.integration.test.ts` reading the local stack via `VITEST_INTEGRATION=1`), Playwright E2E specs (`apps/web/e2e/*.spec.ts`), type-drift validation (`scripts/ci-type-drift.sh`), rollback round-trip checks (`scripts/ci-rollback-explain.sh`), and edge-function deploys against the local stack. The `fast:` job is unit tests + lint + typecheck + build — no DB, no functions, no headless browser.

**Slow-job ships ACTIVE from day one** (since the template-ci-overhaul branch, 2026-05-19). Brand-new projects with zero migrations and zero E2E specs short-circuit via per-step `if: hashFiles(...) != ''` guards: no `supabase/migrations/*.sql` → skip type-drift + rollback round-trip; no `apps/web/e2e/**/*.spec.ts` → skip Playwright install + build + run. The `Start local Supabase` step runs unconditionally as ambient health signal, so the slow-job completes in ~30s on a fresh scaffold and grows naturally as content lands — no Phase 1c / 1g threshold flip, no operator-memory dependency, no skill-prose handoff.

### Why active from day one

The pre-2026-05-19 model shipped the slow-job commented out and required the spec adding the project's first integration test or Playwright spec to uncomment it. The model didn't survive contact with the build loop: three consecutive home-os PRs (PR #9 RLS-isolation, PR #10 magic-link, PR #15 capture-flow) crossed the threshold without flipping the stub. Each pre-ship raised `Gate 2c findings_pending`, each PR shipped with the finding as "infra carry-over," each next PR inherited the gap. Root cause: the devcontainer PAT lacks `workflow` scope, so the agent cannot push `.github/workflows/**` changes; the task gets routed to the human operator and persists. Shipping the slow-job active from the template removes the routing problem entirely — the first PR that lands an integration test or E2E spec is gated by CI automatically, no operator action.

### Per-step empty-state guards

The slow-job's heavy steps gate on file existence via GitHub Actions' `hashFiles(<glob>) != ''` predicate:

| Step                            | Guard                                                       | Why                                                                                                                                                                                                                  |
| ------------------------------- | ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Install Playwright browsers     | `hashFiles('apps/web/e2e/**/*.spec.ts') != ''`              | Brand-new projects with zero E2E specs don't need Playwright browsers (saves ~3 min on the first PR).                                                                                                                |
| Schema type-drift check         | `hashFiles('supabase/migrations/*.sql') != ''`              | `scripts/ci-type-drift.sh` diffs `packages/core/src/supabase.types.ts` against the live schema; the template ships a placeholder types file that diff-fails against an empty schema until the first migration lands. |
| Migration rollback round-trip   | `hashFiles('supabase/migrations/*.sql') != ''`              | `scripts/ci-rollback-explain.sh` errors when `supabase/migrations/` doesn't exist as a directory; brand-new projects don't have one.                                                                                 |
| Build web app for E2E           | `hashFiles('apps/web/e2e/**/*.spec.ts') != ''`              | No specs → no need to build the production bundle. Same gate as the Playwright install + run steps so the trio fires together.                                                                                       |
| Start next + run Playwright E2E | `hashFiles('apps/web/e2e/**/*.spec.ts') != ''`              | The actual run step.                                                                                                                                                                                                 |
| Upload Playwright traces        | `failure() && hashFiles('apps/web/e2e/**/*.spec.ts') != ''` | Belt-and-braces; traces only exist when Playwright ran.                                                                                                                                                              |
| **Start local Supabase**        | **(unguarded — ambient signal)**                            | Heartbeat that proves CI plumbing is wired (firewall, supabase/setup-cli, networking, edge-runtime container) on every PR — even before the project has any real content.                                            |

### Helper scripts

The slow-job invokes two helpers from `scripts/` that the template ships:

- **`scripts/ci-type-drift.sh`** — regenerates `packages/core/src/supabase.types.ts` against the local stack and fails on drift. Catches the failure mode where a migration changes column nullability / FKs / RPC signatures and the committed types weren't regenerated.
- **`scripts/ci-rollback-explain.sh`** — for every migration, applies the rollback against the local DB then re-applies the forward migration. Catches rollback-block syntax errors before they bite during a real outage. **Every migration MUST carry a `-- ROLLBACK:` marker** — the script FAILs loudly on any markerless or empty-bodied migration with a recipe pointing the operator at this entry. The mandate exists because earlier migrations' rollbacks (notably the `drop table` rollback of the foundational `002_tables.sql`) cascade-drop columns added by markerless downstream migrations; without a marker the script previously SKIPped and the cascade-dropped column stayed gone for the rest of CI. Net effect after a silent skip: the DB no longer has the column, `supabase gen types` introspects fresh-from-DB and silently removes the property, and PostgREST returns PGRST204 on every request that names it. The forward must be idempotent (`add column if not exists` + `create index if not exists`) so the rollback+forward cycle restores the column after upstream cascades. Migrations with nothing to undo (data-only, idempotent forward) can carry a single body line `-- noop: forward is idempotent`; the script detects `noop:` and skips the rollback apply step but still re-applies forward, which is what closes the cascade-loss hole. Codified after a 6-attempt CI fix-loop where every speculative fix targeted "PostgREST cache staleness" while the root cause was a missing marker. PGRST204 in CI is almost always a downstream symptom of a missing column, NOT a cache issue — disambiguate by querying `information_schema.columns` via psql before reaching for `notify pgrst`.

Both helpers gate on `hashFiles('supabase/migrations/*.sql') != ''` so they're skipped cleanly on brand-new projects. Both are project-agnostic — copied verbatim from the template into every project; no per-project tuning expected.

### Extending the active stub

When a project adds its first integration test or Playwright E2E spec, the slow-job picks it up automatically — no operator action required. Things that DO require an explicit edit:

- **New env vars** — if a slow-job step needs a credential not currently in the slow-job's `env:` block (e.g., `ANTHROPIC_API_KEY_QA` re-exported as `ANTHROPIC_API_KEY` for an edge function that calls Claude), add it at step level. Never wire `ANTHROPIC_API_KEY_PROD` — CI runs against the local stack and must not burn prod billing. See `/ak-new-project § Security Posture` for the QA/PROD rationale.
- **Test glob diverges from `apps/web/test:e2e`** — the template stub invokes `pnpm --filter apps/web test:e2e`. If a project's E2E entry point differs (different package, different script name), update the invocation.
- **New helper script** — if the spec adds a new `scripts/ci-*.sh` helper, register it as a slow-job step. Match the existing pattern (`hashFiles()` guard if it's content-dependent; unguarded if it's pure CI plumbing).

### Structural enforcement (regression guard)

`/ak-pre-ship` runs a `slow-job-lifecycle` gate to verify the active stub didn't get re-commented or hollowed out. Unlike the pre-2026-05-19 conditional gate, this fires on **every** project — the active stub IS the invariant, not "must-flip-once-threshold-crossed." The gate asserts:

1. The `slow:` job in `.github/workflows/ci.yml` is active (uncommented).
2. The `changes:` job is also active (the slow-job's `needs: [fast, changes]` would dangle otherwise).
3. The slow-job's `if:` predicate matches `github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'`.
4. The `supabase start` health-check retry is wired (compare against the template-shipped reference).
5. The per-step empty-state guards are present: `hashFiles('apps/web/e2e/**/*.spec.ts') != ''` on the Playwright steps, `hashFiles('supabase/migrations/*.sql') != ''` on type-drift + rollback.
6. The `Start local Supabase` step has NO `hashFiles` guard (it's the ambient health signal — if a future tidy-up PR adds one, brand-new projects lose the heartbeat).
7. Branch protection contexts include `slow` (so a PR can't merge with the slow-job red).

Block-on-failure with a remediation message pointing at this section.

### Skip-on-docs-only filter

Docs-only PRs (typo fixes, plan updates, ROADMAP edits) shouldn't burn the 8–10 min slow-job. The convention is a tiny `changes:` setup-job that classifies the diff and exposes `runtime: 'true'/'false'` as a job output; the slow-job's `needs:` includes `changes` and its `if:` consumes the runtime gate. Both jobs ship active in the template; the wiring is part of the day-one shape, not a flip-on-threshold add-on.

**Shape** — single workflow file, two jobs wired together:

```yaml
changes:
  runs-on: ubuntu-latest
  outputs:
    runtime: ${{ steps.classify.outputs.runtime }}
  steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0 # required for `git diff base.sha...HEAD`
    - id: classify
      run: |
        set -euo pipefail
        changed_files=$(git diff --name-only "${{ github.event.pull_request.base.sha }}...HEAD" || true)
        # Empty diff → runtime=true (safer default — run slow-job rather than silently skip).
        [ -z "$changed_files" ] && { echo "runtime=true" >> "$GITHUB_OUTPUT"; exit 0; }
        # `*.md` (not `**/*.md`): inside `case`, `*` already matches `/`, so
        # `*.md` covers both root (`CLAUDE.md`) and nested (`apps/web/README.md`).
        # `**/*.md` in `case` behaves like `*/*.md` and misses root files —
        # `shopt -s globstar` only affects pathname expansion, not `case`.
        runtime=false
        while IFS= read -r path; do
          [ -z "$path" ] && continue
          case "$path" in
            *.md) ;;
            specs/**) ;;
            PLAN.md) ;;
            BUILD-LOG.md) ;;
            TODOS.md) ;;
            .gstack/**) ;;
            .devshop/**) ;;
            *) runtime=true; break ;;
          esac
        done <<< "$changed_files"
        echo "runtime=$runtime" >> "$GITHUB_OUTPUT"

slow:
  if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'
  runs-on: ubuntu-latest
  needs: [fast, changes]
  # ...
```

**Ignore list** — a diff is "docs-only" iff every changed file matches one of these patterns (bash `case` patterns, NOT shell globs). The list is canonical (don't rearrange without spec'ing it):

- `*.md`
- `specs/**`
- `PLAN.md`
- `BUILD-LOG.md`
- `TODOS.md`
- `.gstack/**`
- `.devshop/**`

`*.md` already structurally covers the named `*.md` files (in `case`, `*` matches `/`); the explicit names are kept for reader clarity and to defend against a future YAML refactor that drops the broad pattern.

**Do not "tidy up" the markdown arm into a doublestar pattern.** Bash `case` is pattern matching, not pathname expansion: `*` already matches `/` inside `case`, so `*.md` covers both `CLAUDE.md` and `apps/web/README.md`. `**/*.md` in `case` behaves like `*/*.md` and fails to match root-level markdown — `shopt -s globstar` only affects globbing for filename expansion, not `case` semantics. Lalista hit this regression on PR #63 (2026-05-12): a `CLAUDE.md`-only PR ran the full slow-job because the root file fell through to the default arm. (Why this sentence is split off as its own paragraph and why the bold span contains no asterisks: prettier's emphasis tokenizer disambiguates by rewriting nested `*` to `_` when a paragraph contains both a `**…**` bold span AND an inline-code fragment like `**/*.md`. Keeping the bold span asterisk-free + putting the asterisk-rich prose in its own paragraph is the only durable defense — see commit `289e6ef` for what happens otherwise.)

**Why a `changes:` setup-job and not job-level `paths-ignore:`** — `paths-ignore` is invalid at job level. `actionlint v1.7.7` rejects it: `unexpected key "paths-ignore" for "job" section. expected one of "concurrency", "container", "continue-on-error", "defaults", "env", "environment", "if", "name", "needs", "outputs", "permissions", "runs-on", "secrets", "services", "steps", "strategy", "timeout-minutes", "uses", "with"`. `paths-ignore` is a workflow-trigger key only (under `on.pull_request.paths-ignore` or `on.push.paths-ignore`). The two alternatives — `dorny/paths-filter@v3` (third-party action dependency for one feature) and splitting into `ci-fast.yml` + `ci-slow.yml` (every adopting project would need to update branch-protection contexts) — both have larger blast radius than 15 lines of inline bash.

**Branch-protection contract** — when the diff is docs-only, GitHub Actions reports the slow-job status as `skipped`. Per [GitHub's documented behavior](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging) on required status checks, a `skipped` status is treated as `success` for branch-protection — the PR is mergeable without operator intervention. The `changes:` job is intentionally NOT a required context (it always succeeds, in ~5s); gating happens via the slow-job's `if:`. This is the load-bearing assumption: if GitHub ever changes this behavior or branch protection is configured with the stricter "Require all jobs to be successful" mode, the fallback is `if: always() && (github.event_name != 'pull_request' || needs.changes.outputs.runtime == 'true')` — but don't pre-emptively flip; the documented behavior is the contract.

**Forward verification** — local `actionlint` only validates YAML shape, not the runtime classify behavior. The first docs-only PR on a fresh project is the live test: open the PR's checks panel and confirm the slow-job shows `skipped`. A trivial PLAN.md edit suffices.

### Codified prior art

Lalista is the prior art — its slow-job carries the edge-runtime retry pattern that PR 26 (2026-04-26) hard-won during a real CI flake. Without the retry, the `supabase_edge_runtime_workspace` container's occasional cold-start 502 fails the entire run on a transient infra issue. The retry adds ~30s in the unhappy path and zero in the happy path. The convention propagates this pattern by default to every devshop project rather than letting each one re-discover it after their own PR-26-style incident.

### Template propagation nudge

Project commits that touch `[sync]`-tagged manifest entries (`.github/workflows/`, `.husky/`, `turbo.json`, `eslint.config.mjs`, `.gitleaks.toml`, etc.) get a one-line per-file nudge after all blocking guards pass, surfacing the matching `template/<path>` and suggesting `to-devshop.sh` for the propagation. Soft nudge only — never blocks, since `[sync]` is explicitly "may diverge." The home-os PR #15 ci.yml fixes are the case study: they lived in lalista pre-existing and home-os newly-debugged for a month before getting back to the devshop template. The manifest already encodes the bidirectional intent; the nudge surfaces it at the moment the operator could actually act on it. See `kit/docs/guide/hooks.md § Full Hook Chain Detail` — the `check-template-propagation.sh` row — for the mechanic.

The nudge fires on `[sync]` only, never on `[scaffold-once]` (intentionally project-owned after first scaffold — e.g. `CLAUDE.md`, `PLAN.md`, `BUILD-LOG.md`), never on `[symlink]` (auto-propagates by definition), never on `[locked]` (project can't stage edits to root-owned files). Honors `!`-exclusions like `.devcontainer/.env`.

### Cross-reference: Local Pre-Push Test Gates

The slow-job is the upper layer of the test discipline. The lower layer is the local-floor gate `changed-tests-local` (#2f in `/ak-pre-ship`, Layer 2 of `/preflight`) — see the next section for the convention. The two layers are complementary, not redundant: local fires on a strict subset (parse-check + changed specs + smoke set, ~5 min total) so a developer discovers the cheap failures 30s before pushing. CI's slow-job runs the full multi-viewport / multi-project matrix, on which the local floor depends for everything outside the cheap subset. Set `git config devshop.requireHealthyLocalStack never` to opt out of the local floor's degraded-stack promotion if a project legitimately can't run a local stack.

## Local Pre-Push Test Gates

A devshop-side gate that runs the cheap halves of integration + E2E test execution locally so a developer discovers a broken Playwright spec or a degraded local Supabase stack 30 seconds before pushing instead of 8–10 minutes after. CI's slow-job (above) still runs the full matrix; this gate is the early-warning floor. Lives at `kit/scripts/preship/changed-tests-local.sh`, surfaced as `/ak-pre-ship` Gate `changed-tests-local (ak)` at #2f (the matching Layer 1 `fast-job-local` gate at #2d runs lint/typecheck/unit/build ahead of it; together they are the standalone `/preflight` skill).

### Smoke-set convention (`*-qa-walk.spec.ts`)

The smoke set is convention-based, not config-driven. The gate runs the union of two globs at the project repo root:

- `apps/web/e2e/*-qa-walk.spec.ts`
- `apps/web/e2e/qa-walk.spec.ts`

A spec named `*-qa-walk.spec.ts` is by convention a fast happy-path walk that exercises a primary user verb without setup-heavy fixtures. Lalista already adopted the convention organically (4 specs as of 2026-05-06: `core-flows-qa-walk.spec.ts`, `disambig-add-new-hero-qa-walk.spec.ts`, `qa-walk.spec.ts`, `ci-slow-job-qa-walk.spec.ts`). Other projects adopt by renaming. A project that doesn't follow the convention gets no smoke set from this gate; an explicit per-project `.devshop/test-impact.json` is the deferred sub-fix-2 stage 2 (precision layer above the convention floor).

### Stack-needing path classifier (`path-classifier.sh`)

Single source of truth for the question "does this diff need the local Supabase stack to be healthy?" Used both by `changed-tests-local.sh` (for `n/a` scope detection) and by `supabase-bootstrap.sh up` (for the degraded-stack promotion below). Hardcoded glob list:

| Path glob                                      | Classified as     |
| ---------------------------------------------- | ----------------- |
| `apps/**`                                      | stack-needing     |
| `packages/core/**`, `packages/ui/**`           | stack-needing     |
| `**/*.integration.test.ts` (added or modified) | stack-needing     |
| `apps/*/e2e/*.spec.ts` (added or modified)     | stack-needing     |
| `supabase/migrations/**`                       | stack-needing     |
| `supabase/functions/**`                        | stack-needing     |
| Anything else                                  | not stack-needing |

CLI:

```bash
bash kit/scripts/preship/path-classifier.sh classify <path>
bash kit/scripts/preship/path-classifier.sh diff-needs-stack [<base-ref>]
```

### Wallclock budgets

Each step is bounded via the `timeout --kill-after=10s` shell builtin. On hit, the step records the triage line `found N specs; M ran, K deferred to CI` and the gate emits `findings (N) [budget exceeded]`. Defaults (env-overridable):

| Step                              | Budget | Env var                         |
| --------------------------------- | ------ | ------------------------------- |
| Parse-check (`playwright --list`) | 30s    | `PARSE_CHECK_TIMEOUT_S`         |
| Changed E2E execution             | 2 min  | `E2E_CHANGED_TIMEOUT_S`         |
| Changed integration execution     | 1 min  | `INTEGRATION_CHANGED_TIMEOUT_S` |
| Smoke set                         | 2 min  | `SMOKE_SET_TIMEOUT_S`           |
| Combined floor                    | ~5 min | (sum of above)                  |

### Bypass flag (`devshop.localTestSkipReason`)

Set the bypass to short-circuit the gate per-invocation:

```bash
# Set the bypass on the repo (read by the gate body, not by a git hook):
git config devshop.localTestSkipReason "<why these are OK to skip locally>"
# Then re-run /ak-pre-ship; the gate short-circuits after adversarial review.
# To clear: git config --unset devshop.localTestSkipReason
```

Same shape as `devshop.testReviewSkipReason` / `devshop.dirtyPushReason`. The gate invokes adversarial review (check-type `localTestSkipReason`, Sonnet-routed) on the reason. PASS → `pass (skipped — adversarially reviewed)`; FAIL → `findings (1) pending` with the reviewer's verdict on stdout. Reviewer rules:

- **Per-category engagement**: name each test category being skipped + why CI is sufficient for that category.
- **No core-flow dismissal**: skipping the smoke set on a diff that touches the project's primary user verb is categorically NOT acceptable.
- **Plausible follow-up commitment**: if "will fix later" appears, name a specific TODOS.md / ROADMAP entry.
- **No silent-broken-env skips**: "the local stack is broken so I'm skipping" must include either an open issue OR a concrete recipe the operator already tried.

Default REJECT — passes require explicit specificity.

### Preflight integration: `devshop.requireHealthyLocalStack`

`supabase-bootstrap.sh up` (the existing preflight stack-bootstrap helper) reads the same path classifier to decide whether a degraded stack should hard-block or fall back to a legacy advisory. The decision is parameterized via `git config devshop.requireHealthyLocalStack`:

| Value           | Behavior                                                                           |
| --------------- | ---------------------------------------------------------------------------------- |
| _(unset)_       | Same as `when-relevant` (default). Hard-block on stack-needing diffs only.         |
| `when-relevant` | Explicit form. Hard-block on stack-needing diffs; advisory on docs-only.           |
| `never`         | Explicit opt-out. Advisory regardless of diff. For projects without a local stack. |
| `always`        | Aspirational strict. Hard-block on any degraded stack.                             |

The preflight emits one of two stdout tokens:

- `blocked: <reason>` — orchestrator halts the pipeline (today's behavior).
- `pass-with-note: <reason>` — orchestrator continues with the message as advisory.

Fail-safe: if the classifier is missing OR git can't resolve the base ref, the preflight emits `blocked:` (the safer default — better strict than lax when the tool can't decide).

## Long-running processes in the Claude Code harness

Long-running processes spawned via plain `command &` or with `run_in_background=true` get reaped when the foreground Bash tool call exits. Several workflows — `/qa`, `/design-review`, `/benchmark`, `/canary`, multi-call Playwright debugging — need a dev server (Next, Vite, etc.) alive across multiple subsequent Bash / browse / Playwright invocations. The harness's silent reap produces opaque `ERR_CONNECTION_REFUSED` errors with no log trail.

### The pattern that survives

```bash
(nohup <long-running-command> </dev/null > /tmp/output.log 2>&1 &)
```

The outer parens spawn a subshell; `&` puts the command in that subshell's background; the subshell exits immediately; the command's parent reparents to PID 1 (init); `nohup` ignores SIGHUP. The harness's bg-reap mechanism (which terminates background jobs when the parent shell exits) doesn't follow the reparented process to init. Empirically confirmed to survive across multiple subsequent Bash tool calls in the same harness session — proven during home-os PR #15 hero-shot capture (2026-05-15).

### Next.js dev-server worked example

`next dev` is doubly fussy: in addition to the subshell-reparent dance, it must be spawned with the correct `cwd` (the project's `apps/web/` directory), not the workspace root. Spawning from `cwd=/workspace` produces the cryptic error `Couldn't find any pages or app directory. Please create one under the project root` even though the directory clearly exists at `apps/web/app/`. The combined recipe:

```bash
(cd /workspace/apps/web && nohup ./node_modules/.bin/next dev </dev/null > /tmp/output.log 2>&1 &)
```

After spawning, tail `/tmp/output.log` from a separate Bash call to see the `✓ Ready in <N>ms` line before making the first request — there's a 1–3s warmup window.

### Cross-references

Skills that commonly need a long-lived dev server: `.claude/skills/gstack/qa/`, `.claude/skills/gstack/design-review/`, `.claude/skills/gstack/benchmark/`, `.claude/skills/gstack/canary/`. Each may invoke this convention by reference when its own SKILL.md needs to spawn a server across multiple bash blocks. The home-os hero-shot capture script (referenced in `kit/notes/projects/home-os.md § 2026-05-14 PR #15 hero-shot backfill`) is the canonical worked example.

### When to NOT use this pattern

For one-shot commands that finish in a single Bash call (`pnpm test`, `pnpm build`, `pnpm exec playwright test`), this dance is unnecessary — the foreground process completes before the Bash tool returns. Use plain commands. The reparent pattern is only for processes that must stay alive ACROSS subsequent tool calls.

## Supabase Hardening Defaults

_See [`migrations.md`](./migrations.md) for the canonical text._

## Runtime Validation at LLM / Edge-Function Boundaries

_See [`wrapper-boundaries.md § Runtime Validation`](./wrapper-boundaries.md#runtime-validation-at-llm--edge-function-boundaries) for the canonical text._

## Wrapper API design

_See [`wrapper-boundaries.md § Wrapper API design`](./wrapper-boundaries.md#wrapper-api-design) for the canonical text._

## Database queries

_See [`database-queries.md`](./database-queries.md) for the canonical text._

## Confidence Calibration

The decision rubric every implementation task consults: is this safe to do autonomously, or does it require human sign-off first? The short list lives at `/devshop/CLAUDE.md § Confidence Calibration` (always loaded, no rationale). This section carries the per-category rationale.

### Why the two lists exist

Autonomous work shouldn't be gated — operator sign-off on every task would be exhausting and add no signal. Stop-and-ask work shouldn't be skipped — reversing a bad migration / a leaked secret / an accidental auth bypass costs hours-to-days. The lists draw the line where the human's marginal value is highest: irreversible / cross-cutting / security-bearing decisions get the human; bounded-blast-radius work gets autonomy.

### Per-category rationale — Proceed autonomously

- **UI components + their tests** — bounded blast radius; tests catch regressions; visual diff is operator-reviewable.
- **Extending existing API endpoints** — pattern is established by the existing endpoint; no contract change to negotiate.
- **Bug fixes with clear root cause + confirming test** — root cause is known, test prevents regression. (If root cause is unclear, use `/investigate` first — that IS the stop-and-ask path.)
- **Styling / design token changes** — visual diff is reviewable; `DESIGN.md` is authoritative on direction.
- **Documentation updates** — text only; reviewer catches drift; no runtime impact.
- **Adding new Supabase queries (no schema changes)** — read shapes are recoverable; the fragile dimension is schema, not query shape.
- **Instrumenting metrics for events already defined in METRICS.md** — event taxonomy already approved; instrumentation is mechanical.

### Per-category rationale — Stop and ask

- **New database columns/tables** — migrations are hard to reverse; operator must approve schema shape before code locks it in.
- **Auth flow changes** — security-critical; downstream route-protection middleware must land in the same PR (silent-failure rule per `/devshop/CLAUDE.md § Non-Negotiables`).
- **New third-party API integrations not yet in codebase** — vendor selection, key management, error semantics, rate-limit posture all need a decision before code commits to one shape.
- **Performance-sensitive code paths** — optimization tradeoffs (latency vs memory vs DX) need operator priority; "fast" isn't free and the wrong dimension can regress UX.
- **Security-related logic** — stop before writing, get human sign-off; `/cso` still runs after as defense-in-depth, but pre-write approval is the load-bearing gate.
- **Deletion of existing tests** — tests embody contracts; deleting one is admitting the contract is wrong, which needs explicit acknowledgment (not "this test is flaky, delete it").
- **New METRICS.md event definitions** — taxonomy growth needs review to prevent metric sprawl; events added to `METRICS.md` are operator-approved, never auto-added.
- **Behavior edge cases on new input-handling paths** — what happens with empty / malformed / oversized / concurrent / rate-limited input. Default behavior is often the silent bug; pick deliberately and document in a Decision row.
- **Accessibility + i18n posture for new UI surfaces** — WCAG-AA conformance + i18n string externalization. Retrofitting after ship is expensive; choose at design time.
- **New error / observability surface** — where new error paths land (toast / log / Sentry / silent) and what triggers each. Never decide implicitly — silent error paths become silent prod outages.

### Where this list is consulted

- `/ak-spec § Step 6 § Confidence calibration` — spec author surfaces every stop-and-ask category as a Decision row for operator approval before `/ak-implement` runs.
- `/ak-implement § Conventions to honor § Confidence calibration` — re-verifies stop-and-ask items have user approval before writing code.
- `/ak-implement § Clarification escalation` — short-form list for the mid-implementation "is this stop-and-ask?" check.

## TODO Protocol

_See [`/devshop/CLAUDE.md § TODO Protocol`](../../../CLAUDE.md#todo-protocol) for the canonical text._

## Backlog Routing Guide

Covered by `/devshop/CLAUDE.md § TODO Protocol` (routing table) and `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships` (closure protocol). Both are Tier 1, always loaded.

---

## Commit + PR Text Style

Canonical readability rules for every text artifact the pipeline produces: per-commit messages (direct git commits, `/ship`-authored commits), squash-commit messages (`/ak-merge-devshop`), and PR title + body sections (`## Product update` + `## Engineering details`). The rules are identical across surfaces — only the docs / skills that _invoke_ the rule differ.

**PR body structure** (post-product-update-pr-section, 2026-05-17): every PR's body leads with two H2 sections in this order:

1. **`## Product update`** — first content after the H1 title. Carries `### Headline (user-facing)` (1–2 sentences, marketing-grade, zero eng vocabulary) and `### Detail (team-facing)` (1–4 sentences, light eng OK). Both sub-sections copied verbatim from `spec.md § Product update`; `/ak-build` Phase 4.1 routes them. Single source-of-truth — Phase 5.6's BUILD-LOG `Headline:` + `Summary:` fields, Phase 7 ready-for-review comment, and `/ak-go-live` Step 6 deployed-to-prod comment all copy from the spec, not from the PR body. Operator verifies at Phase 6 Gate A; automated Gate B cross-checks claim-vs-diff. Authoring contract: `/devshop/.claude/skills/ak-spec/SKILL.md § Product update`.
2. **`## Engineering details`** — historical `## Summary` shape, renamed. Bullet-led TL;DR + 3-7 bullets at the eng grain (schema, routes, components, tests, CI). Reviewers want this; end-users don't read it.

**Devshop owns this convention** (lives here, not in `gstack/ship/SKILL.md`) so it survives `gstack` upgrades. When a devshop skill or hook needs to enforce or remind, it points here.

### Subject + title style

The subject is the line a reader sees in `git log --oneline`, the GitHub PR list, and release notes. Write it so a teammate who hasn't seen the diff can decode **what behavior changed in the codebase** — not which file or variable was edited.

1. **Describe the observable change**, not the implementation detail.
   "skip CI when only root markdown changes" beats "docs-only skip filter matches root-level markdown" — the reader cares about the new CI behavior, not which filter variable holds the change.
2. **Lead with a verb** when there's one verb-y change (`skip`, `add`, `fix`, `tighten`, `extract`, `rename`, `move`, `replace`). Noun-lists are fine when the commit ships multiple independent units that don't share a verb (e.g. `feat: invite link + member mgmt + audit feed`).
3. **No internal jargon**. Words that only make sense if you've read the spec ("polish", "soak findings", "Phase 2 expansion", "Tier B") are meta-narrative, not change description — drop them or replace with the underlying user- or code-facing fact.
4. **≤ 72 chars**, but err shorter — a tight subject is read faster.

Examples (drawn from real commits):

| Bad — terse but opaque                                                                             | Good — verb-led, behavior-described                                                 |
| -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `fix(ci): docs-only skip filter matches root-level markdown`                                       | `fix(ci): skip CI when only root markdown changes`                                  |
| `fix(settings): household-collaborators polish — typography, skeleton, disclosure (soak findings)` | `fix(settings): tighten household-collaborators typography + skeleton + disclosure` |
| `feat(household-collaborators): invite link + member mgmt + audit feed`                            | (keep — noun-list is the natural shape for a multi-unit feature PR)                 |
| `chore(build-log): record cheap-test-gates-local`                                                  | (keep — subject is self-describing for a build-log chore)                           |

Self-test: would a teammate scrolling `git log` two months from now know what behavior shipped without opening the diff? If not, rewrite.

### Body / Engineering details style

Commit bodies and PR `## Engineering details` sections (the historical `## Summary`, renamed when `## Product update` took the lead-section slot) share one shape: **bullets first**, prose only when a non-obvious decision needs framing.

1. **Open with one sentence of TL;DR**, then drop into 3-7 bullets — each one a concrete user-meaningful unit. A reader should be able to scan the TL;DR + bullets in 10 seconds and know what landed.
2. **Do NOT lead with a prose paragraph** that re-summarizes what the bullets will say. Pick one shape — paragraph OR bullets — not both. Earlier shape (multi-paragraph prose) forced readers to consume the whole block to track what landed; bullet-led shape gives scannable anchors.
3. **Group bullets into logical sections** when there are 2+ themes (e.g. `**Performance**`, `**Dead Code Removal**`, `**Infrastructure**`) — one theme needs no sub-heading.
4. **Enumerate from `git log <base>..HEAD --oneline`**: exclude the `VERSION` / `CHANGELOG` bookkeeping commit, then every remaining substantive commit must appear in at least one bullet. If a commit's work isn't reflected, you missed it.
5. **Follow-up prose**, if any, is 1-2 sentences — for context the bullets can't carry (a trade-off, a why-now, a smoke-test finding).

### Product update style (Headline + Detail)

`## Product update` (PR body, leading section) carries two named sub-sections drawn verbatim from `spec.md § Product update`:

- **`### Headline (user-facing)`** — 1–2 sentences for the end-user / prospect / changelog reader. Marketing-grade, **zero eng vocabulary**: no enum names, no RPC names, no migration numbers, no PascalCase component names, no route paths, no cross-PR references. Talks about what the user can now do in plain English. Phase 0.2.6 lint flags forbidden patterns before the operator approves at preview time.
- **`### Detail (team-facing)`** — 1–4 sentences for the future-me reader / cold reviewer / BUILD-LOG scanner. Light eng context allowed (state names, feature areas — explained, not jargoned). Builds on Headline with the context the team needs.

Same atomic claims, two audiences. Authored once at `/ak-spec` Phase 0, approved at `/ak-build` Phase 0.2, verified at Phase 6 Gate A (operator) + Gate B (automated claim-vs-diff cross-check). When the two would be word-for-word identical, collapse under `### Headline + Detail (combined)`. For pure infra PRs Headline reads `Infrastructure update — no user-visible change in this PR.` (honest about the audience asymmetry, no fabricated marketing voice).

Routing downstream (single source-of-truth = `spec.md § Product update`):

| Surface                                       | Blurb used                                    |
| --------------------------------------------- | --------------------------------------------- |
| PR body `## Product update` (Phase 4.1)       | Both, Headline first                          |
| BUILD-LOG `Headline:` (Phase 5.6 / 4.0)       | Headline                                      |
| BUILD-LOG `Summary:` (Phase 5.6 / 4.0)        | Detail                                        |
| Phase 7 ready-for-review comment              | Detail (reviewers want the eng-aware version) |
| `/ak-go-live` Step 6 deployed-to-prod comment | Headline (lede) + Detail (context)            |
| Future CHANGELOG / release notes aggregation  | Headline                                      |

The squash-message variant (`/ak-merge-devshop`) uses bold-text lead-in labels (`**Adds:**`, `**Trade-off:**`, `**Doc updates:**`, `**Migration:**`, `**Smoke-test finding:**`) instead of theme sub-headings, but the underlying rule is the same: bullets carry the load, labels are scannable anchors.

### Where the rule fires

| Surface                                                               | Owner                                                                                                                                       | Inlined where                                                                                                | Enforced where                                                                                                              |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| Per-commit messages (any commit)                                      | the agent composing the commit                                                                                                              | Restated by `/ak-build` Phase 4 + `/ak-merge-devshop` Phase 0.3                                              | (not enforced per-commit — judged at squash/PR-push time on the rolled-up surface)                                          |
| PR title + `## Product update` + `## Engineering details` (Phase 4.1) | `/ak-build` Phase 4.1 pre-composes title + both sections; `/ship` is the pure executor; Phase 4.3 verifies                                  | `/ak-build` SKILL.md § Phase 4.1 points here                                                                 | `.husky/pre-push` → `adversarial-review.sh prTextHygieneReason` (surface=pr) — `hooks.md § Project mode`                    |
| Squash subject + body (`/ak-merge-devshop`)                           | `/ak-merge-devshop` Phase 0.3 composes; `merge-devshop/SKILL.md § Subject style + Why bullet-led summary` restates this convention verbatim | `merge-devshop/SKILL.md` is the canonical inlining (since the skill itself does the composition end-to-end). | `/ak-merge-devshop` Phase 0.4.5 → same engine with `DEVSHOP_HYGIENE_SURFACE=squash` — `hooks.md § Dual-surface check-types` |

The convention is **discoverable** at the workflow level (`workflow.md § Phase 4`) and **applied** at the skill level (`merge-devshop/SKILL.md`, `build/SKILL.md`). It is intentionally NOT inlined into `gstack/ship/SKILL.md` — gstack syncs would clobber the addition. When `/ship` is invoked from `/ak-build`, Phase 4's wrapper handoff carries the reminder.

Both enforced surfaces share a single reviewer engine (`adversarial-review.sh prTextHygieneReason`) via env-var-selected surfaces — when the readability rules above shift, both surfaces shift in lockstep. See `kit/docs/guide/hooks.md § Dual-surface check-types` for the per-surface data sources + which sub-rules apply per surface.

---

## Existing-Project Migration Block

Every devshop commit whose diff requires a per-project follow-up MUST include an `**Existing projects:**` bold-label block in the commit body. The block tells future sessions — and the operator doing the next project catch-up — exactly what each project needs to do (or explicitly that nothing is needed).

### When the block is required

The trigger is: the commit touches a surface that affects project repos AND the change requires a per-project step that `from-devshop.sh` / `init-devshop.sh` won't handle automatically. Concretely:

| Diff touches | Auto-handled? | Block required? |
| --- | --- | --- |
| `[locked]` file in `kit/manifest.txt` (e.g. `.claude/settings.json`, `.dcg.toml`, `.husky/pre-push`) | Yes — `init-devshop.sh` refreshes on rebuild | **Yes, but state "no migration needed"** — the "no migration" variant is important so the reader knows the author considered the question |
| `[symlink]` file in `kit/manifest.txt` | Yes — symlink target changes automatically | Same — state "no migration needed" |
| `[sync]` file in `kit/manifest.txt` (e.g. `template/.github/workflows/ci.yml`) | Partially — `from-devshop.sh` syncs, but may need manual review | **Yes** — describe what the operator should verify after sync |
| `[scaffold-once]` file (e.g. `template/CLAUDE.md`, `template/PLAN.md`, `template/PRODUCT-ROADMAP.md`) | No — `from-devshop.sh` skips these by design | **Yes** — per-project migration recipe with concrete steps |
| `template/**` file not in manifest | Depends on lifecycle tag | **Yes** if the change needs per-project action |
| `kit/scripts/**`, `kit/hooks/**`, `.devcontainer/**` | Varies | **Yes** if behavior changes require project-side follow-up (env var, config, rebuild) |

### Required shape

```
**Existing projects:** <one of the two variants below>
```

**Variant A — no migration needed** (the auto-sync mechanism handles it):

```
**Existing projects:** `compose.yml` + `supabase-runner/cmd-relay.mjs` are `[locked]`
files in `kit/manifest.txt`; `init-devshop.sh`'s lock loop refreshes them in each
project workspace on the next devcontainer rebuild. No project-side migration needed.
```

**Variant B — per-project recipe** (manual steps required):

```
**Existing projects:** `template/PLAN.md` is `[scaffold-once]` in `kit/manifest.txt`
so `from-devshop.sh` won't auto-propagate. Per-project: rewrite each project's
PLAN.md to the new schema as a one-time conversion. Each existing project gets a
one-time cleanup commit.
```

The block names: (1) which manifest lifecycle tag applies, (2) why auto-sync does or doesn't cover it, and (3) concrete steps when manual action is needed.

### Placement in the commit body

The block goes under a `**Existing projects:**` bold-label lead-in, following the same lead-in convention as `**Lands:**`, `**Doc updates:**`, `**Migration:**` (see § Commit + PR Text Style above). In `/ak-merge-devshop` squash messages, it appears as one of the lead-in topics alongside the others.

### Enforcement

Not enforced per-commit by a hook (the convention is judgment-heavy — "does this change need a project follow-up?" is not mechanically decidable). Enforced at audit time: `/ak-docs-review` Section A flags devshop commits that touch propagation-relevant surfaces without an `**Existing projects:**` block as a **medium** coverage finding.

### Precedents

- `44e53fc` — `**Existing projects:**` block explaining `[locked]` files auto-refresh on rebuild (no migration needed)
- `4ec8cdd` — `**Existing projects:**` block implicit in the CI yml propagation commit (the `check-template-propagation.sh` nudge was the structural fix)
- `87107fe` — supabase port partial fix with per-project catch-up steps

---

## Verify state before public assertion

Any `gh pr comment`, commit body, status update, audit log, or other public artifact that asserts external state (CI green, preview reachable, deploy succeeded, canary passed) MUST verify the assertion **at the moment of writing** against its **canonical source**, not a proxy.

**Canonical vs proxy**:

- `gh run view --json conclusion` is canonical for CI status.
- "The prior run was green so this one must be too" is an assumption — not canonical.
- The deploy platform's bot status comment is canonical for preview reachability.
- `curl -sfI <preview-url>` from a locked-down devcontainer is a proxy that breaks on firewall / CDN rotation — not canonical.

**Watch-every-push rule**: every subsequent push on the branch (polish-loop fixes, audit-fix commits, follow-up pushes) must be re-watched and confirmed `success` at HEAD before any public artifact asserts CI-green. A green claim against a stale SHA is the same shape as a fabrication.

**Worked incident**: lalista PR 18 (2026-04-25). Audit + ready-for-review comments posted against an earlier green CI run while the latest run (for the bookkeeping commit) was still `in_progress` and ultimately failed → public retraction comment. Codified into `/ak-build` Phase 5.3's "watch-every-push" preamble + Phase 5.8.1's polish-loop CI sanity check + Phase 6 Part B's evidence-sweep posture (read the platform bot's status comment instead of curl-ing the preview URL).

**The general rule**: applies beyond `/ak-build`. Any session producing a public artifact (skill output, PR comment, BUILD-LOG entry) about external state must verify against canonical signal at write-time.

---

## Closing TODO / ROADMAP entries when a fix ships

The same PR that ships a fix MUST close the tracker entries for it. Otherwise, stale entries get cited as "still pending" in future sessions and recreate the false belief that the fix removed — wasting investigation time.

Three things, all in one PR:

1. **Delete the entry** from `kit/ROADMAP.md` / `kit/TODOS.md` / project `TODOS.md`. No "shipped 2026-04-25" footnote, no strikethrough — just delete. Git log + the PR description are the audit trail.
2. **Rewrite docs that described the prior constraint** from conditional prose to imperative present tense:
   - Anti-pattern: _"Without X, Y fails. See ROADMAP § Z."_ — reads as a precondition the reader must verify.
   - Replacement: _"Do Y."_ / _"Y works."_ — the capability is ambient now, treat it that way.
   - The "must be true / verify before assuming blocked" hedge is a pre-fix artifact; strip it.
3. **Unwind every cross-reference** to the deleted entry in the same PR. An orphan citation in some other doc respawns the false belief in any session that reads it.

Future sessions trust the docs. Trust is only earned by keeping them honest at fix-ship time.

**Worked incident**: 2026-04-26 — a `Without this, gh run download fails` line in `/ak-build` SKILL.md survived a month past the firewall fix shipping; a session read it as "still blocked" and skipped artifact-pull on a CI failure that had artifacts waiting.

---

## Non-Negotiables

### Testing

- **No code without tests** — written alongside, never after.
- **No code that breaks existing tests** — full test suite runs before marking done.
- **Testing layers**:
  - Unit tests (`*.test.ts`): mock external dependencies. Pure business logic only — validation, transforms, calculations.
  - Integration tests (`*.integration.test.ts`): must hit a real local database. Never mock the DB layer for queries, access control, or data integrity. Bring up via `pnpm db:start` under the template-default compose-isolation shape (relay → supabase-runner sibling), or `supabase start` from the macOS host terminal under Host Supabase, or Docker Compose for non-Supabase stacks. See `kit/docs/guide/local-supabase-compose-isolation.md` for the architecture.
  - E2E tests: required for every user-facing flow. Playwright runs at 375px (mobile) and 1440px (desktop). Both must pass.
- **Test commands**: `pnpm turbo run test:unit` (unit only, no DB) vs `pnpm turbo run test` (unit + integration, needs local DB). Use `test:unit` for the fast inner loop; `test` for full verification.
- **Auth boundary tests (RLS)**: every table with RLS policies must have at least one integration test — authenticate as User A, create data, authenticate as User B, verify data is NOT visible. RLS bugs are silent data leaks; mocked tests can never catch them.
- **`seed.sql`**: minimum test fixtures for integration tests. Must include at least 2 users with different access levels (e.g., different households or roles) for RLS boundary testing — User A's data must be invisible to User B. Include representative data for each table with RLS policies. Loaded by `supabase start` automatically and by CI before running integration tests.
- **CI enforcement lands in the same PR as the code it tests** — no gap between "tests exist" and "CI runs them."
- **CI mirrors runtime**: if the app uses a DB at runtime, CI starts it locally. Never skip integration tests because "they work locally." Never hit shared remote environments from CI. Supabase: `supabase start` + `seed.sql` + type drift check + mask `SUPABASE_SERVICE_ROLE_KEY`.
- **Type drift check**: CI regenerates types from schema and fails if committed types have drifted.
- **QA-backend isolation** (which Supabase flavor dev / CI / pre-ship point at): see [kit/notes/roadmap/qa-options.md](../../notes/roadmap/qa-options.md) for the 6-option backend matrix (local / preview branches / staging / testcontainers / mocks / hybrid), 4-layer enforcement stack (firewall / credential split / URL guard / branch protection), and the 5-surface map of where QA happens across `/ak-implement`, `/ak-pre-ship`, CI fast/slow jobs, and `/canary`.

### Test Assertion Depth

Owned by `/ak-tests-review` — see `.claude/skills/devshop/tests-review/SKILL.md § Shape-only assertions` for the rule, escape hatch (`// shape-only:` comment), and scope (diff-only, not retroactive).

### Playwright + controlled inputs on WebKit

For forms with **controlled inputs** whose values are read at submit time (login, sign-up, password-reset — anything with `<input value={state} onChange=…>`), **use `pressSequentially` instead of `fill` on WebKit**. The pattern:

```ts
const input = page.locator('#email');
await input.click();
await input.pressSequentially(value, { delay: 10 });
await expect(input).toHaveValue(value);
```

**Why** — `page.locator('#input').fill(value)` can resolve before React's state syncs back to the DOM `value` attribute on a freshly hydrated controlled input. The result: `fill` reports "value set", the next interaction observes the field as empty, the form submits with missing data. Lalista PR #43 reproduced this identically across three WebKit CI runs (25258858879 / 25259626169 / 25260400981) before the fix landed; the symptom reads as flake because Chromium passes. `pressSequentially` delivers real keystrokes — React has time to settle between them — and the `toHaveValue` assert auto-retries so a slow hydration doesn't false-fail.

**How to apply** — anywhere a Playwright spec runs against a WebKit project AND the field is controlled. Uncontrolled inputs (raw `<input>` with no React state) are unaffected; `fill` is fine there. Worked examples ship in `template/apps/web/e2e/sign-up.spec.ts` + `template/apps/web/e2e/forgot-password.spec.ts` (the `fillControlled` helper). `/ak-pre-ship` Gate 9 walks must use this pattern on WebKit; `/ak-tests-review` flags new specs that use bare `.fill()` against controlled inputs.

### Supabase auth E2E patterns

Supabase's sign-up behavior changes shape depending on `[auth.email].enable_confirmations`:

- **`enable_confirmations: true`** (typical prod posture): existing-account second-signup returns `{ user: { identities: [] }, session: null }` — the no-enumeration shape. The app's `/sign-up` page can branch into `AwaitingConfirmationCard`, indistinguishable from a fresh signup. **Test this at the unit level** with a mocked Supabase response — mock the `identities: []` + null-session shape and assert the UI renders the awaiting-confirmation copy.
- **`enable_confirmations: false`** (local stack's auto-confirm default): Supabase returns an explicit `User already registered` error. **Test this at the E2E level** against the local stack — the friendly-error mapping renders "already registered, try signing in instead."

**Why both layers** — prod and local diverge intentionally. E2E exercises the auto-confirm error path (what local-stack returns); unit pins the no-enumeration shape (what prod returns). Without the unit-level mock, projects ship the wrong copy under the prod-shape branch and only catch it post-deploy. Without the E2E, the friendly-error mapping rots silently.

**How to apply** — any project using `supabase.auth.signUp` ships both layers:

1. Unit test at `apps/web/app/sign-up/page.test.tsx` (or wherever the sign-up logic lives) mocking the no-enumeration return shape.
2. E2E at `apps/web/e2e/sign-up.spec.ts` exercising the auto-confirm path (real `signUp`, real Mailpit link follow). Skeleton ships in `template/apps/web/e2e/sign-up.spec.ts`.

`kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 9` carries the canonical Mailpit helper shape; `template/apps/web/e2e/helpers/inbucket.ts` is a verbatim copy so fresh scaffolds inherit it on day 1.

### Testing Lifecycle

Owned by `/ak-implement` — see `.claude/skills/devshop/implement/SKILL.md § Testing lifecycle` for the per-stage table (local → pre-commit → CI fast → CI slow → pre-ship).

### Kit Testing (devshop infrastructure)

The devshop's own scripts and configuration are tested with [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System). Tests run on every devshop commit (step 5 of pre-commit chain, ~6s). Run manually: `pnpm test:kit`.

**Test categories** (`kit/tests/`):

| Category              | Files                                            | What it verifies                                                                                                                                |
| --------------------- | ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Goal verification     | `goal1-separation.bats`, `goal2-guardrails.bats` | Devshop goals hold: separation (symlinks, mixed commits, standalone projects) and guardrails (security model)                                   |
| Guard behavior        | `guard-*.bats` (7 files)                         | Every pre-commit guard and PreToolUse hook: block/allow logic, bypass paths, adversarial review integration                                     |
| Pre-commit routing    | `pre-commit-router.bats`                         | Correct guards called per repo type, failure propagation                                                                                        |
| Structural invariants | `structural-invariants.bats`                     | System-level wiring: hook paths resolve, symlinks intact, manifest consistent, template contracts valid, configs parseable, version/tag aligned |
| Utilities             | `util-*.bats` (3 files)                          | Path normalization, changelog insertion, file header checks                                                                                     |

**Two enforcement layers:**

1. **Per-commit (pre-commit chain):** BATS runs the full test suite (~6s). Catches regressions immediately. The `check-tests-coverage-devshop.sh` guard blocks new scripts without test files and warns on modified scripts without test files.
2. **Per-merge (audit-time):** `/ak-tests-review` reviews the diff before each merge to main (fires automatically inside `/ak-merge-devshop` Phase 1, which delegates to `/ak-check-docs-and-tests`). Surfaces missing coverage of new behavior + weak assertions + the 11-rubric quality checks against the actual `.bats` files. Replaces the per-release adversarial review removed in PR-C of the audit-time docs+tests migration (`kit/ROADMAP.md § PR-C`).

**What's tested vs. exempt:**

Every script in `kit/scripts/` is either tested or explicitly exempt in `check-tests-coverage-devshop.sh`. Exempt scripts have documented reasons (e.g., `adversarial-review.sh` calls Claude CLI — non-deterministic, mocked in all callers; `init-devshop.sh` runs as root).

**How tests mock external dependencies:**

- `adversarial-review.sh` (Claude Sonnet) → PATH-first stub returning PASS/FAIL
- Git state → throwaway repos in `$BATS_TMPDIR` with controlled staging
- Cross-repo checks → disabled via wrapper sed or fake repos
- `GIT_CONFIG_PARAMETERS` → unset to isolate from parent commit's `-c` flags

**Adding tests for a new script:**

1. Create `kit/tests/guard-<name>.bats` or `kit/tests/util-<name>.bats`
2. Use `load helpers/setup` for shared helpers (mock bin, test repos, adversarial stubs)
3. If the script is genuinely untestable, add to the exempt list in `check-tests-coverage-devshop.sh` with a reason

**Preserve the production execution context.** When a bats test extracts a snippet from a real script (via `awk` / `sed`) and re-executes it under `bash $runner`, the runner shell starts with default bash options — NOT the source script's options. If the source has `set -euo pipefail` at the top, the test must replicate that header in the runner; otherwise a whole class of pipefail-driven silent failures is invisible to the test. Worked incident: `init-firewall-port-allowance.bats` (2026-05-20) shipped with 15 passing tests but missed a pipefail-killed-the-script regression because the runner ran outside `set -euo pipefail`; the bug shipped to template and bricked a project rebuild before the gap was caught. Mitigation: bats tests that exec extracted snippets MUST either (a) prepend the source script's `set` options to the runner before sourcing the snippet, or (b) explicitly assert the test scope excludes the source's shell-options context (rare — only when the snippet is provably pipe-free and never reads from commands that exit non-zero). The `init-firewall-port-allowance.bats § Regression` block shows the canonical shape: a `run_snippet_pipefail` helper that wraps the runner in `set -euo pipefail` + `IFS=$'\n\t'` + a sentinel echo at the end, so the test distinguishes "exited cleanly with empty resolution" from "died silently". `/ak-tests-review` reviewer surfaces this gap when reviewing new bats tests that introduce a `bash "$runner"` pattern.

### Metrics

- **No code without metrics** — every user-facing feature must have events in `METRICS.md`, instrumented in the same PR.

### Responsive + Theme

- **Responsive from day one** — works (not just renders) from iPhone SE (375px) to large desktop (2560px). Mobile-first. `packages/ui/src/tokens.ts` defines breakpoints as single source of truth; `tailwind.config.js` reads them. No hardcoded pixel widths. Playwright E2E runs at mobile + desktop. Snapshot tests include both variants.
- **Light/dark theme required** — both from launch. `tokens.ts` defines semantic theme tokens. Tailwind maps to CSS custom properties. Theme follows `prefers-color-scheme` with optional toggle. No hardcoded colors — always theme tokens. Snapshots include both themes.
- **Snappiness / latency feedback** — when adding loading affordances, threshold spinners, optimistic mutations, or skeleton placeholders, see `kit/docs/guide/latency-feedback.md`. The guide owns the two-skeleton-handoff rule and the sizing-primitive override gotcha — both silently degrade UI without throwing errors.

### PWA

- **PWA-installable** — `manifest.json`, Apple meta tags. "Add to Home Screen" works on iOS/Android. Service worker caching (`@serwist/next`) deferred to `PRODUCT-ROADMAP.md` — added after core screens are stable to avoid stale-data bugs during active development. Placeholder icons at scaffold; replaced with real branding during design system migration.

### Code Structure

- **Shared packages export TypeScript source directly** — `"main": "src/index.ts"`. Each consuming app transpiles. Every package has a `src/index.ts` barrel export. No deep path imports across package boundaries.
- **File documentation**: every non-trivial `.ts`/`.tsx` file under `src/` or `app/` has a 3-line header (`// What:` / `// Why:` / `// Does NOT:`). Every exported function has 1-2 sentence JSDoc (enforced by ESLint via `eslint-plugin-jsdoc`). Internal/private: no doc required. Config files (`*.config.*`, `*.d.ts`) are exempt. Headers are checked by `/ak-pre-ship` convention check, not pre-commit — mechanical enforcement produces mechanical documentation.
- **Implementation approach**: default to simple. Boring solution. Tried-and-true over clever. Readable over optimal.
- **ESLint for code quality only** — Prettier owns all formatting.

---

## Test Presence

Every new source file under `apps/*/{src,app,components,lib,hooks}/` or `packages/*/src/` MUST ship with a paired test in the same commit. Enforcement is `kit/scripts/commit-hooks/check-tests-coverage-project.sh`, wired into project-repo `.hooks/pre-commit` via `kit/hooks/pre-commit.sh`.

**Layer 1 (deterministic, this hook):**

- **ADD without paired test** → BLOCK. The pair is `<file>.test.ts` / `<file>.test.tsx` / `<file>.integration.test.ts` / `<file>.spec.ts` in the same directory, OR any `*.test.*` in the same directory that mentions the new file's stem.
- **DELETE source while paired test still present** → BLOCK as orphan. Stage the test deletion in the same commit.
- **MODIFY without test diff** → WARN only. `/ak-tests-review` is the quality gate at ship time.

**Exempt by filename** (entry-points + framework-required files where unit-testing is fraught — E2E covers them): `index.ts`, `index.tsx`, `page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`, `not-found.tsx`, `global-error.tsx`, `template.tsx`, `default.tsx`, `head.tsx`, `icon.tsx`, `robots.ts`, `sitemap.ts`, `manifest.ts`, `middleware.ts`, `instrumentation.ts`, `instrumentation-client.ts`, `vitest.setup.ts`, `providers.tsx`.

**Exempt by pattern**: `*.d.ts`, `*.config.*`, `*.test.*`, `*.spec.*`, `*.integration.test.*`, anything under `e2e/`, `tests/`, `__tests__/`, `__mocks__/`, `types/**/*.ts`, top-level `types.ts`.

**Per-project override**: `.devshop-test-coverage-exempt` at repo root, one path per line. Whole-line `#` comments and trailing `# reason` comments after a path are both stripped before exact-match. Audit-trail discipline — each exemption commits with a reason in the commit message. **Adding a new entry triggers `check-exempt-additions.sh`** (Pre-flight: any cited covering test/spec path in the inline reason must exist on disk; Layer 2: adversarial review judges per-entry specificity). See § Exempt-File Additions below.

**Bypass (Layer 1 trailer)**: `git -c devshop.testsCoverageReason="<why>" commit ...` accepts on flag presence (no LLM call). The `prepare-commit-msg` hook appends a `Tests-Coverage-Bypass: <why>` trailer to the commit message; audit-time `/ak-tests-review` harvests trailers from the commit range and surfaces each as a `[bypass-revisit]` finding (VERIFIED / DEFER / ESCALATE per the diff at audit time). See § Bypass trailers below.

**Relationship to `/ak-tests-review`**: this hook catches "I forgot a test entirely." `/ak-tests-review` (audit-time, fired by `/ak-check-docs-and-tests`) catches "this test is weak." They're complementary, not redundant.

---

## Project Docs Coverage

The project's hierarchical doc set decays silently as routes get added, API wrappers proliferate, and analytics events land. Enforcement is `kit/scripts/commit-hooks/check-docs-coverage-project.sh`, paired with the test-presence hook above. (Renamed from "Project Docs Freshness" / `check-docs-freshness-project.sh` in PR-C of the audit-time docs+tests migration — single naming convention `coverage` for both docs and tests file-pairing; see `kit/ROADMAP.md § PR-C § A`.)

**Trigger map (staged path → required doc):**

| Staged change                                                           | Required doc update                                                                                                                                                                                             |
| ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| New `apps/*/app/**/page.tsx`, `layout.tsx`, `route.ts`                  | `CLAUDE.md` (must also be staged)                                                                                                                                                                               |
| New `apps/*/middleware.ts`                                              | `CLAUDE.md`                                                                                                                                                                                                     |
| New `packages/*/src/api/*.ts` (wrapper module)                          | `CLAUDE.md`                                                                                                                                                                                                     |
| New `posthog.capture(...)` or `Sentry.captureException(...)` call site  | `METRICS.md` (must also be staged) — except in `specs/*/review.md` / `specs/*/tasks.md` (audit-prose paths are pathspec-excluded; real call sites in `apps/`, `packages/`, `supabase/functions/` still trigger) |
| New `apps/*/app/**/page.tsx` or `layout.tsx` (user-visible flow)        | `OVERVIEW.md` (opt-in: only if file exists at HEAD)                                                                                                                                                             |
| New `apps/*/app/**/page.tsx`, `route.ts`, middleware, or function entry | `ARCHITECTURE.md` (opt-in: only if file exists at HEAD)                                                                                                                                                         |
| New file under `apps/<x>/`                                              | `apps/<x>/README.md` (opt-in: only if file exists at HEAD)                                                                                                                                                      |
| New file under `packages/<x>/src/`                                      | `packages/<x>/README.md` (opt-in: only if file exists at HEAD)                                                                                                                                                  |
| New file under `supabase/functions/<x>/`                                | `supabase/functions/README.md` (opt-in: only if file exists at HEAD)                                                                                                                                            |
| Source path DELETE while doc still references it                        | BLOCK on stale reference (across CLAUDE/METRICS/OVERVIEW/ARCHITECTURE/per-package READMEs)                                                                                                                      |

**Layer 1 (deterministic)**: matches staged paths against the trigger map. If a triggering surface is added without the paired doc staged, BLOCK. If a deleted source path's basename-or-full-path still appears in any orientation doc (CLAUDE.md, METRICS.md, OVERVIEW.md, ARCHITECTURE.md, or any per-package README discovered under `apps/`, `packages/`, `supabase/functions/`), BLOCK.

**Opt-in semantics**: `OVERVIEW.md`, `ARCHITECTURE.md`, and per-package READMEs (`apps/<x>/README.md`, `packages/<x>/README.md`, `supabase/functions/README.md`) trigger ONLY when the target doc file exists at HEAD. Projects opt in by creating the file from the template skeleton or writing one directly. New projects scaffold `OVERVIEW.md` + `ARCHITECTURE.md` automatically via the template; per-package READMEs are operator-driven (create the file when there's enough package-level surface to document, leave absent otherwise). The trigger does not fire on the commit that first creates the README — only on subsequent additions to that package.

**Bypass (Layer 1 trailer)**: `git -c devshop.docsCoverageReason="<per-doc enumeration with named edits>" commit ...` accepts on flag presence (no LLM call). The `prepare-commit-msg` hook appends a `Docs-Coverage-Bypass: <reason>` trailer to the commit message; audit-time `/ak-docs-review` harvests trailers from the commit range and surfaces each as a `[bypass-revisit]` finding (VERIFIED / DEFER / ESCALATE per the diff at audit time). See § Bypass trailers below.

**Per-project override**: `.devshop-docs-freshness-exempt` at repo root, one path per line. Whole-line `#` comments and trailing `# reason` comments are both stripped before exact-match. Same audit discipline as the test-coverage override. **Adding a new entry triggers `check-exempt-additions.sh`** — see § Exempt-File Additions below.

**One Layer 1 surface per repo**: project-side `check-docs-coverage-project.sh` fires on project source surfaces (apps/, packages/, supabase/functions/); devshop-side `check-docs-coverage-devshop.sh` fires on devshop source surfaces (kit/scripts/, kit/hooks/, .claude/skills/, template/, .devcontainer/, kit/manifest.txt) per the surface→doc mapping in `kit/ROADMAP.md § PR-C § A`. The two never overlap because they detect repo-mode at runtime and exit 0 in the wrong repo.

---

## Bypass trailers

Layer 1 docs/tests-coverage bypass flags emit Git trailers (instead of running an LLM at commit time) so that audit-time `/ak-docs-review` and `/ak-tests-review` can harvest them and surface each as a `[bypass-revisit]` finding. The trailer mechanic was introduced in PR-C of the audit-time docs+tests migration alongside the per-commit Layer 2 removal — see `kit/ROADMAP.md § PR-C § B`.

**Trailer keys**:

| Layer 1 script                              | Bypass flag                          | Trailer key              |
| ------------------------------------------- | ------------------------------------ | ------------------------ |
| `check-tests-coverage-{project,devshop}.sh` | `git -c devshop.testsCoverageReason` | `Tests-Coverage-Bypass:` |
| `check-docs-coverage-{project,devshop}.sh`  | `git -c devshop.docsCoverageReason`  | `Docs-Coverage-Bypass:`  |

**How it works**:

1. **Pre-commit**: the Layer 1 script reads `git config devshop.<flag>`. If a non-empty value is present AND the script would otherwise block, it accepts the commit (no LLM call). If the flag is absent, the script blocks normally with a helpful message including the bypass invocation.
2. **`prepare-commit-msg`** (`kit/scripts/commit-hooks/append-bypass-trailers.sh`, called from `.husky/prepare-commit-msg`): runs after pre-commit, before the commit message is finalized. Reads the same `git config` flags and appends the corresponding trailer via `git interpret-trailers --in-place`. Idempotent — re-running on the same message file does not duplicate trailers.
3. **Audit-time consumption**: `/ak-docs-review` and `/ak-tests-review` each run a `git log --format=%B <range>` over their commit range, grep for `Docs-Coverage-Bypass:` / `Tests-Coverage-Bypass:` lines, and emit each one as a `[bypass-revisit]` finding in the audit report. Possible audit outcomes:
   - **VERIFIED** — bypass was load-bearing AND remains valid given current diff. Recorded but not escalated.
   - **DEFER** — bypass remains pending (e.g., docs update batched to end-of-feature; subsequent audit re-checks). Recorded.
   - **ESCALATE** — bypass was load-bearing at the time but the diff has shifted such that the bypass would no longer be valid. Surfaced as medium or high severity.

**Example commit body after bypass**:

```
fix(auth): wire onEdit prop into AwaitingConfirmationCard

Adds the prop and its handler. CLAUDE.md update batched with
parent feature work; will be addressed at end-of-feature audit.

Docs-Coverage-Bypass: deferring CLAUDE.md§Where Things Happen update to end of feature
```

**Why trailers vs side-log**: trailers travel with the commit (survive rebase, push, clone) and are universally greppable via `git log`. Side-log files are local-only and flaky (interruptions, container rebuilds). Trailers are visible to anyone reading the PR (GitHub displays the full commit body). Git trailers + `prepare-commit-msg` are documented Git conventions — no new format invented.

**What the trailer mechanic does NOT do**: it does NOT judge whether the bypass is reasonable. That judgment moves to audit time, where the reviewer has the full diff and the docs HAVE been written. Generic bypass reasons (`later`, `WIP`, `low risk`) still get recorded as trailers — but the audit-time `[bypass-revisit]` pass over them produces high-severity findings if the diff shows the work wasn't actually done.

### Approval-gate trailers

A different family of trailer lives on commit bodies authored by skill-driven approval gates, NOT by Layer 1 pre-commit scripts. The reviewer judgment fires at the approval gate (AskUserQuestion), and the operator's "Approve anyway" override lands as a trailer for durable audit-trail. There is no `git -c devshop.<flag>` invocation — the trailer is written by the skill into the composed commit message file before `git commit -F`.

**Trailer keys**:

| Author skill                          | Approval-gate context                                                                                                                          | Trailer key         |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| `/ak-merge-devshop` Phase 0.4.5 + 0.5 | Squash subject + body failed `adversarial-review.sh prTextHygieneReason` (`DEVSHOP_HYGIENE_SURFACE=squash`); operator picked "Approve anyway". | `Hygiene-Override:` |

**How `Hygiene-Override:` works**:

1. Phase 0.4.5 invokes the shared `prTextHygieneReason` engine on the composed squash message; the verdict is captured into `HYGIENE_VERDICT` + `HYGIENE_OUTPUT`.
2. Phase 0.5's approval gate, when `HYGIENE_VERDICT=FAIL`, surfaces the verdict prominently and offers Edit (recommended) / Approve anyway / Cancel.
3. On "Approve anyway", the skill appends `Hygiene-Override: <one-line reason>` to `/tmp/squash-message-${FEATURE}.txt` before the Phase 2 `git commit -F`, so the override is visible alongside `Co-Authored-By:` in `git log` on main.

There is no audit-time `[hygiene-revisit]` pass — the override is informational signal, not a coverage-deferral that needs re-judging. Future surfacing of overrides (e.g., a quarterly retrospective grep) is operator-initiated, not skill-driven. Full mechanism + dual-surface model: `kit/docs/guide/hooks.md § Dual-surface check-types`.

---

## Exempt-File Additions

The two exempt files (`.devshop-test-coverage-exempt`, `.devshop-docs-freshness-exempt`) are the operator's escape hatch for legitimately-uncovered surfaces. Without review, anyone can append a path with a vague reason (or no reason at all) and silently disable the upstream gate for that path. `kit/scripts/commit-hooks/check-exempt-additions.sh` reviews every added line.

**Pre-flight (deterministic)**: each added line of the form `path  # reason` is parsed; path-like tokens in the **reason** (everything after `#`) are extracted (`*.ts`, `*.tsx`, `*.spec.ts`, `*.integration.test.ts`, `*.test.ts`, `*.spec.tsx`, `*.md`) and verified to exist on disk. The LHS path (the exemption target) is NOT checked — it commonly does not exist yet. A cited covering spec/test that doesn't exist is a **hard block — no adversarial bypass**, because that's the exact problem this check exists to catch.

**Layer 2 (adversarial)**: when pre-flight passes, the inline reasons are sent to `adversarial-review.sh exemptAddition`. The reviewer requires per-entry specificity: a cited path that the pre-flight verified, OR an explanation of why the path is intrinsically untestable (pure re-export, type-only, dev-only stub) / doesn't need a doc entry (internal liveness probe, dev-only screen). Generic reasons (`TODO test`, `low risk`, `WIP`, `covered elsewhere`) fail. The relevant convention sections (Test Presence, Project Docs Coverage, Project Docs Hierarchy) are inlined into the reviewer's context.

**Removals are unreviewed** — relaxing an exemption (re-applying the upstream gate) is always safe.

**Order in the chain**: runs BEFORE `check-tests-coverage-project` and `check-docs-coverage-project`, so a bad exempt addition surfaces first — the operator knows to fix the exempt entry, not chase the gate it would have silenced.

**No check-specific bypass flag**. The inline `# reason` IS the bypass surface. If the reviewer is wrong, the universal terminal-only override is `git -c devshop.humanReviewed="approve: <assessment>" commit ...`.

---

## Project Docs Hierarchy

Every devshop project ships with three categories of orientation docs, distinguished by how each is loaded and what role it plays:

- **Always-loaded** — `CLAUDE.md`. The standing operating manual. **Which `CLAUDE.md` loads depends on the session's cwd** (set when the devcontainer opens):
  - **Project session** (cwd = project root, the typical case when you open the project's devcontainer): Claude Code's **native CLAUDE.md discovery** loads the **project's** `CLAUDE.md` — standard Claude Code mechanism, no hook involved. The SessionStart hook (`kit/scripts/session-start.sh`) additionally injects `/devshop/CLAUDE.md` so devshop conventions reach the agent too — workaround for [`anthropics/claude-code#22583`](https://github.com/anthropics/claude-code/issues/22583) (additionalDirectories CLAUDE.md isn't loaded natively). Net effect: project session has BOTH CLAUDE.md files in context.
  - **Devshop session** (cwd = `/devshop`, when you open the devshop's own devcontainer): native discovery loads `/devshop/CLAUDE.md` directly. The SessionStart hook detects this case (`$ROOT == /devshop`) and skips its `/devshop/CLAUDE.md` injection — would be redundant. The project's `CLAUDE.md` is NOT loaded in this case (the session is interacting with the devshop, not the project).

  See `/devshop/CLAUDE.md § Session Start` for the conditional logic + `kit/scripts/session-start.sh:55-63` for the implementation.

- **Foundational (on-demand)** — `OVERVIEW.md` (product), `ARCHITECTURE.md` (system), and per-package READMEs at `apps/<x>/`, `packages/<x>/`, `supabase/functions/`. The "what is this / how is it built" docs a new reader (human or fresh-session agent) drills into first. Durable; updated when scope or shape shifts.
- **Operational (on-demand)** — `PLAN.md`, `BUILD-LOG.md`, `PRODUCT-ROADMAP.md`, `TODOS.md`, `METRICS.md`. Project-management state. Read when planning, shipping, or triaging; transient and continuously updated.

> **Naming note**: this doc-category framing is distinct from the **devshop's context-loading tiers** (`/devshop/CLAUDE.md`'s "Tier 1 / Tier 2 / Tier 3", at `kit/notes/roadmap/conventions-audit-redistribution-2026-04-27.md`), which classify devshop's _own_ operational docs by load-frequency. The two taxonomies are unrelated; they apply to different doc sets and use different vocabulary deliberately.

### Always-loaded

| File        | Role                                                                                                                                                                                                                                  | Loaded                       |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| `CLAUDE.md` | Always-loaded entry point. § Where Things Happen (path map of every documented surface), § Gotchas (non-obvious rules surfaced by shipping work), § Testing, § Stack, § Env Var Naming, § Migration Workflow, § Deploy Configuration. | Every session, automatically |

### Foundational (on-demand)

The "what is this / how is it built" docs. Read on first contact with the project; updated when scope or shape shifts.

| File                           | Role                                                                                                                                               | Loaded    |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| `OVERVIEW.md`                  | **Product**: what the app does, who uses it, core flows, features, scope bounds. Cross-links to ARCHITECTURE.md.                                   | On demand |
| `ARCHITECTURE.md`              | **System**: components, data flow, deployment topology, module map. Cross-links to OVERVIEW.md, links into per-package READMEs.                    | On demand |
| `apps/<x>/README.md`           | App-specific surfaces — route map, layout structure, component conventions, env var slice. One per app under `apps/`.                              | On demand |
| `packages/<x>/README.md`       | Package-specific surfaces — purpose, module map, public API, conventions. One per package under `packages/`.                                       | On demand |
| `supabase/functions/README.md` | Function contracts — one row per edge function (purpose, request/response shape, auth model, env vars). Single file for all functions, not per-fn. | On demand |

`OVERVIEW.md` + `ARCHITECTURE.md` ship in `/devshop/template/` so new projects start with the shape; the freshness hook fires on add-paths-that-change-what's-documented only **once the file exists at HEAD** (opt-in by retaining the scaffold). Cross-link them in both directions at the top of each file ("for the system view see ARCHITECTURE.md" / "for the product view see OVERVIEW.md").

Per-package READMEs are **opt-in per package**: create the README when there's enough surface in that package to warrant a focused doc. The freshness hook fires only when the README exists at HEAD — packages without one are silently skipped. No template-side scaffolding (apps/packages/functions land via `/ak-new-project` and are project-specific in shape); the skeleton below is the source of truth for content shape.

### Operational (on-demand)

Project-management state — read when planning, shipping, or triaging. Continuously updated.

| File                 | Role                                                                                                       | Loaded                                                |
| -------------------- | ---------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `PLAN.md`            | Forward plan at PR grain. § Active / § Planned.                                                            | On demand                                             |
| `BUILD-LOG.md`       | Shipped history. PRs in chronological order with what shipped + non-obvious context.                       | On demand                                             |
| `PRODUCT-ROADMAP.md` | Long-term / deferred features by version.                                                                  | On demand                                             |
| `TODOS.md`           | Tactical bugs/polish, organized by version + when-it-runs.                                                 | On demand                                             |
| `METRICS.md`         | Event taxonomy + feature flags. Updated alongside every new `posthog.capture` / `Sentry.captureException`. | On demand (and required by docs-freshness hook above) |

**Per-package README skeleton** (copy when creating a new one):

```markdown
# <package name>

> <one-sentence purpose>. Up to [OVERVIEW.md](../../OVERVIEW.md) for the product context, [ARCHITECTURE.md](../../ARCHITECTURE.md) for where this fits in the system.

## What's here

<one paragraph mapping the directory shape to module purpose>

## <Surface map — route map for apps, module map for packages, function list for supabase/functions>

| <surface> | <file path> | <purpose> |
| --------- | ----------- | --------- |
|           |             |           |

## Conventions

<package-specific rules: how components are structured, how exports are organized, what's allowed in public API, etc.>

-

## See also

- [OVERVIEW.md](../../OVERVIEW.md) — product context
- [ARCHITECTURE.md](../../ARCHITECTURE.md) — system view
- Other related per-package READMEs
```

### Authoring rules

**`CLAUDE.md § Where Things Happen`**: every new page, API wrapper, edge function, design token surface, or CI/CD workflow lands with a one-bullet entry naming the file path. Terse — one sentence + cross-references. Freshness hook enforces this on add.

**`CLAUDE.md § Gotchas`**: surfaces a non-obvious rule future sessions need before touching the relevant code (e.g., "RLS blocks direct inserts — use the RPC"). Add only when shipping work surfaces a real gotcha — not preemptively.

**`METRICS.md`**: every `posthog.capture(...)` or `Sentry.captureException(...)` call gets a row in the Events table. Properties listed; "why we care" sentence. Hook blocks PRs adding new event call-sites without staging.

**`OVERVIEW.md`**: update when a new user-visible flow lands, a feature category is added, or product scope changes (in vs out). Product-language only — engineering details belong in ARCHITECTURE.md.

**`ARCHITECTURE.md`**: update when a new package/app/edge-function module lands, a deployment-topology change ships, or an external-service dependency is added/removed. System-language only — product framing belongs in OVERVIEW.md.

**Per-package `README.md`**: update when a new file lands under that package's source tree (the freshness hook enforces this on add). Skeleton above is the source of truth — when a new per-package README is created, follow it.

### Template ships

`/devshop/template/` provides skeletons for every Always-loaded + Foundational repo-root file + every Operational file (`{CLAUDE,PLAN,BUILD-LOG,PRODUCT-ROADMAP,TODOS,METRICS,OVERVIEW,ARCHITECTURE}.md`) so new projects start with the right shape. `/ak-new-project` Step 12.6 + Step 16 fill in project-specific values for the older Operational files (CLAUDE, METRICS); OVERVIEW.md + ARCHITECTURE.md ship as-is and are populated as the project's product/system view solidifies. Per-package READMEs are NOT scaffolded by the template — they're created per-package when content warrants.
