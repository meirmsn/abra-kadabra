# Devshop Roadmap

Devshop capabilities to build eventually — how you build, not what you ship.
Tactical fixes go in `TODOS.md`. Project features go in root `PRODUCT-ROADMAP.md`.

Priority tiers:

- **v0** — fixes the current template needs before a second project adopts it. Each exists because the first template-validation project (lalista) surfaced a gap every future project will hit. Factoring up now avoids each project re-inventing the wheel.
- **v1** — devshop capabilities that would be valuable but aren't blocking next-project onboarding.
- **v+** — future, when the need is felt.

---

## v0 — blocks next-project adoption

### Audit `kit/docs/guide/conventions.md` → distribute operational copy into the skills that fire

**Problem.** `kit/docs/guide/` (including `conventions.md`) is loaded **on demand only** — never at session start. Skills load their own `SKILL.md` content when invoked. So a convention placed only in `conventions.md` is a paper rule: it never enters my context unless I happen to grep for it. The session that surfaced this (2026-04-26) read `/ak-build` SKILL.md's "Without this, gh run download fails" prereq line, decided artifact-pull was blocked, and never opened `conventions.md` to find the routing rule that would have told it otherwise.

**Tier model** (from the 2026-04-26 audit):

| Tier | Content                                                                        | Loaded when                                |
| ---- | ------------------------------------------------------------------------------ | ------------------------------------------ |
| 1    | `/devshop/CLAUDE.md` (+ project `CLAUDE.md` per session via SessionStart hook) | Every session start                        |
| 2    | Skill `SKILL.md` files                                                         | Only when the matching slash command fires |
| 3    | `kit/docs/guide/**`, `kit/docs/MODEL.md`, `OVERVIEW.md`, `FAQ.md`              | Only when explicitly read or grep'd        |

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

**Problem.** The current pre-commit adversarial reviewers (`devshop-commit-guard.sh` + `adversarial-review.sh`) check whether **bypass reasons** are valid (e.g., is the docsVerified note thorough? is the dirtyTreeReason load-bearing?). They don't check whether the **commit itself** follows the project's documented conventions. So a commit that adds a feature without a test, or adds a metric event without registering it in `METRICS.md`, or skips a doc update that conventions require, sails through the reviewer because the bypass-reason gate is the only checkpoint.

The agent often forgets convention X (especially one buried in conventions.md per the sibling audit above), and the reviewer doesn't catch it because it doesn't know X exists.

**Shape of the fix:**

Extend the adversarial-review prompt construction to **inline relevant `kit/docs/guide/` sections** as context the reviewer uses to flag convention violations. Two modes:

1. **Inline conventions in the existing per-flag reviewers** (cheap, additive). Each existing review (`docsVerified`, `prDescStaleReason`, etc.) gets the relevant conventions appended to its prompt: "These are the documented conventions for this concern; flag the commit if it violates them." E.g., the `docsVerified` reviewer gets `conventions.md § Metrics Lifecycle` and `§ Non-Negotiables → Testing`; the `prDescStaleReason` reviewer gets nothing (no relevant convention).

2. **A new "convention check" gate** that runs unconditionally on every commit (no bypass flag). Reads the diff, reads the conventions, asks the reviewer: "Does this diff follow them?" Cheaper path: only fire on commits that touch `apps/**` / `packages/**` / `supabase/**` (real code), skip on docs-only.

**Implementation surface:**

