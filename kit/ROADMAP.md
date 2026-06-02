# Devshop Roadmap

Devshop capabilities to build eventually — how you build, not what you ship.
Tactical fixes go in `TODOS.md`. Project features go in root `PRODUCT-ROADMAP.md`.

Priority tiers:

- **v0** — fixes the current template needs before a second project adopts it. Each exists because the first template-validation project (lalista) surfaced a gap every future project will hit. Factoring up now avoids each project re-inventing the wheel.
- **v1** — devshop capabilities that would be valuable but aren't blocking next-project onboarding.
- **v+** — future, when the need is felt.

---

## v0 — blocks next-project adoption

### Migration sequencing safety nets for the Vercel-preview window

**Pre-implementation findings (verified 2026-05-14):** **PARTIAL — Track B shipped, Tracks A + C pending. ⚠️ Orphan reference exists.**

- **SHIPPED**: **Track B** (highest-leverage) at `.claude/skills/ak-go-live/SKILL.md:76-120` — Step 1.6 migration sequencing pre-flight with classification heuristic (`MIGRATIONS_TOUCHED` grep for additive vs mutating) + AskUserQuestion surface. Attributed via "Codified from kit/ROADMAP.md § Migration sequencing safety nets for the Vercel-preview window (Track B)".
- **NOT SHIPPED**: **Track A** (`/ak-spec` migration scoping prompt) and **Track C** (`kit/docs/guide/ops.md § Migration Sequencing` doc section). `grep "Migration Sequencing"` against `ops.md` returns zero matches.
- **⚠️ Orphan reference to fix**: `ak-go-live/SKILL.md:88` says "Track A of the migration-sequencing convention plants this at spec time" — but `ak-spec/SKILL.md:333` only has a "Deploy boundaries" bullet covering similar ground under a different name, with no `## Migration Sequencing` section. Step 1.6's look-for-spec-section logic will fall through silently on most projects. **Implementer must either** (a) ship Track A planting `## Migration Sequencing` under that exact name in ak-spec's section template, OR (b) rephrase ak-go-live:88 to be honest ("if `specs/<feature>/spec.md` happens to have a `## Migration Sequencing` section…").
- **Scope going forward**: Tracks A + C + the orphan-ref fix. Per the entry's own sequencing recommendation, A + C were always conditional on B firing often enough to warrant the doc/spec investment — re-check whether real cycles since 2026-05-08 ever exercised Step 1.6 before deepening.

Spec below preserved for full original context.

---

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
- **`/auth/callback` route** (RSC + Route Handler hybrid): reads `code` query param, calls `supabase.auth.exchangeCodeForSession(code)` server-side, then redirects based on `type` (`recovery` → `/reset-password`; `email_change` → `/settings`; default → `/`). Sets the session cookie so subsequent requests are authed. **MUST anchor every redirect target on `request.headers.get('host')`, not `new URL(path, request.url)`** — Next.js 16 normalizes `request.url`'s hostname to its configured HOSTNAME (defaults to localhost) regardless of the actual Host header. Cookies set on the request host don't cross-send to the normalized redirect host, breaking the callback chain in CI/local even though prod (Vercel terminating TLS upstream with the canonical Host) masks the bug. Canonical helper at `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 10` (`sameOriginUrl(request, path)`); same fix applies to `/auth/signout` if the project ships a server-side signout route. Surfaced during home-os PR #15 slow-job rollout.
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

### Latency feedback framework — 5-tier decision rule + primitives

**Pre-implementation findings (verified 2026-05-19):** **PARTIAL — framework doc + routing shipped, primitives extraction + `/ak-spec` consult pending.**

- **SHIPPED via `a9f364d`** (stub) **+ prose-lift on `docs/latency-feedback-doc`**: `kit/docs/guide/latency-feedback.md` now carries the full 5-tier framework — table, decision rule, tokens (`FEEDBACK_THRESHOLD_MS` / `RETRY_BUDGET_MS` / `RETRY_BACKOFF_MS`), primitive contracts (`useOptimisticMutation` / `useSubmitFeedback` / `SubmitButton` / `LoadingArea`), the load-bearing queueMicrotask gotcha (verbatim from lalista with code snippet), test patterns to reproduce, and a surface-mapping template for project specs. Existing Tier C corner-case sections preserved as "within-the-framework" addenda.
- **SHIPPED via context-aware guideline routing**: discovery from project sessions is wired through `kit/docs/guide/README.md:68-69` — `useOptimisticMutation` / `SubmitButton` / `LoadingArea` / `loading.tsx` / client `useEffect` fetches / `"Tier A2"` / `"Tier C"` / `"skeleton"` / `"latency"` keywords all route to `latency-feedback.md`. No `template/CLAUDE.md` pointer needed (and would violate the "project CLAUDE.md is self-sufficient" principle codified in `/devshop/CLAUDE.md § Session Start`).
- **NOT SHIPPED**: `/ak-spec` consultation step in `.claude/skills/devshop/spec/SKILL.md` (when the spec involves interactive UI / async ops, prompt the spec author to produce the surface-mapping table per `latency-feedback.md § Applying the framework to your project`); primitives extraction (`useSubmitFeedback` / `SubmitButton` / `LoadingArea` / `useOptimisticMutation`) to a `@devshop-template/ui` package; lalista CLAUDE.md trim (delete the 5-tier table + decision rule that pre-trim lived at `git show ee87881^:CLAUDE.md L64-L78`; keep only the lalista-specific surface mapping table — and fix the stranded `Tier B of the latency-feedback framework; see Gotchas` pointer at lalista CLAUDE.md L14).
- **Unblocker shipped**: the `template/apps/web/` baseline landed 2026-05-19, so primitives extraction is no longer scaffold-blocked. `template/packages/ui/` still needs to be scaffolded as part of the primitives PR itself.
- **Realistic next step**: `/ak-spec` consult step (~15 min) + lalista-side CLAUDE.md trim (lalista session, ~10 min) + primitives extraction (~1.5–2 hr per the `latency-feedback-primitives` PLAN row).

Spec below preserved for full original context.

---

