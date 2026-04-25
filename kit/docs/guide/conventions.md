# Conventions

Single source of truth for conventions referenced by multiple skills. Skills point here, not copy.

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

`/ak-pre-ship` runs a `design-conformance` (ak) gate (between `design-review` and `qa`). The gate treats `DESIGN.md` as a contract: it LLM-extracts normative claims (explicit values, canonical examples, imperative rules, component contracts) and verifies each against the implementation. Complementary to `/design-review` (gstack), which covers visual hierarchy / spacing / AI-slop; this gate covers the orthogonal axes `/design-review` skips.

**Claim types** (see `.claude/skills/devshop/design-conformance/SKILL.md` for the extraction prompt):

- `explicit_value` — exact values: hex colors, pixel sizes, durations. Verified via `grep` across source roots.
- `canonical_example` — literal text the doc names as archetypal. Surfaces for human / LLM-judgment review.
- `imperative_rule` — "must / should / always / never" claims. Surfaces for judgment review.
- `component_contract` — declared props / classes / attributes. Surfaces for review.

**When the extractor returns zero claims** (DESIGN.md absent or purely aspirational), the gate emits `n/a` and the pipeline advances.

**Extraction is cached** by `sha256(DESIGN.md)` in `specs/<feature>/design-claims.json.sha256`. Changing DESIGN.md triggers re-extraction; the diff to the claims file requires adversarial review per the Phase 3 Dismissal Log contract so claim drift stays auditable.

**Authoring DESIGN.md for the gate**: no project-side markers required. If extraction over-produces noise, tune the skill's extraction prompt on the devshop side. Project DESIGN.md files stay framework-neutral.

## Screenshot Routing

Projects have three tracked locations for screenshots plus one gitignored sink. Each has a distinct purpose; routing matters because gate tooling and PR bodies assume these paths.

| Location                       | Tracked? | Who writes            | Purpose                                                                                       |
| ------------------------------ | -------- | --------------------- | --------------------------------------------------------------------------------------------- |
| `specs/<name>/hero/`           | ✅       | `/ak-pre-ship`, human | Durable product shots embedded in PR body + BUILD-LOG; one matrix per PR                      |
| `specs/<name>/screenshots/`    | ❌       | `/ak-pre-ship` gates  | Per-gate evidence (responsive check, design-review diffs); regenerable                        |
| `specs/<name>/qa-walk/`        | ❌       | `/ak-pre-ship` Gate 9 | Per-verb artifacts (`verb-<N>-<slug>.{png,json}`) proving each Core user story verb completed |
| `/screenshots/` (repo root)    | ❌       | human                 | Dev-context shots shared in a conversation / Slack / bug report; ephemeral                    |
| `/Screenshot*.png` (repo root) | ❌       | macOS                 | Caught by `.gitignore` so default-named drops don't pollute `git status`                      |

**When choosing where to put a shot, ask:**

1. Is it evidence for a specific PR, committed as part of the review package? → `specs/<name>/hero/`
2. Is it produced by a `/ak-pre-ship` gate (responsive, design-review, benchmark)? → `specs/<name>/screenshots/` (gate tooling writes here)
3. Is it context I'm sharing with Claude or a teammate right now, not tied to a PR? → `/screenshots/`
4. Is it README-banner / marketing / landing-page imagery? → **Not yet established** as a convention; surface when the first project needs one.

New projects get the `/screenshots/` folder + README template automatically via `/ak-new-project`. Existing projects inherit the `.gitignore` rules via `sync/from-devshop.sh` (manifest-tracked) but not the folder; copy from `template/screenshots/README.md` manually if you want it.

## Deploy Boundaries

Every Supabase-backed project has multiple deploy surfaces; deploying one does NOT deploy the others. This matters because `git push` / PR merge only triggers the Next.js app deploy — Supabase migrations, edge functions, and auth config stay untouched unless you run the corresponding command explicitly.

