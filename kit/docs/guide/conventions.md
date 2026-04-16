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

**What's tested vs. exempt:**

Every script in `kit/scripts/` is either tested or explicitly exempt in `check-test-coverage.sh`. Exempt scripts have documented reasons (e.g., `adversarial-review.sh` calls Claude CLI — non-deterministic, mocked in all callers; `init-devshop.sh` runs as root). The `check-test-coverage` pre-commit guard blocks new scripts without tests and warns on modified scripts without tests.

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