Projects keep re-solving the same UX gap: how snappy to make a button / a route nav / an optimistic mutation. Defaults skew either too eager (spinner everywhere, including <250ms ops where it's noise) or too lazy (no feedback, user double-taps). Lalista chapter 1m (`feat/app-snappiness`, PR #49, shipped 2026-05-07) co-developed a 5-tier framework with the user that matches the affordance to the operation's actual latency. Every next project with interactive UI will hit the same decision tree.

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

- `kit/docs/guide/latency-feedback.md` (lift into existing stub) — full framework prose: 5 tiers, decision rule, retry-budget shape, queueMicrotask gotcha, worked examples (generic surfaces, not lalista-specific). Becomes the ground truth.
- Discovery from project sessions: already wired via context-aware guideline routing in `kit/docs/guide/README.md:68-69` (keyword + primitive-import + file-glob triggers). No `template/CLAUDE.md` pointer — `/devshop/CLAUDE.md § Session Start` forbids `/devshop/...` cross-refs in project CLAUDE.md (the hook delivers devshop context at runtime; the routing table delivers the guide on relevant edits).
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
- `lalista/CLAUDE.md § Latency feedback tiers` — currently carries the 5-tier table, decision rule, and a lalista-specific surface mapping. After this lifts, lalista CLAUDE.md trims to just the lalista-specific surface mapping (5-tier table + decision rule delete entirely — context-aware routing surfaces the devshop guide automatically when the relevant primitives are touched). No `/devshop/...` cross-ref in lalista CLAUDE.md per the "project CLAUDE.md is self-sufficient" principle.
- `lalista/DESIGN.md § Motion + feedback` — token values; lifts alongside the components.
- `lalista/PRODUCT-ROADMAP.md § v1 § Devshop extraction of validated UX patterns` (line 347) — the soak-reminder counterpart on the lalista side.
- `lalista/packages/ui/src/{useSubmitFeedback,SubmitButton,LoadingArea,useOptimisticMutation}.{ts,tsx}` — concrete prior art ready to lift.

**Cost/risk:**

- Implementation: ~30 min for the guide doc + ~15 min for the `/ak-spec` SKILL amendment + ~1-2h for the primitives extraction PR (separate, post-soak). Total ~2-3 focused hours across two PRs.
- Risk of premature extraction is the main cost of NOT waiting for the soak; once we've waited, the patterns have already proven themselves on real users. Lalista's CI fix-loop on PR #49 surfaced 4 fix-loop iterations worth of edge cases (overlay-z-index intercept on banner Retry/Undo, React batching defeats observable optimistic frame, schema-drift footguns in test queries) — the doc + primitives codify those lessons so the next project doesn't rediscover them.

[v0, surfaced-by lalista-PR49, 2026-05-07]

---

### gstack vendored upgrade (0.15.1.0 → 1.55.0.0)

**Problem.** The vendored gstack at `.claude/skills/gstack/` is pinned at **v0.15.1.0 (2026-04-01)**; upstream is **v1.55.0.0** — ~110 releases / two months behind, and the gap widens weekly (gstack bumps a version per shipped branch). Every project clones gstack independently, so the debt compounds per project. Two costs are already being paid: (1) the **browser-daemon memory / CDP-leak** class behind the home-os zombie-process incident (~34k zombie processes forced a container rebuild that wiped a worktree) is fixed upstream (v1.51 closed four CDP-leak classes; v1.55 fixed the headed-browser crash-loop) but absent locally; (2) the **persistent design daemon** (v1.45) and the maturing **`design` image-gen binary** (v1.42–1.43.2, `gpt-image-2`) that the v1 visual-design MVP and the v+ full pipeline build on don't exist in the pinned copy — so visual-design work is effectively blocked on this upgrade.

**Delta verified (2026-06-01).** Full changelog read end-to-end (0.15.2.0 → 1.55.0.0, ~110 entries) plus a direct file-level diff of the load-bearing parse contracts between the live 0.15.1.0 tree and a 1.55.0.0 clone:

- **Empirically stable contracts (safe):** `/cso` severity enum (`CRITICAL/HIGH/MEDIUM/LOW/TENTATIVE` — identical, incl. the `TENTATIVE` token `router-shim.sh` keys on); `/qa` artifact paths (`.gstack/qa-reports/`, `screenshots/`, `qa-report-*` — byte-identical); `.gstack/projects/<slug>/` filenames `/ak-spec` globs (`*-design-*.md`, `*-test-plan-*.md`, `ceo-plans/*.md`). The HIGH-risk parse couplings do **not** move.
- **Pre-existing bug (not an upgrade regression):** `/ak-spec` (`spec/SKILL.md:136`) globs `design-html/*.html`, but gstack writes finalized HTML to `designs/*/finalized.html` in _both_ versions — so `DESIGN_HTML` is already a silent no-op today. Track/fix separately.

**Upgrade-mechanics hazards (the real risk lives here, not in skill contracts):**

1. **`./setup` now installs Claude hooks + has consent prompts.** v1.48 added `--plan-tune-hooks`/`--no-plan-tune-hooks` (else interactive-prompt → timeout auto-skip); v1.52 installs PostToolUse/PreToolUse hooks behind a `./setup` consent prompt. The vendored-upgrade flow runs `./setup` — against our **root-owned, locked `~/.claude/settings.json`**. Run with `--no-plan-tune-hooks`; if it attempts a settings.json write, that's a denied path needing the `/tmp + sudo install` handoff or an explicit opt-out. **Must run non-interactively or it hangs.**
2. **gbrain auto-wiring (v1.40):** `buildGbrainEnv` seeds `DATABASE_URL` from gbrain config, overriding `.env.local` by default (escape `GSTACK_RESPECT_ENV_DATABASE_URL=1`); `.gbrain-source` auto-added to consumer `.gitignore`. Low risk for us (projects use `SUPABASE_*`, not `DATABASE_URL`; gbrain only activates if configured) — but new surface. Don't enable gbrain blindly.
3. **Browse binary must rebuild from source** (`rebuild-browse.sh`): server export refactors (v1.34/v1.39) break only _programmatic embedders_ — we shell out, so fine; Apple-Silicon codesigning is handled by `./setup`. Covered by the smoke test.

Skill renames/restructures that do **NOT** bite (devshop invokes gstack skills by name via the Skill tool; it never greps their SKILL.md internals): `/ship` section-carve (v1.54), `description:` frontmatter trim (v1.46), `/checkpoint`→`/context-save` (v1.1.3), `/debug`→`/investigate` (v1.24 — we already use `/investigate`), `/ship` step renumber (v0.18.2), `gbrain_sync_mode`→`artifacts_sync_mode` config rename (v1.27 — we don't read it; gbrain post-dates our version).

**Benefits, mapped to documented pain:** browse CDP/memory-leak fixes (v1.51) + headed crash-loop fix (v1.55) → the Playwright-zombie / destructive-rebuild footgun; screenshot 2000px downscale guard (v1.42) → vision-API bricking on full-page shots; persistent design daemon (v1.45) → **prerequisite for `visual-design-richness-mvp`**; redaction engine, 33 patterns (v1.53) in `/cso`+`/spec`+`/ship` → defense-in-depth on the prod-service-role-key footgun; `/review` file:line+verbatim-quote requirement (v1.43.2) → higher-signal Gate 6.

**New capabilities that reshape the v1 roadmap:**

- **Native iOS QA suite (v1.43): `/ios-qa`, `/ios-fix`, `/ios-design-review`, `/ios-clean`, `/ios-sync`** — HTTP-driven real-iPhone QA, no simulator / XCTest / WebDriverAgent. Intersects `native-mobile-support`'s unresolved "Mobile E2E in CI" / Maestro assumption (`v+-native.md`). Re-evaluate before committing the mobile-QA approach.
- **`design` image-gen binary (`gpt-image-2`, v1.43.2)** — the exact dependency the v+ "Visual design pipeline (full)" / `/ak-assets` entry anticipates; already exists upstream behind this upgrade.
- **`/spec` skill (v1.47)** — five-phase spec with a codex quality gate; conceptual overlap with `/ak-spec`. Deliberate "adopt the quality gate vs keep ours" call when next touching `/ak-spec` (not urgent).

**Strategy.** Devshop worktree off `origin/main` (never on a live project mid-feature; gstack is per-project, so the devshop copy upgrades independently and validates first). (1) baseline snapshot — done: cso/qa/design contracts verified stable; (2) upgrade the vendored copy via `gstack-upgrade/SKILL.md § Step 4`, `./setup --no-plan-tune-hooks`, watch for settings.json writes; (3) smoke: `rebuild-browse.sh` → `browse --help` + screenshot → `populate-playwright-cache.sh` → one throwaway `/ak-pre-ship` dry run exercising `/cso`+`/qa`+`/design-review`+`/benchmark` to confirm `router-shim.sh` + `verify-story.sh` parse end-to-end; (4) roll to projects independently afterward.

**Why v0.** The browse-daemon leak class hits _current_ projects' QA / pre-ship runs now (already caused a destructive rebuild), and upgrade debt compounds weekly — both are "before the next project adopts" concerns. It also unblocks the two largest v1 bets (`visual-design-richness-mvp` needs the design daemon; `native-mobile-support` should weigh gstack's new iOS-QA skills). Sequence it **before** `visual-design-richness-mvp`.

**Trigger.** Operator-requested 2026-06-01 (this session). Hard prerequisite once visual-design v1 work starts.

**Cross-ref.**

- `.claude/skills/gstack/gstack-upgrade/SKILL.md § Step 4` (vendored path) + `CLAUDE.md § gstack` (never-edit + silent `rm -rf` rule).
- `kit/scripts/preship/router-shim.sh` (cso `TENTATIVE` parse — verified stable) + `verify-story.sh` (qa artifacts — verified stable).
- `kit/scripts/{rebuild-browse,populate-playwright-cache,capture-screenshot}.sh` — browse wrappers exercised by the smoke test.
- `kit/ROADMAP.md § Visual design richness (MVP)` + `§ Visual design pipeline (full)` (design daemon + image-gen unblocked) + `§ Native/mobile devshop support` (iOS-QA skills).
- Home-os 2026-05-28 zombie-process / worktree-wipe incident (the leak class this closes).

**Cost/risk.** Devshop vendored copy: ~1.5–3 hr (swap + `./setup` hazard + smoke + throwaway `/ak-pre-ship`). Project rollout separate (each via `/gstack-upgrade`). Residual risk **low** — the parse contracts are empirically unchanged; the live hazards are the `./setup`/settings.json interaction and not enabling gbrain blindly, both handled in the strategy. Benefit: closes the browse-daemon leak class + unblocks visual-design and native QA.

[v0, surfaced-by gstack-delta-analysis-2026-06-01]

---

## v1 (after v0 is validated on the first project)

### Visual design richness (MVP) — art-direction layer + template SVG decorative kit + a richness gate

**Problem.** Devshop pages come out slick-but-plain: good typography, color, spacing, borders — and nothing else. No illustration, no texture, no decorative motif, no imagery. The root cause is **upstream of implementation, not a Claude taste failure**. The design phase produces exactly one durable artifact, `DESIGN.md`, and `DESIGN.md` captures **tokens and rules** (fonts, colors, spacing, motion) but never **visual assets or an art-direction language**. The implementation agent faithfully follows the contract it's given; the contract never asks for richness, no asset exists to import, and no gate fails a page for being visually flat. So plainness is the guaranteed output of the current pipeline, on every project, by construction.

**gstack-ownership constraint (load-bearing — shapes the whole design).** Every existing design skill is gstack-owned and MUST NOT be edited: `design-consultation`, `design-shotgun`, `design-html`, `design-review`, `plan-design-review` (per `CLAUDE.md § gstack` + `kit/ROADMAP.md § v+ Never edit gstack`). This entry therefore adds **zero** gstack edits. Everything is devshop-side: new `ak-` skill steps, template files, `DESIGN.md`/`CLAUDE.md` conventions, and our own pre-ship gate that **invokes** gstack skills unmodified and layers our checks around them. The rule clarifies rather than constrains the design: gstack is a black box we orchestrate; the new artifacts + gate are ours.

**Shape of the fix — the design phase emits an art-direction layer + a reusable asset kit, and a gate enforces both:**

1. **`DESIGN.md` "Art direction" section** — a **devshop step appended AFTER** gstack `/design-consultation` runs (we do not change what the gstack skill writes; we augment its output). Captures the richness dimension the token layer omits: **imagery direction** (photography style / none / illustration-instead), **illustration & graphic style** (flat-vector / organic / textured), **decorative motif language** (dividers, background textures, grain, gradient meshes), **shape language** (radii, line weight, geometric vs organic), **depth / material** (flat / shadow / glass / grain), and **reference + anti-reference** (moodboard "look like this" + explicit "don't look like generic AI slop"). Voice-and-tone stays in `DESIGN.md` but is a separate copy lane, not part of this gate.
2. **Template SVG decorative kit** — themeable SVG primitives (section dividers, blobs, silhouettes, geometric motifs, gradient meshes) bound to `DESIGN.md` tokens so they recolor light/dark for free. Claude-native (SVG/CSS is squarely in-lane), version-controlled, zero external dependency, no licensing surface. Lives under `template/` (`packages/ui` or `apps/web`).
3. **`/ak-spec` (ours) names richness per screen** — for each screen the spec declares which motifs / kit assets that screen must use, carried forward as an implementation requirement rather than left to chance.
4. **`/ak-implement` (ours) imports from the kit** — plain-CSS fallback is not an acceptable output when the spec named assets.
5. **`/ak-pre-ship` (ours) richness gate** — invokes gstack `/design-review` unmodified, then adds **our** check: does the rendered page actually wire the art-direction assets the spec named, or did it silently go flat? Fail-if-flat. This is the gate that would have caught every plain page shipped to date.

**Why v1 — quality elevation, not an adoption blocker.** Products ship and function without it, so it doesn't block next-project adoption — but every from-scratch project inherits the plainness by construction, so the quality ceiling stays capped until it lands. The MVP closes most of the gap, is entirely Claude-native (no image model, no licensing/provenance headaches), and proves the "art-direction layer + asset kit + richness gate" shape cheaply before the heavier image-gen pipeline (v+ below) is justified.

**Scope boundary.** Vector / decorative richness only — no photographs, no illustrated scenes, no bespoke imagery, and no binding of pixel mockups forward. That ceiling is the full pipeline in `### Visual design pipeline (full)` under v+.

**Trigger.**

- The next from-scratch project reaches the design phase and wants more than plain CSS; OR
- the operator pushes back on plain output again (already surfaced 2026-05-31 in the visual-design design conversation that produced this entry).

**Cross-ref.**

- `CLAUDE.md § gstack` + `CLAUDE.md § Design System` (read `DESIGN.md` before any visual decision) — the wrapper rule + the contract this entry extends.
- gstack `/design-consultation` → `DESIGN.md` — the upstream the new "Art direction" step augments.
- gstack `/design-review` — invoked unmodified by the new richness gate.
- `.claude/skills/ak-spec` + `.claude/skills/ak-pre-ship` — the devshop skills that grow the per-screen richness requirement and the gate.
- `kit/ROADMAP.md § v+ § Visual design pipeline (full)` — the image-gen + mockup-binding escalation this MVP precedes.
- `kit/ROADMAP.md § v1 § /ak-collateral` — adjacent (marketing-collateral composition), different surface (in-product richness vs README/social assets).

**Cost/risk.** ~1–1.5 focused days across a few commits: `DESIGN.md` "Art direction" convention + the devshop augment step (~1h), template SVG decorative kit (~3–4h, the bulk), `/ak-spec` + `/ak-implement` prompt amendments (~1h), the `/ak-pre-ship` richness gate (~2–3h). Main risk is the richness gate's subjectivity — "is this page rich enough?" is judgment, not a deterministic check; mitigate by gating on the **objective** signal first (did it import/render the spec-named kit assets at all?) before any taste judgment.

[v1, surfaced-by visual-design-conversation-2026-05-31]

---

### Template PWA service worker baseline

The template ships a PWA manifest + meta tags out of the box (apple-touch-icon, viewport-fit=cover, standalone, start_url), which is enough to install — but it does NOT ship a service worker. Every PWA-shaped project will hit the same soak finding: iOS cold-launch feels slow because every fresh WebView process pays the full server-roundtrip cost (middleware token refresh + RSC fetches + client mount + realtime handshake) before first paint. Lalista's polish PR #68 (2026-05-13) parallelized the two server fetches in `/list/page.tsx` via `Promise.all` — the largest cheap win without a SW — but the user can still feel the difference between "warm WebView" and "cold WebView." From here the next lever is HTML caching via SW, and that pattern is general (every PWA-shaped project will want it).

**The pattern** — same shape as Auth UX conventions / Latency feedback framework: lalista soaks the implementation first, devshop extracts the convention once the edges are known. Lalista's `PRODUCT-ROADMAP.md § PWA service worker caching` carries the project-side row; this row is the template-side counterpart.

**Shape of the fix:**

- **Implementation library**: `@serwist/next` (the de-facto Next.js 15 PWA SW story). Add to `template/apps/web/package.json` as a dep; wire `next.config.ts` per the serwist docs.
- **Default caching strategy**: stale-while-revalidate for HTML (so cold-launch paints last-known content immediately + refetches in background), cache-first for static assets, network-only for `/api/**` + Supabase calls. The HTML SWR is the cold-launch lever.
- **Versioning**: serwist's `precacheManifest` regenerates on each build; updates propagate on next page nav after the new SW activates. Document the "tab close + reopen" worst-case staleness window in the convention so operators understand it.
- **Dev-mode behavior**: SW disabled in dev (or self-unregistering) — cached assets during HMR cycles is its own footgun.
- **Real-device validation**: a CI gate can't fully prove the win (headless Chromium doesn't model iOS WebView-process-reap cold-launch); the convention should require post-merge `/canary` to hit the production PWA from a real device and confirm.

