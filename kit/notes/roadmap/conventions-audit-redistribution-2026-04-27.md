# conventions.md Redistribution Audit — 2026-04-27

## Goal

`conventions.md` collects cross-skill conventions, but operational rules buried there don't fire — the agent forgets them and skill gates don't catch the omissions. This audit classifies every `## ` section as Tier 1 (always-fires, belongs in CLAUDE.md or every relevant SKILL.md), Tier 2 (fires when a specific surface is touched, belongs inlined into the owning skill's SKILL.md), or Tier 3 (reference / taxonomy / aspirational, stays in conventions.md as the canonical source). For each Tier 1 / Tier 2 section, the proposal names the target SKILL.md path and extracts the load-bearing rule text to inline.

## Summary table

| Section                                                | Tier                                  | Proposed target(s)                                                                                                                                                    | Rationale (one line)                                                                                                                                       |
| ------------------------------------------------------ | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Metrics Lifecycle                                      | 2                                     | `/devshop/.claude/skills/devshop/spec/SKILL.md`, `/devshop/.claude/skills/devshop/implement/SKILL.md`, `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`            | Each lifecycle stage fires inside one specific skill; the rules need to fire there, not be discovered by reference.                                        |
| Metrics principles (subsection)                        | 3                                     | conventions.md (stays)                                                                                                                                                | Authoring guidance for METRICS.md content — read once, applied broadly; no fire moment per skill.                                                          |
| METRICS.md structure (subsection)                      | 3                                     | conventions.md (stays)                                                                                                                                                | Pure schema / template — reference-only.                                                                                                                   |
| TASKS.md Format                                        | 3                                     | conventions.md (stays)                                                                                                                                                | Already a pure pointer to the implement skill; no operational rule lives here.                                                                             |
| SPEC.md Quality Checklist                              | 3                                     | conventions.md (stays)                                                                                                                                                | Pointer to spec skill; nothing to inline.                                                                                                                  |
| DESIGN.md as Contract (`design-conformance` gate)      | 2                                     | `/devshop/.claude/skills/devshop/design-conformance/SKILL.md`, `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`                                                    | Claim-extraction taxonomy + cache-invalidation rule fires inside the gate; pre-ship orchestrates it.                                                       |
| Screenshot Routing                                     | 2                                     | `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`, `/devshop/.claude/skills/devshop/spec/SKILL.md`                                                                  | Routing decision fires when a gate writes a screenshot or when a spec drafts evidence paths.                                                               |
| Deploy Boundaries                                      | 2 (borderline 1)                      | `/devshop/.claude/skills/devshop/spec/SKILL.md`, `/devshop/.claude/skills/devshop/go-live/SKILL.md`, `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`              | Schema-mutating-migration rule + auth-config manual-deploy rule fire when migrations / functions / auth touched.                                           |
| Slow-Job Lifecycle                                     | 2 (already-shipped skill-side inline) | `/devshop/.claude/skills/devshop/pre-ship/SKILL.md` (gate `slow-job-lifecycle` already inlined; see `pre-ship/SKILL.md:311-330`)                                      | Skill-side enforcement already exists; convention.md role becomes worked-example reference.                                                                |
| Supabase Hardening Defaults                            | 2                                     | `/devshop/.claude/skills/devshop/new-project/SKILL.md`, `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`                                                           | Defaults fire at scaffold; ON DELETE / Realtime publication rules fire on every migration.                                                                 |
| ON DELETE on `auth.users` FK references (subsection)   | 1                                     | `/workspace/CLAUDE.md` (or template's `CLAUDE.md`), `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`, `/devshop/.claude/skills/devshop/implement/SKILL.md`         | Fires on every migration touching `auth.users` FKs — common, silent, and easy to miss. Belongs in CLAUDE.md if any project reliably touches Supabase auth. |
| Realtime publication setup (subsection)                | 2                                     | `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`, `/devshop/.claude/skills/devshop/implement/SKILL.md`                                                             | Fires only when adding a Realtime subscription helper; rare but silent on miss.                                                                            |
| SSR + E2E boilerplate canonical patterns (subsection)  | 3                                     | conventions.md (stays)                                                                                                                                                | Pointer to `kit/docs/guide/supabase-ssr-boilerplate.md` — taxonomy / index, not a rule itself.                                                             |
| Runtime Validation at LLM / Edge-Function Boundaries   | 2                                     | `/devshop/.claude/skills/devshop/implement/SKILL.md`, `/devshop/.claude/skills/devshop/test-review/SKILL.md`, `/devshop/.claude/skills/devshop/new-project/SKILL.md`  | Schema/wrapper pattern fires on every new edge function or LLM-backed endpoint; new-project owns the scaffold step.                                        |
| Wrapper API design                                     | 2 (already-shipped skill-side inline) | `/devshop/.claude/skills/devshop/test-review/SKILL.md` (deterministic check already inlined; see `test-review/SKILL.md:83-108`)                                       | Skill-side enforcement already exists; convention.md role becomes worked-example reference.                                                                |
| Confidence Calibration                                 | 2                                     | `/devshop/.claude/skills/devshop/spec/SKILL.md`, `/devshop/.claude/skills/devshop/implement/SKILL.md`                                                                 | "Stop and ask" decision fires every spec / every implement step; belongs in those SKILL.mds inline.                                                        |
| TODO Protocol                                          | 1                                     | `/workspace/CLAUDE.md` (project) + `/devshop/CLAUDE.md` (devshop) — already partially codified there                                                                  | Fires every time the agent encounters a discovery during any task; belongs in always-loaded context.                                                       |
| Backlog Routing Guide                                  | 1                                     | `/workspace/CLAUDE.md` + `/devshop/CLAUDE.md` (already partially there)                                                                                               | Same — fires on every task with a discovery / deferred-work decision.                                                                                      |
| Non-Negotiables — Testing                              | 1                                     | `/workspace/CLAUDE.md` + every skill that writes tests (`/devshop/.claude/skills/devshop/implement/SKILL.md`, `/devshop/.claude/skills/devshop/test-review/SKILL.md`) | "No code without tests" / RLS coverage / type drift fire on every coding task.                                                                             |
| Non-Negotiables — Test Assertion Depth                 | 2 (already-shipped skill-side inline) | `/devshop/.claude/skills/devshop/test-review/SKILL.md` (already inlined as Gate 5; see Gotchas / convention)                                                          | Skill enforces the rule; conventions.md is reference for the rule's rationale.                                                                             |
| Non-Negotiables — Testing Lifecycle                    | 3                                     | conventions.md (stays)                                                                                                                                                | Lifecycle table is a reference taxonomy mapping stages to commands; not a rule that fires.                                                                 |
| Non-Negotiables — Kit Testing (devshop infrastructure) | 3                                     | conventions.md (stays) — also referenced from `/devshop/CLAUDE.md`                                                                                                    | Pure reference for BATS conventions inside the devshop repo; not a project-level rule.                                                                     |
| Non-Negotiables — Metrics                              | 1                                     | `/workspace/CLAUDE.md` + `/devshop/.claude/skills/devshop/implement/SKILL.md` + `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`                                   | "No code without metrics" fires on every user-facing PR.                                                                                                   |
| Non-Negotiables — Responsive + Theme                   | 1                                     | `/workspace/CLAUDE.md` + `/devshop/.claude/skills/devshop/implement/SKILL.md`                                                                                         | Mobile-first / dual-theme is a structural rule that fires on every component change.                                                                       |
| Non-Negotiables — PWA                                  | 2                                     | `/devshop/.claude/skills/devshop/new-project/SKILL.md`                                                                                                                | Fires only at scaffold; afterwards mostly latent.                                                                                                          |
| Non-Negotiables — Code Structure                       | 1                                     | `/workspace/CLAUDE.md` + `/devshop/.claude/skills/devshop/implement/SKILL.md` + `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`                                   | File-header / barrel-export / "boring solution" rules fire on every file added.                                                                            |

## Per-section detail (Tier 1 / Tier 2)

### Metrics Lifecycle — Tier 2

**Rule to inline (per skill):**

- `/ak-spec` (`/devshop/.claude/skills/devshop/spec/SKILL.md`): "On first run, draft `METRICS.md` taxonomy from autoplan output and ask user to confirm. On subsequent runs, propose new events when features introduce new user actions — new event definitions are always a 'stop and ask' item."
- `/ak-implement` (`/devshop/.claude/skills/devshop/implement/SKILL.md`): "Instrument `posthog.capture()` calls for every event referenced in the spec's Metrics section. Instrumented alongside code, never after."
- `/ak-pre-ship` (`/devshop/.claude/skills/devshop/pre-ship/SKILL.md`): "Cross-reference user-facing code against `METRICS.md`. Pause if a user-facing PR is missing instrumentation."

**Leave behind in conventions.md:** the lifecycle taxonomy (the four-point flow chart) as canonical reference. Each skill SKILL.md has a one-line back-reference to `conventions.md § Metrics Lifecycle`.

### DESIGN.md as Contract — Tier 2

**Rule to inline:**

- `/devshop/.claude/skills/devshop/design-conformance/SKILL.md`: "Extraction is cached by `sha256(DESIGN.md)` in `specs/<feature>/design-claims.json.sha256`. When DESIGN.md changes, re-extract and adversarially review the diff per the Phase 3 Dismissal Log so claim drift stays auditable. When the extractor returns zero claims, emit `n/a` and advance."
- `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`: "Run `design-conformance` between `design-review` and `qa`. The gate treats DESIGN.md as a contract — extraction failure is non-blocking; claim-violation is blocking."

**Leave behind in conventions.md:** the four claim types (`explicit_value`, `canonical_example`, `imperative_rule`, `component_contract`) as taxonomy reference plus the framing narrative.

### Screenshot Routing — Tier 2

**Rule to inline:**

- `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`: "When writing a gate-produced screenshot: per-gate evidence → `specs/<name>/screenshots/`; Gate 9 per-verb artifacts → `specs/<name>/qa-walk/`; durable PR-body shots → `specs/<name>/hero/`. Never write to repo root; root `/Screenshot*.png` is gitignored."
- `/devshop/.claude/skills/devshop/spec/SKILL.md`: "When the spec references screenshot paths, use the table-defined locations; never invent new paths."

**Leave behind in conventions.md:** the four-row table + the four-question decision flow (which is genuinely useful prose for a human reader confronting an ambiguous shot).

### Deploy Boundaries — Tier 2 (borderline 1)

**Rule to inline:**

- `/devshop/.claude/skills/devshop/spec/SKILL.md`: "If the spec includes a schema-mutating migration (rename, drop, NOT NULL without default, type change), the spec's test plan MUST either (a) flag the migration as backwards-incompatible and gate `/ak-go-live` on the deploy-migrations workflow finishing first, or (b) split into two PRs — additive PR first, mutating PR after the dual-shape code paths land. Default to option (b) for prod-impact migrations."
- `/devshop/.claude/skills/devshop/go-live/SKILL.md`: "Auth-config changes still need to ship manually via Management API or dashboard before the app deploy. Migrations + functions + Vercel app all auto-deploy on push:main; rollback is reverse-order with the same backwards-compatibility caveats."
- `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`: "If the PR touches `supabase/migrations/**` or `supabase/functions/**`, surface the deploy-boundary checklist as a pre-ship reminder so the test plan flags any backwards-incompatible change."

**Leave behind in conventions.md:** the surface table (Vercel / migrations / functions / auth-config) as the canonical reference + the CI-vs-prod credential separation paragraph (which is rationale, not a fire-moment rule).

### Slow-Job Lifecycle — Tier 2 (already-shipped skill-side inline)

**Status:** already done in this session. `/devshop/.claude/skills/devshop/pre-ship/SKILL.md § Gate slow-job-lifecycle (lines 311-330)` enforces the convention; the slow-job-lifecycle-check.sh script does the mechanical work. The conventions.md section now serves as the worked-example / rationale reference (Phase 1c/1g threshold story, lalista PR-26 edge-runtime retry context).

**No further redistribution needed.** A future executor should NOT duplicate the gate's checklist into another skill.

### Supabase Hardening Defaults — Tier 2

**Rule to inline:**

- `/devshop/.claude/skills/devshop/new-project/SKILL.md` Step 17b: "Apply hardened defaults — `password_min_length=8`, `security_captcha_enabled=true` (if hCaptcha secret provided), `site_url=<production URL>`, `uri_allow_list=<prod + Vercel preview wildcard + localhost>`. Don't touch `rate_limit_email_sent` or `disable_signup`."
- `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`: "If the PR adds a migration referencing `auth.users(id)`, fail the migration-review gate when `ON DELETE` is implicit (defaults to `NO ACTION` and silently blocks user deletion). Require explicit `CASCADE` / `SET NULL` / `RESTRICT`."

**Leave behind in conventions.md:** the hardened-defaults table + rationale column (each row's "why" is too long for an inlined rule and is genuinely educational).

### ON DELETE on `auth.users` FK references — Tier 1

**Rule to inline:**

- `/workspace/CLAUDE.md § Gotchas` (or each project's CLAUDE.md): "Any schema table referencing `auth.users(id)` MUST specify `ON DELETE` explicitly — `CASCADE`, `SET NULL` (column nullable), or `RESTRICT`. Implicit defaults to `NO ACTION` and silently blocks user deletion. Recommended: audit columns → `SET NULL`, ownership columns → `CASCADE`, must-keep-row-and-must-have-user → `RESTRICT`."
- `/devshop/.claude/skills/devshop/pre-ship/SKILL.md` migration-review gate: same rule, mechanical grep of staged `supabase/migrations/**`.
- `/devshop/.claude/skills/devshop/implement/SKILL.md`: same rule, restated as a pre-write check when the implementer adds a migration.

**Leave behind in conventions.md:** the recommended-defaults explanation (audit / ownership / rare case) plus the "why this exists" Postgres-default narrative.

### Realtime publication setup — Tier 2

**Rule to inline:**

- `/devshop/.claude/skills/devshop/pre-ship/SKILL.md` migration-review gate: "If a PR adds a `subscribeTo<X>` helper or `postgres_changes` listener, verify the table is added to `supabase_realtime` publication via a migration. Without it, cross-session delivery silently no-ops."
- `/devshop/.claude/skills/devshop/implement/SKILL.md`: "When adding a Realtime helper, also add the publication migration in the same PR with the canonical `alter publication ... add table ...` shape including a ROLLBACK block."

**Leave behind in conventions.md:** the canonical SQL snippet + the "older Supabase CLI versions auto-included…" rationale paragraph + the lalista PR 26 prior-art pointer.

### Runtime Validation at LLM / Edge-Function Boundaries — Tier 2

**Rule to inline:**

- `/devshop/.claude/skills/devshop/implement/SKILL.md`: "When adding an LLM-backed edge function call or any third-party HTTP fetch with hand-written response shape: parse with Zod at the wrapper boundary in `packages/core/src/api/<feature>.ts`. Use `.safeParse()` (never `.parse()`); throw a feature-named `{Feature}ValidationError`; capture to Sentry with scrubbed payload excerpt before throwing. Do NOT add Zod to PostgREST results, form input, or app-internal function args."
- `/devshop/.claude/skills/devshop/test-review/SKILL.md`: "If a PR adds a wrapper around `client.functions.invoke<T>(...)` or a `fetch().json() as T` returning a hand-written shape, flag missing Zod parse as critical."
- `/devshop/.claude/skills/devshop/new-project/SKILL.md` scaffold: "Add Zod to `packages/core/package.json` and create `packages/core/src/schemas/` with a README pointing at `conventions.md § Runtime Validation`."

**Leave behind in conventions.md:** the Where-to-add-it table (where Zod helps vs where it's paranoia), the schema-module pattern with code example, and the wrapper-boundary worked example. These are the educational core.

### Wrapper API design — Tier 2 (already-shipped skill-side inline)

**Status:** already done in this session. `/devshop/.claude/skills/devshop/test-review/SKILL.md § Wrapper API design — lifecycle events not just data (lines 83-108)` already implements the deterministic check. The conventions.md section serves as the worked-example / rationale reference (lalista PR 27 prior art).

**No further redistribution needed.** A future executor should NOT duplicate the check into another skill.

### Confidence Calibration — Tier 2

**Rule to inline:**

- `/devshop/.claude/skills/devshop/spec/SKILL.md`: "When drafting a spec, classify each item as proceed-autonomously vs stop-and-ask using the calibration list. The seven stop-and-ask categories (new DB columns, auth flow changes, new third-party APIs, performance-sensitive paths, security logic, deletion of existing tests, new METRICS.md events) become spec-level decision rows requiring user sign-off before `/ak-implement` runs."
- `/devshop/.claude/skills/devshop/implement/SKILL.md`: "Before implementing, re-verify the spec's stop-and-ask items have user approval. Adding a new metric event mid-implementation triggers a pause."

**Leave behind in conventions.md:** the two bulleted lists (proceed / stop-and-ask) as the canonical taxonomy.

### TODO Protocol — Tier 1

**Rule to inline:**

- `/workspace/CLAUDE.md`: "Blocker (can't complete) → stop, add to `TODOS.md` with `[blocked]` tag, mark task blocked, ping user. Out-of-scope discovery → route per backlog guide, skip, continue. Minor < 5 min → fix in current commit. Minor > 5 min → add to `TODOS.md` with `[minor]` tag, continue."
- `/devshop/CLAUDE.md`: identical text (already partially present — verify and align).

**Leave behind in conventions.md:** keep the rule body as canonical phrasing. Project CLAUDE.md restates inline.

### Backlog Routing Guide — Tier 1

**Rule to inline:**

- `/workspace/CLAUDE.md` + `/devshop/CLAUDE.md`: "Two questions: (1) Who cares? App user → project row. Devshop user → devshop row. (2) When? Soon → TODO. Eventually → ROADMAP. The 2x2 routing table follows; project files never reference devshop files. When a roadmap item ships, delete from roadmap and log in BUILD-LOG.md."

**Leave behind in conventions.md:** keep the 2x2 table + the closure-protocol pointer.

### Non-Negotiables — Testing — Tier 1

**Rule to inline:**

- `/workspace/CLAUDE.md`: "No code without tests, written alongside. No code that breaks existing tests. Three layers: unit (`*.test.ts`), integration (`*.integration.test.ts`, real local DB), E2E (Playwright at 375px + 1440px both must pass). Auth-boundary RLS test required for every RLS-policied table. CI mirrors runtime. Type-drift check enforces regenerated types."
- `/devshop/.claude/skills/devshop/implement/SKILL.md`: same rules, restated as a pre-write check.
- `/devshop/.claude/skills/devshop/test-review/SKILL.md`: same rules, used as the audit checklist.

**Leave behind in conventions.md:** the full bulleted Non-Negotiables list as canonical reference + the QA-backend isolation pointer to qa-options.md.

### Non-Negotiables — Test Assertion Depth — Tier 2 (already-shipped skill-side inline)

**Status:** already inlined in `/devshop/.claude/skills/devshop/test-review/SKILL.md` as Gate 5. Conventions.md section becomes the rule's rationale reference (lalista core-flows blank-row race).

**No further redistribution needed.**

### Non-Negotiables — Metrics — Tier 1

**Rule to inline:**

- `/workspace/CLAUDE.md`: "No code without metrics — every user-facing feature has events in `METRICS.md`, instrumented in the same PR."
- `/devshop/.claude/skills/devshop/implement/SKILL.md` + `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`: same.

**Leave behind in conventions.md:** keep as one-line rule alongside the lifecycle (already cross-references).

### Non-Negotiables — Responsive + Theme — Tier 1

**Rule to inline:**

- `/workspace/CLAUDE.md`: "Responsive from day one (375px to 2560px), mobile-first, no hardcoded pixel widths, breakpoints from `packages/ui/src/tokens.ts`. Light/dark theme required, no hardcoded colors, snapshots include both themes."
- `/devshop/.claude/skills/devshop/implement/SKILL.md`: same, restated as pre-write check on every component.

**Leave behind in conventions.md:** keep as canonical reference; mention `tokens.ts` is single source of truth.

### Non-Negotiables — PWA — Tier 2

**Rule to inline:**

- `/devshop/.claude/skills/devshop/new-project/SKILL.md`: "Add `manifest.json`, Apple meta tags, placeholder icons at scaffold. Service worker (`@serwist/next`) is deferred to PRODUCT-ROADMAP — don't add at scaffold."

**Leave behind in conventions.md:** the rationale paragraph (deferred for stale-data-bug avoidance).

### Non-Negotiables — Code Structure — Tier 1

**Rule to inline:**

- `/workspace/CLAUDE.md`: "Shared packages export TypeScript source directly (`main: src/index.ts`); every package has a `src/index.ts` barrel; no deep path imports across package boundaries. Every non-trivial `.ts`/`.tsx` under `src/` or `app/` has a 3-line header (What / Why / Does NOT). Every exported function has 1-2 sentence JSDoc. Default to simple / boring solutions. ESLint for code quality only — Prettier owns formatting."
- `/devshop/.claude/skills/devshop/implement/SKILL.md`: same, restated as pre-write check.
- `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`: convention check gate already enforces file-header shape; restate inline.

**Leave behind in conventions.md:** keep the full bulleted list as canonical reference.

## Tier 3 stays put

These sections stay in conventions.md as canonical reference; SKILL.mds back-reference them but do not inline:

- **Metrics principles** (subsection of Metrics Lifecycle) — METRICS.md authoring guidance
- **METRICS.md structure** (subsection) — pure schema template
- **TASKS.md Format** — pointer to implement skill
- **SPEC.md Quality Checklist** — pointer to spec skill
- **SSR + E2E boilerplate canonical patterns** (subsection of Supabase Hardening Defaults) — pointer to `kit/docs/guide/supabase-ssr-boilerplate.md`
- **Non-Negotiables — Testing Lifecycle** — table mapping stages to commands; reference taxonomy
- **Non-Negotiables — Kit Testing (devshop infrastructure)** — BATS conventions for the devshop repo only

## Sequencing notes

1. **Wrapper API design and Slow-Job Lifecycle are already done in this session.** Convention text stays as worked-example reference; do not duplicate the deterministic checks elsewhere. (test-review/SKILL.md:83-108; pre-ship/SKILL.md:311-330)

2. **CLAUDE.md edits unblock SKILL.md cross-references.** The Tier 1 sections (TODO Protocol, Backlog Routing, Testing, Metrics, Responsive+Theme, Code Structure, ON DELETE) should be inlined into the project's CLAUDE.md (and `/devshop/CLAUDE.md` for devshop-side rules) FIRST, because each SKILL.md inline restatement should reference "see CLAUDE.md § X" for the canonical phrasing rather than triplicating text. Do CLAUDE.md, then skills.

3. **`/ak-spec` is touched by 6 sections** (Metrics Lifecycle, Screenshot Routing, Deploy Boundaries, Confidence Calibration, plus Tier-1 forwards) — batch the spec/SKILL.md edits to avoid five separate diff churn.

4. **`/ak-pre-ship` is touched by 8 sections** (Metrics, DESIGN.md, Screenshot, Deploy Boundaries, Hardening Defaults, ON DELETE, Realtime publication, Code Structure, Metrics) — batch likewise. Two existing gates (`design-conformance`, `slow-job-lifecycle`) already cover their conventions; new inlining lands as additional gate descriptions or as preflight reminders, not duplicates.

5. **`/ak-implement` is touched by 7 sections** — batch likewise. Most are pre-write checks; a single "Conventions to honor on every implement step" subsection inside its SKILL.md probably suffices, restating the load-bearing rules with one-line back-references to conventions.md.

6. **`/ak-new-project`'s scaffold step** absorbs three Tier 2 sections (Hardening Defaults Step 17b, Runtime Validation Zod scaffold, PWA placeholder) — verify each is already in the new-project Step list before adding; some may be present already.

7. **No skill needs creation.** All targets are existing skill paths verified via `ls /devshop/.claude/skills/devshop/`.