| Surface                 | How it deploys                                                                                                              | Trigger                                  | `/ak-go-live` covers? |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- | --------------------- |
| Next.js app (Vercel)    | Automatic on push — preview on PR, production on merge                                                                      | `git push` / PR merge                    | ✅                    |
| Supabase migrations     | `.github/workflows/deploy-migrations.yml` runs `supabase db push --include-roles` (path-filtered to `supabase/migrations/`) | Auto on push:main when migrations change | ✅ (via the merge)    |
| Supabase edge functions | `.github/workflows/deploy-functions.yml` runs `supabase functions deploy` per dir (path-filtered to `supabase/functions/`)  | Auto on push:main when functions change  | ✅ (via the merge)    |
| Supabase auth config    | Management API `/v1/projects/{ref}/config/auth` or dashboard                                                                | Manual, per change                       | ❌ (manual)           |

**Schema-mutating migrations need extra care.** The migrations + Vercel deploys race in parallel on push:main — fine for **schema-additive** migrations (new columns/tables, defaults, NOT NULL only on backfilled columns) because old code keeps working on the new schema. For **schema-mutating** migrations (renames, drops, NOT NULL without default, type changes), old code breaks the moment the migration lands and stays broken until the new code deploys. Two options:

1. **Mark the migration as backwards-incompatible in the PR description**, and gate merge on the deploy-migrations workflow finishing before approving the PR for `/ak-go-live`. The window where old code sees new schema is brief but non-zero — accept it, or
2. **Split the change into two PRs**: PR 1 ships an additive migration (new column/table) + new code paths that handle BOTH shapes. PR 2 ships the mutating migration + cleanup of the old paths. Slower but window-free.

Default to option 2 for production-impact mutating migrations; option 1 is fine for low-traffic windows on solo-dev projects.

**Surfaces that auto-deploy on push:main** (Next.js app, migrations, edge functions) all fire in parallel — there's no sequential ordering between them anymore. The schema-additive guidance above covers the migrations-vs-app race; the functions-vs-app race is symmetric (old app calling new function or vice versa) and follows the same backwards-compatibility-or-split-PR remedy.

**Auth config still needs to ship manually**, ideally before the app deploy if the new code relies on new redirect URLs / CAPTCHA / password policy. PATCH `/v1/projects/{ref}/config/auth` or use the dashboard. Auth-config changes are cheap to roll back (re-PATCH) so ordering is flexible.