**Implementation surface:**

- `kit/docs/guide/pwa-service-worker.md` (new) — full convention prose: caching strategies per asset class, versioning behavior, dev disable, real-device validation requirement, "what NOT to cache" list (Supabase calls, edge functions, `/auth/callback`).
- `template/apps/web/next.config.ts` + `template/apps/web/app/sw.ts` (new) — the serwist registration + precache manifest config, parameterized so projects can override the cache lists.
- Discovery from project sessions: add a row to `kit/docs/guide/README.md` routing index keying on `apps/web/app/sw.ts`, `next.config.ts` serwist edits, `"PWA"` / `"service worker"` / `"@serwist/next"` keywords → target `pwa-service-worker.md`. No `template/CLAUDE.md` pointer — `/devshop/CLAUDE.md § Session Start` forbids `/devshop/...` cross-refs in project CLAUDE.md.
- `.claude/skills/devshop/new-project/SKILL.md` — `/ak-new-project` Step N: ask "is this a PWA?" If yes, scaffold the SW config from the template; if no, skip (CLI tools / pure SPAs / SSR sites that aren't installed).
- `.claude/skills/devshop/pre-ship/SKILL.md` — pre-ship gate that lints the SW config for known footguns (e.g., caching `/auth/callback` would break magic-link flows; caching `/api/**` would hide DB writes from the user).

**Why v1 — soak-extract pattern, not blocking:**

Same playbook as Auth UX conventions / Latency feedback framework. The pattern needs lalista's SW implementation to ship first so the convention extracts from real lessons rather than aspirational design. Lalista's polish #68 parallelization is the last cheap win pre-SW; the next lalista PR that adds SW is the trigger to extract the convention here. Until then, projects that need a SW point at lalista's eventual implementation.

**Trigger:**

- Lalista clears its `PRODUCT-ROADMAP.md § PWA service worker caching` row by shipping a serwist-based SW.
- OR: a second devshop project adopts the template + is a PWA + hits the same cold-launch soak finding (which is the natural verification step).

**Cross-ref:**

- `lalista/PRODUCT-ROADMAP.md § PWA service worker caching` — the project-side counterpart with the cold-load context surfaced by polish PR #68.
- `lalista/apps/web/public/manifest.json` + `lalista/apps/web/app/layout.tsx` — the installability scaffolding that's already template-level; the SW lives one layer up.
- `lalista/apps/web/middleware.ts` + `lalista/apps/web/app/list/page.tsx` — the boot-path roundtrips a SW would short-circuit.

**Cost/risk:**

- Implementation: ~1h for the convention doc + ~1h for the template wiring + ~30 min for the `/ak-new-project` branch. Total ~2-3 focused hours, plus the upstream lalista SW PR (~half a day for caching strategy + real-device validation).
- Risk of premature extraction is the main cost of NOT waiting for the soak; cache invalidation is a classic footgun and the wrong default lasts forever (users keep stale HTML after deploys; the realtime channel + cached page disagree on the truth; etc.). Lalista's soak surfaces those edges before they become a template default.

[v1, surfaced-by lalista-polish-PR68-2026-05-13]

---

### Project-worktree setup support — propagate the `.worktrees/` convention to projects (symlink-tooling, not submodule)

**Problem.** The devshop has a clean linked-worktree convention for its _own_ parallel work, but it was never propagated to projects — and the mechanism doesn't transfer as-is because **projects wire tooling via symlinks into `/devshop`, whereas the devshop wires it via git submodules.** As a result, a worktree of a _project_ repo comes up bare: no `.claude/` (it's gitignored — `.claude/*`), so a fresh `claude` session in the worktree has **no skills** (`/ak-build` unavailable), **no `settings.json`** (no SessionStart hook → no briefing, no commit/push guard hooks, default permissions). The operator sees "claude doesn't load as usual" and has to hand-wire symlinks.