- `kit/scripts/adversarial-review.sh` — extend the prompt builder to inline guide sections by topic. Add a `CONVENTIONS_TO_INCLUDE` map keyed by review topic.
- `kit/scripts/commit-hooks/devshop-commit-guard.sh` — add a `convention-check` gate (or fold into existing gates per option #1 above).
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
- `/devshop/kit/scripts/commit-hooks/devshop-commit-guard.sh` — the gate-orchestration point.
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
    - `ANTHROPIC_API_KEY` = if edge functions call Claude (used by slow-job)
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
  | `ANTHROPIC_API_KEY`                           | Spend rate-limit until rotated                                                                               |
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
4. **GH Secrets to keep as Secrets**: `SUPABASE_DB_PASSWORD`, `SUPABASE_ACCESS_TOKEN`, `ANTHROPIC_API_KEY`, `SENTRY_DSN`, `SENTRY_AUTH_TOKEN`, `VERCEL_TOKEN`.
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
- `kit/ROADMAP.md` § "Pre-commit test-presence hook (project repo)" below — sibling project-repo convention propagation

**Cost/risk**:

- Implementation: ~3-4 focused hours (template helper + tests, skill rewrite of Step 4/5, doc propagation across 5+ files, lalista mirror, CI re-run + verification). Adversarial review will require 2-3 doc enumeration cycles per commit; budget for that.
- Risk during rollout: lalista's deploy workflows briefly need `SUPABASE_PROD_URL` Variable BEFORE the workflow file change merges (or the parameter substitution will fail). Set the Variable first; merge second. Same for any future project adopting from template.
- Benefit: closes the prod-service-role-in-CI risk by default; eliminates the `SUPABASE_PROJECT_REF` redundancy; documents what's actually sensitive vs symmetric-but-public; provides migration recipe for existing projects.

---

### JIT DB password entry for prod migration deploys via `/ak-go-live`

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
- Update `/ak-new-project` Step 5 — drop `SUPABASE_DB_PASSWORD` from the GH Secrets list (only `SUPABASE_ACCESS_TOKEN` + `ANTHROPIC_API_KEY` + `SENTRY_*` + `VERCEL_TOKEN` remain as Secrets).
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

**Why v0**:

This is the structural completion of the security-posture cleanup. The cleanup closed the prod-service-role-in-CI gap by moving service-role to local-stack defaults; the symmetric move for DB password is to take it out of CI entirely. Without this, the cleanup is "partially structural" — service-role is fully off CI, DB password isn't. Closing the asymmetry is a small skill rewrite + a docs cascade; the cost is low compared to the principal-of-least-privilege payoff.

Holding to v0 (vs v1) because: (a) lalista is the first adopter and is mid-rollout, so the docs cascade lands once; (b) every future project scaffold benefits from starting in the operator-side-migration posture; (c) the cleanup is fresh in mind, so the doc surfaces are still hot.

**Trigger**:

- Lalista's PR 18 merges and the auto-deploy workflows fire for the first time (validates the parameterization). Then this entry is the natural follow-on — same skill, same PR-body shape, but the migration auto-deploy is replaced by `/ak-go-live`'s JIT flow.
- OR: a second project adopts the devshop and the operator pushes back on persisting prod DB password in GH Secrets — that's the cue to ship.

**Cross-ref**:

- `kit/ROADMAP.md § Security-posture cleanup` (just shipped on `feat/security-posture-cleanup`) — the structural enabler this entry completes.
- `lalista/.github/workflows/deploy-migrations.yml` (5b248d9) — the file to delete project-side.
- `/devshop/.claude/skills/devshop/go-live/SKILL.md` — the skill to extend with the JIT phase.
- 1Password CLI: `op read` docs ([1password.com/downloads/command-line](https://1password.com/downloads/command-line)).
- `kit/docs/guide/security.md § CI Credential Isolation` — the home for the third structural-defense bullet.

**Cost/risk**:

- Implementation: ~2-3 focused hours (skill rewrite + doc cascade across 5 files + project-side mirroring + adversarial reviews × 2-3 cycles).
- Risk during rollout: if the password-manager CLI isn't installed at the moment `/ak-go-live` runs the JIT phase, fall-back to Path B (`!`-prefix) keeps the deploy unblocked — no infrastructure prerequisite.
- Benefit: fully closes the persisted-prod-credential-in-CI risk class; the DB password joins the prod service-role key in "lives in password manager + Supabase project, nowhere else." Combined with the just-shipped cleanup, CI's only prod-grade credential becomes `SUPABASE_ACCESS_TOKEN` (account-wide but narrow consumption — used only by `deploy-functions.yml` for management API auth).

---

### Browse binary + Playwright browser availability in project devcontainers

Surfaced 2026-04-26 while attempting to run `/qa-only` + `/design-review` against lalista's PR 18 preview URL from the project devcontainer. The skills produced no audit because **the browse binary is broken** (in the project install) AND **Playwright browsers can't be downloaded** (firewall blocks the CDN).

**Concrete failure sequence**:

1. `gstack/browse/dist/browse` in lalista's `/workspace/.claude/skills/` errors with:

   ```
   TypeError: Attempted to assign to readonly property.
       at /workspace/.claude/skills/gstack/browse/dist/bun-polyfill.cjs:16:1
   ```

   The committed `bun-polyfill.cjs` assigns to `globalThis.Bun` unconditionally, but a recent Bun version made `globalThis.Bun` non-writable. The cached binary was built against an older Bun.

2. The devshop's own `/devshop/.claude/skills/gstack/browse/dist/browse` (built from the same source) **does** load — different Bun-runtime version path inside the binary, apparently. So it's not a source-level issue, it's a stale build of the workspace copy.

3. Trying to use the working devshop binary, Playwright fails because no browsers are cached (`~/.cache/ms-playwright/` empty) and the Chromium env-var fallback isn't honored by Playwright's launch path:

   ```
   ║ Looks like Playwright Test or Playwright was just installed or updated. ║
   ║ Please run the following command to download new browsers:              ║
   ║     npx playwright install                                              ║
   ```

4. Trying to install browsers (`pnpm --filter @lalista/web exec playwright install chromium`) fails because the devcontainer firewall blocks Playwright's CDN:
   ```
   Failed to install browsers
   Error: Failed to download FFmpeg (playwright ffmpeg v1011)
   Error: Download failure, code=1
   ```

The combined effect: project devcontainers can't run `/qa-only`, `/design-review`, `/canary`, `/benchmark`, or any other browse-dependent gstack skill — even though the underlying browser tooling is partially present.

**Why each layer is broken** (so the fix targets the right one):

- **Layer 1 (browse binary stale on workspace install)**: lalista's gstack install dates from a build that targeted a different Bun runtime than what's currently on `$PATH`. Per the project memory's "virtiofs Build Workaround", rebuilding from `/tmp` (because virtiofs blocks Bun's `--compile` rename) is the sanctioned recipe — but it requires the source tree, which lives at `/devshop/.claude/skills/gstack/browse/src/`, not in the workspace.
- **Layer 2 (Playwright browsers not cached)**: lalista's devcontainer Dockerfile is older than the 2026-04-23 fix that apt-installs Chromium directly + sets `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`. The env var IS set on this devcontainer (per `echo $PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` returning `/usr/bin/chromium`) but Playwright's launch path checks the cache dir before honoring the override, so an empty cache dir causes the "please install" message even when Chromium is system-installed.
- **Layer 3 (firewall blocks Playwright CDN)**: the firewall allowlist in `template/.devcontainer/init-firewall.sh` doesn't include `playwright.azureedge.net` / `cdn.playwright.dev` (or whatever current Playwright CDN host is). This is intentional for the apt-baked path (no need for CDN) but blocks the fallback `playwright install chromium` flow.

**Shape of the fix** — three coordinated changes:

1. **Source the rebuild from devshop, not workspace**:
   - Update the `gstack Setup — virtiofs Build Workaround` memory entry to use `/devshop/.claude/skills/gstack/browse/src/cli.ts` as the source path instead of `/workspace/.claude/skills/gstack/browse/src/` (which doesn't exist in project devcontainers — gstack's source only ships with the devshop install, the workspace gets dist binaries only).
   - Optionally: ship a one-line wrapper script `kit/scripts/rebuild-browse.sh` that runs the rebuild + copies binaries back, so the recipe doesn't have to live in operator memory.

2. **Make the Chromium-env-var fallback actually work**:
   - Patch the gstack browse binary's launch path (or document the workaround) so when `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` is set AND `~/.cache/ms-playwright/` is empty, Playwright uses the env-var path instead of demanding the cache. The lalista CLAUDE.md gotcha at `2026-04-23` claims this works — verify it does, or fix it.
   - Alternatively: pre-populate `~/.cache/ms-playwright/` with stub directories that satisfy Playwright's existence check, pointing at the apt-installed Chromium. Cheap; worth investigating.

3. **Cleanup migration recipe for pre-2026-04-23 project devcontainers**:
   - Add a one-off section to `/ak-new-project § Migration: existing project to current credential layout` (or a new sibling section) describing how to bring an older project devcontainer up to the apt-baked Chromium standard. Steps: bring `Dockerfile` in line with the template (`apt-get install chromium chromium-driver`), add `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium` to `containerEnv` in `devcontainer.json`, rebuild devcontainer.
   - Lalista is the canonical first adopter; once shipped, remove the operator-side TODO from `lalista/TODOS.md`.

**Proposed fallback-fix steps for an operator hitting this today** (to embed in the cleanup section + add to skill error messages):

```bash
# 1. Rebuild lalista's browse binary from devshop's source (workspace is virtiofs)
cd /tmp
bun build --compile /devshop/.claude/skills/gstack/browse/src/cli.ts --outfile /tmp/browse-bin
cp /tmp/browse-bin /workspace/.claude/skills/gstack/browse/dist/browse
chmod +x /workspace/.claude/skills/gstack/browse/dist/browse
cd /workspace/.claude/skills/gstack && bash browse/scripts/build-node-server.sh   # rebuilds server-node.mjs

# 2. (If apt-baked Chromium isn't already there) install via apt
sudo apt-get update && sudo apt-get install -y chromium chromium-driver
echo 'export PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium' >> ~/.bashrc

# 3. Manually populate Playwright cache with a minimal stub so the launch path is happy
# (or add the Playwright CDN to the firewall allowlist as a temporary fallback)
mkdir -p ~/.cache/ms-playwright/chromium-1140/chrome-linux
ln -sf /usr/bin/chromium ~/.cache/ms-playwright/chromium-1140/chrome-linux/chrome
```

The exact `chromium-1140` directory name varies by Playwright version (current as of 2026-04-26); detect from `node_modules/.pnpm/playwright-core@*/.../packages.json`.

**Why v0**:

The audit-from-devcontainer story is broken for any project that scaffolded before 2026-04-23 (the apt-bake fix landed) AND hits the browse binary bun-runtime drift. New scaffolds get the apt-bake but still inherit the browse binary fragility. Without this fix:

- `/ak-pre-ship` Phase 0 preflight check claims to verify browser availability — and currently passes when in reality the workspace browse binary is stale, masking the issue until a skill actually tries to drive a browser.
- `/qa`, `/qa-only`, `/design-review`, `/canary`, `/benchmark` are all blocked from working in the devcontainer. Operator either fixes manually (yak-shave) or runs audits from outside the container (loses gstack integration).
- The PR-18-style "visual audit + live QA walkthrough" checkboxes become non-actionable from inside the container.

It's v0 because every project hits it; v1 because it's not strictly blocking adoption (operators can fall back to manual visual checks). Calling it v0 because the cost/benefit of fixing it once is much better than the cost of every project's operator yak-shaving the same path independently.

**Trigger**:

- Lalista's `/qa-only` attempt on PR 18 (2026-04-26) — concrete case study + the operator (current user) is mid-iteration, so the fix payoff is immediate.
- OR: a second project's first `/ak-pre-ship` run.

**Cross-ref**:

- Project memory's `gstack Setup — virtiofs Build Workaround` — the source-rebuild recipe, currently pointing at `/workspace/.../src/` (doesn't exist in project devcontainers); needs update.
- `/devshop/CLAUDE.md § Known Footguns` 2026-04-23 entry: "Chromium is exempt from this footgun as of 2026-04-23 — `template/.devcontainer/Dockerfile` apt-installs `chromium + chromium-driver`." Lalista predates this so doesn't inherit.
- `template/.devcontainer/Dockerfile` and `template/.devcontainer/devcontainer.json` — the canonical apt-bake + env-var pattern.
- `/devshop/.claude/skills/gstack/browse/src/cli.ts` — source path for the rebuild.
- `/workspace/.claude/skills/gstack/browse/dist/{browse,bun-polyfill.cjs,server-node.mjs}` — files that need replacing on lalista.
- Lalista PR 18 conversation 2026-04-26 — the surfacing context.

**Cost/risk**:

- Implementation: ~3-5 focused hours (debug Playwright launch path, write the Chromium-env-var stub, write the migration script, test on lalista, doc cascade across `/ak-new-project § Migration` + the project memory entry + adversarial reviews).
- Risk: low — all changes are operator-side tooling, no prod credential surface, no schema implications.
- Benefit: unblocks the entire gstack browser-skill suite from project devcontainers; closes the "checked at preflight, broken in practice" gap that's currently masking the issue; makes `/ak-pre-ship`'s browser gates actually verify state instead of trusting cached binaries.

---

### Pre-commit test-presence hook (project repo)

Today `check-test-coverage.sh` runs only in the devshop repo itself — it flags `kit/scripts/*.sh` additions/modifications that lack a `.bats` test. Project repos (lalista, every future project) have no equivalent: new `.ts`/`.tsx` files under `apps/*/src/` + `packages/*/src/` can land without a paired `.test.ts` and the pre-commit gate says nothing. `/ak-test-review` catches this at ship time (late — feature already built), and adversarial reviewers can't enforce test _existence_ because no machine-readable invariant exists.

Lalista surfaced the gap post-PR-4 when surveying what CI actually protects: every E2E / integration gate runs only in slow-job CI, unit-test coverage is not machine-enforced at all, and test deletion during refactor is invisible until coverage numbers drift down — which nobody watches.

**Shape of the convention:**

- **New script**: `kit/scripts/commit-hooks/check-test-coverage-project.sh` — mirrors the existing devshop-self version but scoped to project-repo paths:
  - Walks staged `.ts`/`.tsx` files under `apps/*/src/`, `apps/*/app/`, `apps/*/components/`, `apps/*/lib/`, `packages/*/src/`
  - For each, requires an adjacent `.test.ts` / `.test.tsx` / `.integration.test.ts`
  - New file without a test → BLOCK. Modified without a test → WARN (same tiering as the devshop script).
  - Exempt list (conservative, project-tunable): barrel `index.ts`, `*.d.ts`, `*.config.ts`, `page.tsx` / `layout.tsx` (route entry points — unit-testing server components is fraught; E2E covers those), `middleware.ts` (covered by `middleware.test.ts` but flagging needed once), anything under `*/e2e/` or `*/tests/`, any file whose sibling dir contains a `*.integration.test.ts` or `*.spec.ts` that references the filename.
  - Per-project override: `.devshop-test-coverage-exempt` file at repo root, one path per line, commit-auditable.

- **Wire into `.hooks/pre-commit`**: in the project-repo branch, add `bash "$SCRIPTS_DIR/commit-hooks/check-test-coverage-project.sh"` after `check-security-files-freshness.sh`.

- **Convention doc** in `guide/conventions.md § Test Presence`: explain what's blocked vs. warned, how to add to the exempt list (with a commit message explaining why), and the relationship to `/ak-test-review` (hook catches "I forgot entirely"; review catches "this test is weak").

- **`.bats` tests** in `kit/tests/` for the script: fixtures cover (a) new file without test → block, (b) new file with adjacent test → pass, (c) modified file without test → warn not block, (d) exempt file → pass, (e) override file addition → pass.

**Why v0 — blocks next-project adoption:**

Every devshop project will hit this exact gap. Lalista is already carrying a `TODOS.md § v0 § e2e-audit-fill-gaps` entry that exists because unit-test enforcement was not in place — future projects shouldn't have to carry the same note. The hook is cheap (~100 LOC bash, ~200 ms pre-commit overhead) and high-value (closes the "silent test removal" gap `qa-options.md § Q3 shift #6` identified for every project).

**Trigger:**

- Lalista adopts the hook and runs a full commit cycle to flush out false-positive-exempt-list tuning — that data feeds the template's default exempt list
- OR: a second project shows up and immediately needs test-presence enforcement — ship at that moment

**Cross-ref:**

- `kit/scripts/commit-hooks/check-test-coverage.sh` — the devshop-repo prior art (kit-scripts only)
- `lalista/TODOS.md § v0 § e2e-audit-fill-gaps` — the E2E-side pair of this unit-side convention
- `lalista/PLAN.md` row 1 — the concrete surfacing opportunity

**Cost/risk reference (from 2026-04-24 lalista scoping session):**

- Implementation: ~4–6 focused hours (script + .bats tests + doc + wire-in)
- False-positive risk: mitigated by conservative exempt list + per-project override file
- Test-file-existence ≠ test quality: deliberate — `/ak-test-review` is the quality gate
- Maintenance: exempt list drifts a few entries per year; cheap to keep current

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

### Runtime validation at LLM / edge-function boundaries (Zod)

Projects with LLM-backed edge functions (or any endpoint returning structured data) currently rely on TypeScript's compile-time assertions alone — `client.functions.invoke<T>(...)` in Supabase, `(await fetch()).json() as T` in general. The generic or cast is a compiler promise, not a runtime check: whatever the server sends flows through untyped. For LLM-backed endpoints the risk is real — a prompt tweak, model swap, or function refactor that alters the response shape crashes clients at the use-site (`response.foo.bar` on `undefined`) instead of failing fast at the boundary.

Lalista surfaced this during TODOS cleanup 2026-04-22. See `lalista/PRODUCT-ROADMAP.md § v0 § 1j` + PR 6 (`feature/zod-validation`, queued): the `add-item` edge function returns an `AddItemResponse` shape generated by Claude Sonnet + pg_trgm logic, typed client-side via `functions.invoke<AddItemResponse>` with no runtime guard. Every next devshop project with an LLM-backed edge function will hit the same gap.

**Shape of the convention:**

- **Zod as the standard runtime-validation dependency** — added to the template's `packages/core` at scaffold time. ~12 KB min+gzip, tree-shakeable, TS-first schemas with inference.
- **Schema module pattern** — `packages/core/src/schemas/<feature>.ts` holds the Zod mirror of each `<feature>Response` type in `models/index.ts`. `z.infer<typeof Schema>` keeps the TS type and runtime schema in sync from one source.
- **Parse at the client wrapper boundary** — API wrappers in `packages/core/src/api/` call `Schema.safeParse(data)` before returning. On failure: report to Sentry with the raw payload (PII-scrubbed) and throw a typed `{Feature}ValidationError`. `.safeParse()` (not `.parse()`) gives observability a chance before the existing error boundary catches the throw.
- **Permissive object defaults** — use `.passthrough()` on object schemas so unknown fields (forward-compat from future additions) don't throw. Strict only on required shape.
- **Convention doc** in `guide/conventions.md § Runtime Validation at LLM / Edge-Function Boundaries`:
  - When to add Zod (LLM-backed endpoints) vs. when not to (DB queries — generated types + CI drift check already cover; form inputs — HTML5 + platform validation already cover)
  - How to author a schema (`.passthrough()` default, `z.infer` for type)
  - How to surface validation errors (Sentry with scrubbed payload, typed error class)
- **Template scaffold** — `/ak-new-project` adds Zod to `packages/core/package.json` and creates `packages/core/src/schemas/` with a placeholder `README.md` pointing at the convention doc.

**Why v0 — blocks next-project adoption:**

Lalista is about to implement this inline at PR 6 (`lalista/PRODUCT-ROADMAP.md § v0 § 1j`). Shipping the devshop convention **before** lalista PR 6 means lalista adopts the template directly and verifies the convention works on first use. Shipping after means factoring from lalista's inline implementation as prior art (same playbook as Auth UX conventions above, sourced from lalista's PR 2). Either order works — but the convention needs to exist before a second project onboards.