**Rollback** is reverse-order with the same backwards-compatibility caveats: revert the app first to pull traffic off the new surfaces, then roll back migrations (if the migration's `-- ROLLBACK` block supports it) and edge functions.

## Supabase Hardening Defaults

What `/ak-new-project` Step 17b applies to every new Supabase project, and why:

| Setting                    | Default (free-tier)     | Hardened                           | Rationale                                                                                                                                                |
| -------------------------- | ----------------------- | ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `password_min_length`      | 6                       | 8                                  | 6 is below published password-policy floors (NIST 800-63B minimum is 8). Non-breaking for new projects; existing users are grandfathered.                |
| `security_captcha_enabled` | `false`                 | `true` (if secret provided)        | CAPTCHA blocks automated signup abuse (credential stuffing, spam-account creation). Interactive because it needs an hCaptcha secret per project.         |
| `site_url`                 | `http://localhost:3000` | production URL                     | Every email-based auth flow (password recovery, magic link, email change, signup confirm) redirects via `site_url`. Stale `localhost` = silent breakage. |
| `uri_allow_list`           | empty                   | prod + Vercel wildcard + localhost | Supabase rejects auth redirects outside this list. Must include the Vercel preview-deploy wildcard so PR previews can exercise the full auth flow.       |

Not touched (intentional):

- `rate_limit_email_sent` stays at the free-tier default (2/hour). Raising requires custom SMTP (per-project decision, production-launch concern).
- `disable_signup` stays `false`. Invite-code alternative is a separate roadmap item (`kit/ROADMAP.md § v1 § Invite-code signup control`).

### ON DELETE on `auth.users` FK references

Any schema table that references `auth.users(id)` MUST specify the `ON DELETE` action explicitly — `CASCADE`, `SET NULL` (column must be nullable), or `RESTRICT`. Never leave it implicit.

Postgres defaults to `NO ACTION`, which silently blocks user deletion as soon as any dependent row exists. Supabase's Authentication UI surfaces this as the opaque "Database error deleting user" — the operator's only recourse is to go hunt down every FK and delete the dependent rows manually, or change the constraint (which requires DDL, which requires another migration).

Recommended defaults by column meaning:

- **`added_by` / audit columns** → `ON DELETE SET NULL` (preserve history, lose attribution).
- **Tight ownership columns** (row doesn't make sense without the user) → `ON DELETE CASCADE`.
- **Rare case: must keep row AND must have a user** → `ON DELETE RESTRICT` (forces an explicit decision at user-deletion time; worst UX but most explicit).

Every schema reviewer and `/ak-pre-ship` migration gate should reject a migration where a `references auth.users(id)` lacks an explicit `ON DELETE` clause — it's a latent bug, not a design choice.

## Confidence Calibration

### Proceed autonomously

- UI components + their tests
- Extending existing API endpoints
- Bug fixes with clear root cause + confirming test
- Styling / design token changes
- Documentation updates
- Adding new Supabase queries (no schema changes)
- Instrumenting metrics for events already defined in METRICS.md

### Stop and ask (before implementing)

- New database columns/tables (migrations are hard to reverse)
- Auth flow changes
- New third-party API integrations not yet in codebase
- Performance-sensitive code paths
- Security-related logic — stop before writing, get human sign-off; `/cso` still runs after
- Anything requiring deletion of existing tests
- New metric event definitions (add to METRICS.md requires review)

## TODO Protocol

- **Blocker** (can't complete task without human input) → stop, add to `TODOS.md` with `[blocked]` tag, mark task `blocked` in tasks.md, ping user
- **Out-of-scope discovery** (real bug or feature, but not in current spec) → route per backlog guide below, skip, continue
- **Minor issue** (< 5 min to fix) → fix in current task's commit, note in commit message
- **Minor issue** (> 5 min to fix) → add to `TODOS.md` with `[minor]` tag, continue

## Backlog Routing Guide

Two questions decide where deferred work goes:

1. **Who cares?** App user → project row. Dev using the devshop → devshop row.
2. **When?** Fix/do soon → TODO. Build eventually → ROADMAP.

|             | Tactical       | Strategic            |
| ----------- | -------------- | -------------------- |
| **Project** | `TODOS.md`     | `PRODUCT-ROADMAP.md` |
| **Devshop** | `kit/TODOS.md` | `kit/ROADMAP.md`     |

TODO items can be scheduled into versions defined in their corresponding ROADMAP (e.g., `[v0.2]`, `[v2]`). Project files never reference devshop files.

**When a roadmap item ships**: remove it from the roadmap entirely and log the completion in `BUILD-LOG.md`. Roadmaps only show what's ahead — `BUILD-LOG.md` is the record of what was done.

---

## Non-Negotiables

### Testing

- **No code without tests** — written alongside, never after.
- **No code that breaks existing tests** — full test suite runs before marking done.
- **Testing layers**:
  - Unit tests (`*.test.ts`): mock external dependencies. Pure business logic only — validation, transforms, calculations.
  - Integration tests (`*.integration.test.ts`): must hit a real local database (Docker-in-Docker). Never mock the DB layer for queries, access control, or data integrity. Supabase: `supabase start`. Other: Docker Compose.
  - E2E tests: required for every user-facing flow. Playwright runs at 375px (mobile) and 1440px (desktop). Both must pass.
- **Test commands**: `pnpm turbo run test:unit` (unit only, no DB) vs `pnpm turbo run test` (unit + integration, needs local DB). Use `test:unit` for the fast inner loop; `test` for full verification.
- **Auth boundary tests (RLS)**: every table with RLS policies must have at least one integration test — authenticate as User A, create data, authenticate as User B, verify data is NOT visible. RLS bugs are silent data leaks; mocked tests can never catch them.
- **`seed.sql`**: minimum test fixtures for integration tests. Must include at least 2 users with different access levels (e.g., different households or roles) for RLS boundary testing — User A's data must be invisible to User B. Include representative data for each table with RLS policies. Loaded by `supabase start` automatically and by CI before running integration tests.
- **CI enforcement lands in the same PR as the code it tests** — no gap between "tests exist" and "CI runs them."
- **CI mirrors runtime**: if the app uses a DB at runtime, CI starts it locally. Never skip integration tests because "they work locally." Never hit shared remote environments from CI. Supabase: `supabase start` + `seed.sql` + type drift check + mask `SUPABASE_SERVICE_ROLE_KEY`.
- **Type drift check**: CI regenerates types from schema and fails if committed types have drifted.
- **QA-backend isolation** (which Supabase flavor dev / CI / pre-ship point at): see [kit/notes/roadmap/qa-options.md](../../notes/roadmap/qa-options.md) for the 6-option backend matrix (local / preview branches / staging / testcontainers / mocks / hybrid), 4-layer enforcement stack (firewall / credential split / URL guard / branch protection), and the 5-surface map of where QA happens across `/ak-implement`, `/ak-pre-ship`, CI fast/slow jobs, and `/canary`.

### Test Assertion Depth

Every test that asserts on **state shape, array length, mock-call count, or internal reducer output** must also assert on **user-visible rendered output** — text content (`getByText`, `toHaveTextContent`), role (`getByRole`), or accessibility attributes (`getByLabelText`, `toHaveAccessibleName`). Shape assertion without a matching DOM assertion is a class-of-bugs anti-pattern: the state machine reports success while the user sees a broken UI (the lalista core-flows blank-row race — `entries.length === 1` passed, the user saw an empty row).

**Escape hatch** — for genuinely-no-render code (pure-state reducers, internal data transforms, utility functions), a test-file comment stating the rationale bypasses the rule:

```ts
// shape-only: pure reducer, no render path
test('addItem appends to entries', () => {
  expect(reducer(state, addItem('milk')).entries).toHaveLength(1);
});
```

The comment must name the absence of user-visible output. Generic bypasses (`// shape-only: test simple state`, `// shape-only: obvious from context`) are rejected by `/ak-test-review` (Gate 5).

**Scope** — `/ak-test-review` enforces this only on tests added or modified in the current PR's diff. Grandfathered tests in untouched files are not retroactively flagged; conversion of legacy shape-only tests is tracked in `TODOS.md` if it ever becomes worth the churn.

**Why this exists** — Phase 1's Gate 9 artifact assertion (qa-walk per-verb evidence) catches missing-DOM-output bugs _if_ the harness captures DOM state. This rule moves the catch one level up so even unit tests fail fast when "code did a thing" diverges from "user sees the right thing." See `.claude/skills/devshop/test-review/SKILL.md § Shape-only assertions`.

### Testing Lifecycle

| Stage                | What runs                                           | Needs DB?          | Blocking?                             |
| -------------------- | --------------------------------------------------- | ------------------ | ------------------------------------- |
| Per-task (local)     | `test:unit`                                         | No                 | Yes — task not done until green       |
| Pre-commit (husky)   | lint-staged + typecheck + gitleaks + devshop guards | No                 | Yes — commit blocked                  |
| Pre-tool (Claude)    | DCG only (shell hooks can't block Bash calls)       | No                 | Yes — DCG blocks destructive commands |
| Post-commit (Claude) | dirty-tree + cross-repo reminder                    | No                 | No — advisory context                 |
| CI fast (every push) | Lint + types + `test:unit` + build                  | No                 | Yes — shows red on PR                 |
| CI slow (PR to main) | `test` (unit+integration) + E2E + type drift        | Yes (CI starts it) | Yes — merge blocked                   |
| `/ak-pre-ship`       | `/ak-test-review` (reads tests) + `/qa` (browser)   | App running        | Pauses on findings                    |

Unit tests are the fast inner loop (local + CI fast). Integration + E2E are the outer gate (CI slow). No env var needed — the command you run is the mode.

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

1. **Per-commit (pre-commit chain):** BATS runs the full test suite (~6s). Catches regressions immediately. The `check-test-coverage` guard blocks new scripts without test files and warns on modified scripts without test files.
2. **Per-release (release.sh):** Semantic test coverage review via adversarial agent. Compares the functional diff since the last tag against the test suite's `@test` names. Catches new code paths, changed exit codes, or new options that existing tests don't exercise. Blocks the release if coverage gaps are found. This avoids the cost of a Sonnet call on every commit while still catching gaps before they ship.

**What's tested vs. exempt:**

Every script in `kit/scripts/` is either tested or explicitly exempt in `check-test-coverage.sh`. Exempt scripts have documented reasons (e.g., `adversarial-review.sh` calls Claude CLI — non-deterministic, mocked in all callers; `init-devshop.sh` runs as root).

**How tests mock external dependencies:**

- `adversarial-review.sh` (Claude Sonnet) → PATH-first stub returning PASS/FAIL
- Git state → throwaway repos in `$BATS_TMPDIR` with controlled staging
- Cross-repo checks → disabled via wrapper sed or fake repos
- `GIT_CONFIG_PARAMETERS` → unset to isolate from parent commit's `-c` flags

**Adding tests for a new script:**

1. Create `kit/tests/guard-<name>.bats` or `kit/tests/util-<name>.bats`
2. Use `load helpers/setup` for shared helpers (mock bin, test repos, adversarial stubs)
3. If the script is genuinely untestable, add to the exempt list in `check-test-coverage.sh` with a reason

### Metrics

- **No code without metrics** — every user-facing feature must have events in `METRICS.md`, instrumented in the same PR.

### Responsive + Theme

- **Responsive from day one** — works (not just renders) from iPhone SE (375px) to large desktop (2560px). Mobile-first. `packages/ui/src/tokens.ts` defines breakpoints as single source of truth; `tailwind.config.js` reads them. No hardcoded pixel widths. Playwright E2E runs at mobile + desktop. Snapshot tests include both variants.
- **Light/dark theme required** — both from launch. `tokens.ts` defines semantic theme tokens. Tailwind maps to CSS custom properties. Theme follows `prefers-color-scheme` with optional toggle. No hardcoded colors — always theme tokens. Snapshots include both themes.

### PWA

- **PWA-installable** — `manifest.json`, Apple meta tags. "Add to Home Screen" works on iOS/Android. Service worker caching (`@serwist/next`) deferred to `PRODUCT-ROADMAP.md` — added after core screens are stable to avoid stale-data bugs during active development. Placeholder icons at scaffold; replaced with real branding during design system migration.

### Code Structure

- **Shared packages export TypeScript source directly** — `"main": "src/index.ts"`. Each consuming app transpiles. Every package has a `src/index.ts` barrel export. No deep path imports across package boundaries.
- **File documentation**: every non-trivial `.ts`/`.tsx` file under `src/` or `app/` has a 3-line header (`// What:` / `// Why:` / `// Does NOT:`). Every exported function has 1-2 sentence JSDoc (enforced by ESLint via `eslint-plugin-jsdoc`). Internal/private: no doc required. Config files (`*.config.*`, `*.d.ts`) are exempt. Headers are checked by `/ak-pre-ship` convention check, not pre-commit — mechanical enforcement produces mechanical documentation.
- **Implementation approach**: default to simple. Boring solution. Tried-and-true over clever. Readable over optimal.
- **ESLint for code quality only** — Prettier owns all formatting.