**Canonical devshop pattern (works for /devshop, not for projects):**

```
git worktree add .worktrees/<topic> -b <type>/<topic> origin/main \
  && git -C .worktrees/<topic> submodule update --init --recursive
```

- `.worktrees/<topic>` lives inside the repo; `/.worktrees/` is gitignored (`/devshop/.gitignore:30`).
- `origin/main` base is **load-bearing** — without it `git worktree add` defaults to current HEAD and silently inherits WIP commits (documented worked-bite in `/devshop/CLAUDE.md § Worktree workflow`).
- `submodule update --init --recursive` populates the devshop's vendored tooling (bats libs etc. are submodules). **This step does nothing useful for a project**, whose `kit/` is `.devshopkit -> /devshop/kit` and whose `.claude/skills/*` are symlinks into `/devshop`.
- `/ak-merge-devshop` auto-detects the worktree, squashes via `git -C`, ff-merges main, tears it down. `session-start.sh` detects `/devshop/.worktrees/` and routes to devshop context.

**Why it doesn't reach projects (the gaps):**

1. **No `/.worktrees/` in the project `.gitignore`.** The template never carried it, so projects have no convention. (home-os `.gitignore` has no worktree entry.)
2. **No project-worktree setup flow.** `kit/scripts/sync/create-devshop-symlinks.sh` is already `WS`-parameterized (`WS="${WS:-/workspace}"`) and builds the per-skill `.claude` symlinks into `/devshop` — but it is **never auto-run for a worktree**. `session-start.sh` only auto-repairs `/workspace` (`if [ ! -L /workspace/.devshopkit ]` — hardcoded).
3. **`settings.json` is a root-owned copy** managed by `init-devshop.sh` (deliberately a copy, not a symlink, so Claude can't edit its own permission grants). `init-devshop.sh` is `/workspace`-scoped, and `create-devshop-symlinks.sh` intentionally skips `settings.json`/`.dcg.toml`. So even after running the symlink script, a project worktree has no `settings.json` → no hooks.
4. **Bootstrap catch.** A bare worktree has no `settings.json` → the SessionStart hook never fires → the worktree **cannot self-heal on first `claude` startup.** Wiring must happen at _creation_ time, not first-session time.
5. **No `origin/main`-base guard for project worktrees.** The devshop rule lives only in `/devshop/CLAUDE.md` prose for devshop worktrees; nothing enforces it for projects.

**Shape of the fix:**

1. **Propagate `/.worktrees/` to the project `.gitignore`** (template + a propagation step for existing projects).
2. **New `kit/scripts/sync/setup-project-worktree.sh <type>/<topic>`** that mirrors the devshop recipe but swaps `submodule update` → symlink wiring:
   ```
   git worktree add .worktrees/<topic> -b <type>/<topic> origin/main
   WS="$PWD/.worktrees/<topic>" bash /devshop/kit/scripts/sync/create-devshop-symlinks.sh
   # + settings.json (see #3)
   ```
3. **Extend `create-devshop-symlinks.sh`: when `WS` ≠ `/workspace`, also symlink `settings.json` (+ `.dcg.toml`) from `/workspace`'s root-owned copy.** Symlinking to the root-owned file preserves the can't-self-edit security property (Claude still can't write it) without needing `init-devshop.sh` to run as root per-worktree. Document the security note inline.
4. **Teach `session-start.sh` to repair _project_ worktrees** under `<workspace-root>/.worktrees/`, not just `/workspace` — useful for a _partially_-wired worktree (it can't fix a fully-bare one; see bootstrap catch #4, which is why #2 must run at creation).
5. **Add an `origin/main`-base guard** to project worktree creation: if the project repo is on a non-`main` branch at creation, `AskUserQuestion` to confirm the base (default `origin/main`). This is the exact failure that bit home-os below.
6. **Project-mode `/ak-build` parallel-work guidance:** use `.worktrees/<topic>` with managed teardown, mirroring `build/devshop-mode.md`'s worktree handling, adapted for symlink-tooling.

**Trigger — home-os, 2026-05-28.** A parallel `/ak-build photo-comparison-ui` session was run concurrently with the main session's `/ak-build` (advisor-hardening) → `/ak-go-live`. The photo-comparison worktree was created **off-convention in three ways**, each mapping to a gap above:

- **Wrong location:** `/home/node/worktrees/photo-comparison-ui` (home dir), not `<repo>/.worktrees/<topic>`. This had a second bite: a container rebuild (triggered to clear ~34k zombie processes from parallel Playwright runs) **wiped the worktree's working directory** — `/home/node/` is not a persisted volume, only `/workspace` is. A worktree at `<repo>/.worktrees/<topic>` lives under `/workspace` and would have survived the rebuild intact. So "wrong location" isn't just tidiness; it's the difference between a rebuild-durable and a rebuild-fragile worktree.
- **Wrong base:** branched from `fix/advisor-hardening` (a WIP branch mid-`/ak-go-live`), not `origin/main` — the exact silent-WIP-inheritance the devshop doc warns about. When `fix/advisor-hardening` squash-merged (PR #40) and was deleted, the worktree's base orphaned; later a branch-checkout race caused an _unrelated_ migration PR (#41) to squash the photo-comparison spec skeleton onto `main`.
- **Bare `.claude`:** the worktree had no skills/settings, so a fresh `claude` there "didn't load as usual." Required a manual `.claude` symlink to unblock.

The branch was eventually rebased onto current `main` (resolving the base orphan) and is fully implemented, but the whole episode — race contamination + bare worktree + manual recovery — traces directly to the missing project-worktree convention.

**Recovery when a worktree's working dir is wiped (rebuild or manual `rm`).** The working directory is disposable; the branch is not. Git worktrees share the parent repo's object database (`<repo>/.git/worktrees/<name>`), so **the branch ref + all its commits survive** even when the worktree checkout is gone — `git worktree list` shows the stale entry as `prunable`. Session transcripts also survive, under their own project dir (`~/.claude/projects/-home-node-worktrees-<topic>/*.jsonl`) — readable to reconstruct where the lost session left off. Recovery is:

```
git worktree prune                       # drop the dead registration
git checkout <type>/<topic>              # check the branch out in /workspace (or recreate the worktree under <repo>/.worktrees/)
git rev-parse --verify <type>/<topic>    # confirm the commits are intact
```

The setup script in the fix (#2) should place worktrees under `<repo>/.worktrees/` precisely so a rebuild never wipes one; the recovery recipe above is the fallback for worktrees created off-convention before the fix lands.

**Why v1 — not v0.** The default single-session flow is unaffected; this only bites when a project runs **concurrent** `/ak-build` sessions in worktrees, which is rare today. v0 entries block next-project adoption; this is "advanced parallel workflow has sharp edges." Promote to v0 if multi-session project work becomes common, or if a second race-contamination incident ships bad content to `main`.

**Cost/risk:**

- Implementation: ~2–4 hours. `.gitignore` template + propagation; new `setup-project-worktree.sh`; `create-devshop-symlinks.sh` `settings.json` branch + bats; `session-start.sh` worktree-detection extension + bats; `/ak-build` project-mode worktree prose; `origin/main` guard.
- Risk: low — all additive; worktrees are opt-in; the symlink-to-root-owned-copy preserves the security boundary.
- Benefit: project parallel work becomes a supported one-liner instead of a hand-wired, race-prone improvisation; eliminates the bare-worktree + wrong-base class of incident.

**Cross-ref:**

- `/devshop/CLAUDE.md § Worktree workflow` — the canonical devshop pattern + `origin/main` worked-bite
- `/devshop/kit/scripts/sync/create-devshop-symlinks.sh` — the `WS`-parameterized symlink builder to extend
- `/devshop/kit/scripts/session-start.sh:8-11,20-30` — `/workspace`-hardcoded auto-repair + devshop-worktree detection
- `/devshop/.claude/skills/devshop/build/devshop-mode.md` — devshop-mode worktree create/teardown to mirror for project mode
- home-os 2026-05-28 — PR #40 (advisor-hardening) / PR #41 (rls_auto_enable) `/ak-go-live` session + the concurrent `feat/photo-comparison-ui` worktree incident

[v1, surfaced-by home-os photo-comparison-ui parallel-session incident on 2026-05-28]

---

### Test-coverage hook scope: extend to template/.devcontainer/\*.sh + reframe EXEMPT_SCRIPTS as warn-not-block

**Problem.** `kit/scripts/commit-hooks/check-tests-coverage-devshop.sh` only scopes to `kit/scripts/*.sh` (line 51-52: `git diff --cached --name-only --diff-filter=A | grep '^kit/scripts/.*\.sh$'`). Template-side devcontainer scripts (`template/.devcontainer/init-firewall.sh`, `init-prod-url.sh`, `refresh-allowed-ips.sh`, `init-host-env.sh`, `init-devshop.sh`) are outside the scope — additions or non-trivial behavior changes there ship without any test-coverage check.

Audit-time `/ak-tests-review` catches the gap (it did during the firewall-extras-overlay merge, 2026-05-14), but the Layer 1 hook misses two surfaces today:

- `template/.devcontainer/init-prod-url.sh` + `template/.devcontainer/refresh-allowed-ips.sh` (both added 2026-05-09, `f94a121`) shipped with zero bats coverage; retroactive coverage landed via `kit/tests/template-production-url-firewall.bats` (2026-05-20, as part of the `feat/production-url-onboarding-gap` close-out). The hook-scope gap that allowed the original miss is still open — these were the codification trigger, not the only at-risk surface.

Both are security-relevant scripts (they govern firewall allowlist updates). The pattern: when a template-script feature ships, the same author often forgets the bats — exactly the case the hook should catch.

Separately, `EXEMPT_SCRIPTS` (line 32-40) is over-broad. It exempts `init-devshop.sh`, `session-start.sh`, etc. with the rationale "runs as root — needs integration test environment" — true for **runtime** integration tests, but **static-grep tests** (the pattern used by `structural-invariants.bats` and `template-compose-isolation.bats`) work without root. In practice operators add static tests anyway: `init-devshop.sh` has 5 bats files referencing it, `adversarial-review.sh` has 14 — the exemption is honored in the breach. The exemption should distinguish "no runtime test feasible" (still warn for static gaps) from "no test of any kind possible" (truly exempt).

**Shape of the fix:**

1. Extend the hook's path filter from `^kit/scripts/.*\.sh$` to also match `^template/\.devcontainer/.*\.sh$`. Template-side devcontainer scripts get the same "added → block" / "modified → warn" treatment.

2. Reframe `EXEMPT_SCRIPTS` semantics. Either (a) split into two lists — `RUNTIME_EXEMPT_SCRIPTS` (no execution-test required, static-grep still warned-on) vs `FULLY_EXEMPT_SCRIPTS` (no test of any kind required) — or (b) keep one list but downgrade the exemption to warn-only for added scripts. Option (b) is the smaller change.

3. Update the hook's bypass message to direct operators to static-grep tests as the cheap path.

**Cost.** ~30 minutes. Pure script edit + 2-3 new bats assertions in `kit/tests/guard-tests-coverage-devshop.bats` to pin the new behavior. No semver impact.

**Why v1 not v0.** Layer 2 audit catches this — there's no silent-coverage-gap ship today. The cost of the gap is "Layer 2 surfaces a finding that Layer 1 should have blocked" — paper-cut, not silent miss. Promote to v0 if a third missed-coverage incident surfaces.

### Pre-push reviewer recognises canonical Phase 5.6 / 5.8 / 5.9 bookkeeping commits

**Problem.** `/ak-build` Phase 5.6 (BUILD-LOG bookkeeping), Phase 5.8 (post-pre-ship docs+tests audit append), and Phase 5.9 (visual evidence refresh) each produce a commit that the project's pre-push reviewer flags as "PR description appears stale relative to commits — N additional commits without justification." The reviewer is correctly conservative by default. But the canonical phase commits are **defined to be additive** to whatever the PR body already says:

- **Phase 5.6** message pattern: `chore(build-log): record <feature>`. Edits PLAN.md + BUILD-LOG.md + PRODUCT-ROADMAP.md. The PR body's `**Docs**` paragraph already names "BUILD-LOG.md gains the canonical ship entry" — the commit IS the fulfillment of an already-described claim.
- **Phase 5.8** message pattern: `docs(<feature>): Phase 5.8 Audit 2 (post-pre-ship <findings-summary>)`. Edits only `specs/<feature>/review.md`, appending one `## Audit N` section. The PR body's `## Pre-ship audit trail` already attests Audit 1; Audit 2 is the documented Phase 5.8 step.
- **Phase 5.9** message pattern: `chore(<feature>): refresh visual evidence at HEAD (Phase 5.9)`. Edits only `specs/<feature>/{hero,screenshots}/*.png`. The PR body's `### Evidence` section already embeds those exact paths.

Each push after these commits triggers the reviewer, and each requires `git -c devshop.prDescStaleReason="..."` with a 2–4 line justification. The justification is **identical every PR** ("Phase N fulfills the already-described claim"). Sonnet adversarially reviews, accepts, push goes through. Net cost: one round-trip of operator + reviewer attention per Phase 5.6/5.8/5.9 commit per PR.

**Concrete from home-os PR #9** (2026-05-13):

- `00e614f` (Phase 5.6): blocked by pre-push reviewer; bypassed with `prDescStaleReason="The Phase 5.6 bookkeeping commit is the canonical /ak-build BUILD-LOG record for this PR..."`. Adversarial reviewer accepted (Sonnet ~30s).
- `9580061` (Phase 5.8): blocked; bypassed with `prDescStaleReason="Phase 5.8 audit commit only appends a clean Audit 2 section..."`. Adversarial reviewer accepted.

Both reasons collapse to the same pattern: **this is a known canonical phase commit, recognised by message prefix; the PR body's narrative covers it by reference.**

**Shape of the fix:**

Teach `check-pr-desc-staleness.sh` to **recognise** the canonical phase-commit patterns and auto-accept them WITHOUT requiring a bypass reason. Detection is regex-only on the commit message subject + the touched-file set; sub-millisecond compared to the Sonnet adversarial round-trip.

```bash
# kit/scripts/preship/check-pr-desc-staleness.sh — proposed addition

# Canonical /ak-build phase-commit patterns. Each pairs a subject regex
# with a file-touch allowlist. A commit matching BOTH is auto-accepted.
declare -a PHASE_PATTERNS=(
  '^chore\(build-log\): record [a-z0-9-]+$|^(PLAN\.md|BUILD-LOG\.md|PRODUCT-ROADMAP\.md|TODOS\.md)$'
  '^docs\([a-z0-9-]+\): Phase 5\.8 Audit 2|^specs/[a-z0-9-]+/review\.md$'
  '^chore\([a-z0-9-]+\): refresh visual evidence at HEAD \(Phase 5\.9\)$|^specs/[a-z0-9-]+/(hero|screenshots)/.+\.png$'
)

for pattern in "${PHASE_PATTERNS[@]}"; do
  subject_re="${pattern%%|*}"
  paths_re="${pattern#*|}"
  if echo "$LATEST_COMMIT_SUBJECT" | grep -qE "$subject_re"; then
    bad_files=$(git diff --name-only "$RANGE" | grep -vE "$paths_re" || true)
    if [ -z "$bad_files" ]; then
      echo "Phase commit pattern matched (subject + path allowlist); auto-accepting"
      exit 0
    fi
  fi
done
```

Three guards make this safe:

1. **Subject + path conjunction**: a `chore(build-log): record foo` commit that ALSO edits `apps/web/...` does NOT auto-accept (the path-allowlist catches scope creep).
2. **Exact-match regex on subject**: `chore(build-log): record foo BREAKING CHANGE` won't match.
3. **Range scope**: only the latest-commit subject matches, but the path-allowlist runs over the full range — catches bundling a Phase 5.6 commit on top of unrelated changes.

**Why v1 — not v0:**

- The cost is real (operator drafts the same recurring bypass reason every PR + Sonnet round-trip, ~30s × 2–3 phase commits per PR), but scales linearly with phase commits, not catastrophically.
- The bypass mechanism works correctly today; failure mode is paper cut, not silent risk.
- The v0 entries above this one (docs-coverage hook, PRODUCTION_URL onboarding) are higher-priority structurally — they cause silent gaps where this one only adds friction.

Promote to v0 if friction becomes load-bearing: e.g., if a future automation phase requires Claude to push without operator drafting bypass reasons.

**Trigger:**

- home-os PR #9 — 2 bypasses for canonical phase commits
- lalista PRs running `/ak-build` — same pattern at every Phase 5.6/5.8 commit
- Every future project: identical fact pattern guaranteed

**Cross-ref:**

- `/devshop/kit/scripts/preship/check-pr-desc-staleness.sh` — the reviewer to teach
- `/devshop/.claude/skills/ak-build/SKILL.md § Phase 5.6 / 5.8.3 / 5.9.2` — phase commit-message specifications
- home-os PR #9 — concrete bypass-trailer evidence at `00e614f` (5.6) and `9580061` (5.8)

**Cost/risk:**

- Implementation: ~1 hour (regex matrix + bats coverage for happy path + the "phase-commit subject + scope-creep file" failure case).
- Risk: low. Three guards layer; worst case is a benign scope-creep auto-accepts (caught by the next `/ak-pre-ship` audit or code review).
- Benefit: zero adversarial-reviewer round-trips for canonical phase commits; ~$0.05–0.10 saved per PR; operator attention freed from drafting the same justification every push.

[v1, surfaced-by home-os PR #9 § 5b reflection on 2026-05-13]

---

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

- Security-posture cleanup (shipped via `631dc7e` on `feat/security-posture-cleanup`; entry closed and removed from `kit/ROADMAP.md` per the closing-entries rule) — the structural enabler this entry completes.
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
- `CLAUDE.md § Non-Negotiables` — "Adversarial Layer 2 reviews fire at audit moments, not per commit" (the "before each merge to main" rule the skill operationalizes; structural migration shipped via PR-A/B/C `b02d531`/`a0f1705`/`a2e1f34`).

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

### Native/mobile devshop support

Extend the devshop to support React Native (Expo) apps alongside web. Adds `apps/mobile/`,
EAS CLI, Maestro E2E, mobile Sentry/PostHog, App Store/Play Store deployment.
Full build blueprint: `kit/notes/bootstrap/v+-native.md`.

**Open decision — macOS desktop architecture (added 2026-06-01).** Two incompatible paths, deliberately unresolved until native work actually starts:

- **Expo Mac Catalyst** — reuse the React Native codebase as a Mac build target (`v+-native.md` §2d). One codebase spans iOS + macOS.
- **Electron** — wrap the existing Next.js web app in Chromium. Reuses the _web_ code; a separate surface from the RN tree.

The choice determines whether macOS shares the mobile codebase or the web codebase — resolve at native-kickoff via `AskUserQuestion`. (The committed `v+-native.md` plan currently assumes Catalyst; Electron is the operator-raised alternative.)

**Tooling note — gstack now ships a native iOS QA suite (added 2026-06-01).** gstack v1.43 added `/ios-qa`, `/ios-fix`, `/ios-design-review`, `/ios-clean`, `/ios-sync` — HTTP-driven real-iPhone QA with no simulator / XCTest / WebDriverAgent. Re-evaluate `v+-native.md`'s "Maestro for mobile E2E" decision against these before committing the mobile-QA approach — gstack may already cover the surface that plan budgets for. Available only after the gstack upgrade (vendored gstack is v0.15.1.0 as of 2026-06-01; upstream is v1.55.0.0).

**Why v1.** The largest single capability expansion the devshop can take on — a whole second platform. Not blocking next-project adoption (every project to date is web), so it sits below the web-hardening v1 items; promoted out of v+ once native became a concrete near-term direction rather than a someday-maybe.

[v1, promoted-from-v+ 2026-05-31]

---

## v+ (future — when the need is felt)

### Visual design pipeline (full) — image-gen mockups as committed acceptance targets + production asset generation + a visual-diff gate

**Builds on** `kit/ROADMAP.md § v1 § Visual design richness (MVP)`. The MVP gives every project a Claude-native vector/decorative layer + a richness gate. This entry raises the ceiling to **raster artwork (photography, illustrated scenes, bespoke imagery)** and closes the **mockup-binding** gap the MVP deliberately leaves open.

**Problem.** Two gaps survive the MVP. (1) **No raster path** — the SVG kit can't produce a photograph, an illustrated empty-state scene, or a bespoke hero illustration; those need an image model or a human. (2) **Mockups don't bind forward** — gstack `/design-shotgun` already generates image-gen variant mockups in a browser comparison board, but after a winner is picked the mockup is **thrown away**; implementation re-derives the screen from `DESIGN.md` tokens and loses the specific visual fidelity the mockup had. The result is "we explored a rich design, then shipped a plainer re-derivation of it."

**gstack-ownership constraint (restated).** `design-shotgun` and `design-html` are gstack-owned and unmodifiable (`CLAUDE.md § gstack`). This entry **invokes** them unmodified and does all the new work devshop-side: a step that **commits** the chosen mockup, a new asset-generation skill, and a new pre-ship **diff** gate. No gstack edits.

**Shape of the fix — three additions on top of the MVP's art-direction layer + asset kit:**

1. **Pixel mockups become committed acceptance targets.** Invoke gstack `/design-shotgun` for direction/screen exploration → a **devshop step commits the winning mockup(s)** as reference targets under `specs/<feature>/design/` (same artifact-preservation discipline as the `.gstack/projects/**` re-include rule in `CLAUDE.md § gstack`). The mockup is now an acceptance contract, not a discarded exploration — this is the "respect the mockup" mechanism.
2. **Production asset generation** — a new devshop skill (working name `/ak-assets`) bridges to an image model for production illustrations / imagery, then **optimizes** (sharp / svgo), **commits**, **writes alt text** (doubles as the a11y win — Claude is genuinely good at alt text), and **records license / provenance** (the liability the boring-infra layer must own). Scoped to _production-shippable_ assets, distinct from gstack's _throwaway exploration_ mockups.
3. **Scaffold binding + visual-diff gate.** `/ak-spec` (ours) invokes gstack `/design-html` on the winning mockup → its reflowing production HTML/CSS **seeds** implementation instead of a from-scratch re-derivation. `/ak-pre-ship` (ours) gains a gate that **screenshots the built screen and diffs it against the committed reference mockup** (via the browse daemon / `capture-screenshot.sh`), layered on top of the MVP richness check.

**Why v+, not v1.** It takes on an **image-model dependency** plus real failure modes the MVP avoids: mockups that can't actually be built, flaky visual diffs, asset licensing / provenance, and a new credential surface. It should land only after the MVP proves the "art-direction + asset kit + gate" shape on a real project — the MVP tells us where the ceiling actually pinches before we pay for the heavy machinery.

**Trigger.**

- The MVP (v1) has shipped and soaked on one project, AND a project needs raster artwork / photography or wants pixel-mockup fidelity carried into implementation; OR
- the operator asks to bind explored mockups forward rather than re-deriving screens.

**Cross-ref.**

- `kit/ROADMAP.md § v1 § Visual design richness (MVP)` — the prerequisite this builds on.
- gstack `/design-shotgun` (image-gen variant board) + `/design-html` (mockup → production HTML/CSS) — invoked unmodified; the asset-commit + scaffold steps wrap them.
- `CLAUDE.md § gstack` (`.gstack/projects/**` artifact-preservation) — the precedent for committing gstack-produced artifacts to git.
- `kit/scripts/capture-screenshot.sh` + the browse daemon — the screenshot infra the visual-diff gate reuses (note the `specs/` write-path footgun the script already works around).
- `kit/ROADMAP.md § v1 § /ak-collateral` — shares an image-composition lineage; could share the asset pipeline.

**Cost/risk.** Several focused days across multiple PRs: the mockup-commit step (~half day), the `/ak-assets` generation + optimization + provenance skill (the bulk — image-model integration, credential plumbing, license tracking), the `/design-html` scaffold wiring (~half day), and the visual-diff gate (~1 day, plus tuning for flakiness). Principal risks: visual diffs are inherently flaky (anti-aliasing, font rendering, dynamic content) → gate on a generous threshold + human override, never hard-fail on small deltas; image-gen licensing/provenance must be tracked at generation time, not retrofitted; and a mockup the model can't realistically build wastes a cycle → keep `/design-html` scaffold as the reality check before committing a mockup as an acceptance target.

[v+, surfaced-by visual-design-conversation-2026-05-31]

---

### Playwright video recording — ffmpeg + `playwright.config.ts` wiring + WebM→GIF for PR embedding

**What this is** — durably capture video evidence of E2E test runs as Playwright artifacts, surface them in CI failure investigation, and (downstream) embed GIFs in PR bodies for visual debugging context. Three coupled pieces that should ship together as one PR (not three).

**Current state (verified 2026-05-19 during the `sandbox-qa-close-gap` PR)**

- **Chromium**: ✅ apt-baked in `template/.devcontainer/Dockerfile` lines 43-60 (commit `1df36b0`, 2026-04-23). `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium` in `devcontainer.json` containerEnv (line 76-77). Playwright launches against this binary, bypassing the CDN-IP-rotation problem entirely.
- **ffmpeg**: ❌ NOT in any image — neither `template/.devcontainer/Dockerfile` nor the devshop's own devcontainer ships it.
- **Playwright `video:` config**: ❌ Not wired anywhere. `grep -rE "video:.*on|video:.*retain-on-failure|recordVideo" .claude/skills/ template/ kit/docs/` returns zero hits. No project (lalista, home-os) uses it.
- **WebM→GIF**: ❌ No pipeline. GitHub PR bodies render GIFs but not WebM (see `.claude/skills/gstack/TODOS.md:428` — already on the gstack roadmap).
- **Test artifact upload**: ⚠ `apps/web/test-results/` is already included in the upload artifact path per `kit/docs/guide/ops.md:75` ("videos / traces / `error-context.md` live in `test-results/`") — so the upload glob is correct; the videos just aren't produced.

**Why this is deferred from `sandbox-qa-close-gap` (2026-05-19)**

That PR considered adding ffmpeg alone, but operator review (correctly) flagged it as YAGNI: shipping the binary without a consumer is image-bloat for tooling capability nobody currently uses. The architectural sequence is wrong if we ship ffmpeg first — `apt-get install` runs every container rebuild, costing build time / bandwidth, for a binary that produces zero bytes of value until step (B) wires it up. Ship all three together when the trigger condition fires.

**Trigger condition to ship**

The first time a debugging session would have benefited from a recorded video — typically a flaky E2E that reproduces visually but not in CI logs, or a UI regression that's hard to describe in prose. Until that happens, write the entry, don't ship the code.

**Three deliverables (~2-3 hr combined)**

**(A) Workspace Dockerfile — add `ffmpeg` to the apt-install block** (~5 min, locked-file recipe).

Add `ffmpeg` to the existing `RUN apt-get install` block at `template/.devcontainer/Dockerfile` lines 43-60, alongside the Chromium libs. The exact diff (drafted + verified working in the 2026-05-19 session, dropped from the PR but preserved here verbatim):

```dockerfile
# In the existing comment block above the chromium RUN, append:
#
# ffmpeg is required for Playwright's `video: 'on' | 'retain-on-failure'`
# recording option. Without it, Playwright silently produces zero-byte video
# artifacts on test failure (no error surfaced; the CI artifact is present
# but useless). Baking it here keeps recording-on-failure working out of the
# box for every project's E2E suite.

# In the RUN apt-get install block, add ffmpeg between chromium-driver and libnspr4:
RUN apt-get update && apt-get install -y --no-install-recommends \
  chromium \
  chromium-driver \
  ffmpeg \
  libnspr4 \
  ...
```

No `checksums.sha256` entry needed (apt repo signing covers it). Locked-file recipe: write to `/tmp/staging/Dockerfile.new`, then `sudo install -m 644 -o root -g root /tmp/staging/Dockerfile.new <worktree-path>` per `kit/docs/guide/security.md § Authoring locked files`.

**(B) `playwright.config.ts` — wire video recording per project** (~10 min, in each project's `apps/web/playwright.config.ts`).

The minimal config:

```ts
// apps/web/playwright.config.ts (project-side; lives in apps/web, not template)
export default defineConfig({
  use: {
    video: 'retain-on-failure', // captures every test; drops on success
    // or 'on' for always-capture during heavy debugging
    trace: 'retain-on-failure', // already common; keep
  },
  // ...
});
```

Choose `retain-on-failure` (not `on`) by default — `on` produces a WebM per test even on green runs, blowing up artifact size for no value. The trace artifact already covers green-run debugging.

Generalization to template: when this entry ships, the same config snippet lands in `template/apps/web/playwright.config.ts` (the file ships from the baseline as of 2026-05-19 — patch over what's already there).

**(C) WebM→GIF for PR embedding** (~1.5 hr, the bulk of the work).

WebM is what Playwright produces; GitHub PR bodies render `.gif` inline but `.mp4`/`.webm` only as download links. The conversion needs:

- A post-test step that finds every `test-results/**/video.webm`, converts to `.gif` (ffmpeg one-liner: `ffmpeg -i video.webm -vf "fps=10,scale=720:-1" -y out.gif`), trims to <10 seconds (last N seconds before failure are usually the useful ones), and uploads alongside the WebM.
- A PR-body templating decision: where do video links go? `/ak-build § Phase 6 § Evidence section` is the natural home (alongside hero shots). The image-embed must use the `https://github.com/<owner>/<repo>/raw/<branch>/<path>` URL form per `/ak-build § PR body conventions § Image embeds` (private-repo safe).
- Size budget: target <5MB per GIF after conversion. GIFs >25MB hit GitHub's upload limit silently.

Existing gstack TODOs already track parts of this:

- `.claude/skills/gstack/TODOS.md:71` — Playwright browser context isolation (prerequisite for video recording)
- `.claude/skills/gstack/TODOS.md:82` — Playwright supports video recording per context + WebM→GIF for PR embedding
- `.claude/skills/gstack/TODOS.md:428` — GitHub PR bodies render GIFs but not WebM

When this entry ships, those gstack TODOs cross-resolve.

**Dependencies**

- ⓘ `template/apps/web/playwright.config.ts` exists as of the 2026-05-19 baseline — this entry is a follow-on patch.
- ⓘ Lalista's existing `apps/web/playwright.config.ts` already has the file shape, so (B) can ship to lalista in this entry's PR and template-side in the same PR.

**Why this stays v+ for now**

No project has hit "I wish I had a video of that test failure" in the soak window covering lalista (>50 PRs) + home-os (28 PRs as of 2026-05-19). Error-context.md + trace.zip + screenshots have been sufficient for every CI failure investigation to date — and the `/ak-build § Phase 5.4` artifact-pull recipe already routes operators to those artifacts. Promote to v0/v1 when the trigger condition fires.

**Cross-ref**

- `template/.devcontainer/Dockerfile` lines 43-60 — the apt-install target for (A)
- `template/.devcontainer/devcontainer.json` lines 76-77 — `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium` (already shipped)
- `kit/docs/guide/security.md § Authoring locked files` — the recipe for (A)
- `.claude/skills/gstack/TODOS.md:71, 82, 428` — gstack-side prerequisites that resolve when this lands
- `.claude/skills/ak-build/SKILL.md § PR body conventions § Image embeds` — the URL form for (C)
- `kit/docs/guide/ops.md:75` — the existing CI artifact-upload glob (`test-results/`) already covers videos

[v+, deferred from `sandbox-qa-close-gap` 2026-05-19 after operator review; trigger: first session where a video artifact would have shortened a debugging arc]

---

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

The `slow` job in `.github/workflows/ci.yml` ships ACTIVE at scaffold time (since `template-ci-overhaul`, 2026-05-19) with empty-state guards. It gates new content automatically — the first integration test or E2E spec a project lands is gated by CI immediately, no operator action. Per-project wiring still happens as features land, but never as a "must uncomment the stub" step.

**Trigger 1: First DB-backed feature** (e.g., auth, data queries):

The template stub already includes the canonical shape — no uncomment ritual:

- `supabase/setup-cli` step + `supabase start` (GitHub Actions has native Docker — no DinD)
- The lalista-PR-26 `supabase_edge_runtime` health-check retry loop (preserve it; don't strip)
- `scripts/ci-type-drift.sh` — regenerates `packages/core/src/supabase.types.ts` against the local stack and fails on drift (helper ships in `template/scripts/`; copied verbatim into every project)
- `scripts/ci-rollback-explain.sh` — for each migration with `-- ROLLBACK:`, applies the rollback then re-applies forward (round-trip), catching syntax errors before they bite during a real outage (also ships in `template/scripts/`)

Per-project wiring (the only operator-facing work):

- Add `SUPABASE_SERVICE_ROLE_KEY` to CI Variables — value is the local-stack default JWT (published; same value across every Supabase install). Per the security-posture cleanup, prod service-role NEVER goes here.
- Add `ANTHROPIC_API_KEY_QA` to CI Secrets if edge functions call Claude — re-exported as `ANTHROPIC_API_KEY` inside the test step's env block. `ANTHROPIC_API_KEY_PROD` is unrelated to CI; it's pushed to Supabase by `deploy-functions.yml`.
- Update branch protection to require `slow` alongside `fast`.

Full lifecycle convention (day-one-active model, structural enforcement, codified prior art): `kit/docs/guide/conventions.md § Slow-Job Lifecycle`. The `/ak-pre-ship` gate `slow-job-lifecycle` is the regression guard — catches if the active stub gets re-commented, the `if:` predicate broken, retry pattern stripped, empty-state guards dropped, or the unguarded `Start local Supabase` accidentally gated.

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

### API performance baselines for `/benchmark`

The current `/benchmark` skill measures frontend Core Web Vitals; an API-side
companion would measure key query response-times against representative data
volumes and alert when they degrade. Build when a project ships a query whose
performance degrades silently as data grows — load-test with realistic data
volume, record baselines, surface drift in `/benchmark` reports.

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

---

### Gitignore `specs/` in project repos — stop tracking devshop process artifacts

**Problem.** `/ak-build` creates `specs/<feature>/` directories in the project repo containing spec files (`spec.md`), task checklists (`tasks.md`), gate review logs (`review.md`), per-gate shard files (`gates/*.md`), hero screenshots (`hero/*.png`), and QA walk logs. These are devshop process artifacts — they serve the build pipeline during implementation but have no value post-merge. They currently get committed and pushed to the project's remote, mixing devshop scaffolding with project code. Home-os has 10 features' worth of specs (~7.8 MB, 115 screenshots) tracked in git — none referenced by runtime code, CI, or tests.

**Why not just gitignore now.** The `/ak-build` Step 0 resume logic reads `spec.md`, `tasks.md`, and `review.md` from disk to determine where a crashed build left off. The pipeline also explicitly `git add` + `git commit` spec artifacts at Phase 0, Phase 3.1b, and Phase 3.3. These mechanics need updating.

**What gitignoring means for resume.** Gitignored files still exist on disk — they survive container restarts and session crashes. The resume logic reads from the filesystem, not git history, so resume still works. Only a catastrophic volume loss would wipe in-flight specs, and the worst case is re-running `/ak-build` from Phase 0.

**Shape of the fix:**

1. Add `specs/` to project `.gitignore` (template + existing projects).
2. `git rm -r --cached specs/` in each project (files stay on disk, just untracked).
3. Remove `git add specs/...` + `git commit` calls from `/ak-build` Phase 0, Phase 3.1b, Phase 3.3.
4. Update `/ak-merge-devshop` to compose squash-commit messages from commit messages and PR body instead of reading `spec.md` / `review.md`.
5. Re-point any E2E test that writes into `specs/` to a different output directory.
6. Optionally strip `-- Source: specs/...` comments from migration convention (commit messages carry the same provenance).

**What you lose:** git-tracked spec history (old commits still have it), `-- Source:` comments in migrations, `specs/` visible on GitHub after merge. **What you gain:** clean separation of devshop process from project code, ~7.8 MB removed from repo, no devshop jargon in the project file tree.

**Trigger:** after `strip-pr-process-artifacts` ships (the lower-cost PR-surface cleanup), when the operator confirms the trade-off (ephemeral specs, re-run-from-scratch on catastrophic loss) is acceptable.

**Cross-ref:**

- `kit/TODOS.md` § Strip devshop process artifacts from PR descriptions and comments (companion)
- `/devshop/.claude/skills/devshop/build/SKILL.md` § Step 0 (resume logic), lines 111-113 ("durable vs ephemeral" contract)
- home-os PR #34 cleanup (2026-05-26)

**Cost/risk:** ~2–3 hours. Risk: in-flight specs lost on catastrophic volume loss → re-run `/ak-build` from scratch.