**Trigger:**

- Lalista reaches PR 6 `/ak-spec` time (imminent — queued on `lalista/PLAN.md` row 2)
- OR: a second project shows up with an LLM-backed edge function

**Cross-ref:**

- `lalista/PRODUCT-ROADMAP.md § v0 § 1j` — the inline implementation prior art (or target of adoption if the devshop convention lands first)
- `lalista/TODOS.md § v0 § zod-validation-refactor-to-adopt` — the refactor-to-adopt TODO (filed only if lalista ships inline before the devshop convention lands)
- `models/index.ts` is the devshop-template file where response types live today — schemas colocate as `schemas/*.ts`

---

## v1 (after v0 is validated on the first project)

### Tiered pre-ship pipeline

Auto-detect change scope and pick a tier:

- **Full** (schema, auth, new API, security): all steps
- **Standard** (UI features, new screens): skip `/cso` and `/benchmark`
- **Light** (bug fixes, styling, docs, config): lint + tests + `/review` + `/ship`

Announce which tier was picked. Override with `--full` or `--light`.

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
reason, adversarially reviewed. Same pattern as `dirtyTreeReason` and `docsVerified`.

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

Uncomment the `slow` job (`needs: fast`, `if: github.event_name == 'pull_request'`). Add:

- `supabase/setup-cli` GitHub Action for Supabase CLI
- `supabase start` to spin up local DB stack (GitHub Actions has native Docker — no DinD needed)
- Load `seed.sql` via `psql` against local Supabase Postgres
- Integration test step: `pnpm turbo run test` (runs both unit + integration)
- Type drift check: `supabase gen types typescript` → `git diff --exit-code packages/core/src/supabase.types.ts` → fail if types have drifted from schema
- Rollback SQL validation: for each new migration, extract the `-- ROLLBACK` block and parse it against local Postgres (e.g., `EXPLAIN` wrapper). Fail if syntax is invalid — catches typos before they're needed in an emergency
- Mask secrets: `echo "::add-mask::$SUPABASE_SERVICE_ROLE_KEY"`
- Implementation note: verify which Supabase env vars are actually needed for `supabase start` + `supabase gen types` in CI. Wire only what's confirmed.

**Trigger 2: First E2E-testable flow** (e.g., sign-in → core action → verify):

Add to the `slow` job:

- Install browsers: `npx playwright install --with-deps chromium`
- Build and start app: `pnpm turbo run build --filter apps/web` then `npx next start` against local Supabase
- Run E2E at both viewports: `npx playwright test --project=mobile --project=desktop`
- Upload trace artifacts on failure via `actions/upload-artifact` for debugging
- Cache Playwright browsers using lockfile hash

**Additional secrets for slow job**: `SUPABASE_SERVICE_ROLE_KEY` (integration tests need admin access) and `ANTHROPIC_API_KEY` (if edge function integration tests call Anthropic). Add to GitHub Secrets when wiring up the slow job.

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

Automated tests for `devshop-commit-guard.sh` and other commit hooks. Set up
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
