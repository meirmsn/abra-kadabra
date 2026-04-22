# Workflow: Idea to Deployed

## Pipeline at a Glance

```
┌─────────────────────────────────────────────────────────────────────────┐
│  IDEATION                                                               │
│                                                                         │
│    rough notes                                                          │
│       │                                                                 │
│       ▼                                                                 │
│  ┌─────────────────┐  interviews → product design doc                   │
│  │ /office-hours   │  (demand, urgency, scope)                          │
│  └─────────────────┘                                                    │
└─────────────────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  PLANNING                                                               │
│                                                                         │
│  ┌─────────────────┐  runs sequentially:                                │
│  │ /autoplan       │  ├─ /plan-ceo-review                               │
│  │                 │  ├─ /plan-design-review                            │
│  │                 │  └─ /plan-eng-review                               │
│  └─────────────────┘  → .gstack/projects/<slug>/                        │
│                                                                         │
│  optional (UI-heavy): /design-shotgun → /design-html                    │
└─────────────────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  /ak-build  — autonomous pipeline (one command)                         │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 0 · preview + decisions checkpoint                         │   │
│  │   reads roadmap / design / test-plan sources                     │   │
│  │   → 3-section preview: decisions / scope / tracker               │   │
│  │   user approves → writes specs/<name>/spec.md SKELETON           │   │
│  │     (provenance + Sources + Decisions — no Task order yet)       │   │
│  │   starts live TaskCreate tracker                                 │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                    │                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 1 · /ak-spec                                               │   │
│  │   reads spec.md skeleton (Decisions preserved verbatim)          │   │
│  │   expands in place → full spec (In scope, Task order, Tests, …)  │   │
│  │   flips PLAN.md row Planned → Active                             │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                    │                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 2 · /ak-implement                                          │   │
│  │   decompose → code + tests per task                              │   │
│  │   stuck protocol: try fix → /investigate → ask user              │   │
│  │   atomic commits, decisions logged in tasks.md                   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                    │                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 3 · /ak-pre-ship  (11 gates, re-run tests after each)      │   │
│  │   1. devshop docs check                                          │   │
│  │   2. metrics check                                               │   │
│  │   3. responsive + theme (UI)                                     │   │
│  │   4. /simplify          ──▶ test:unit                            │   │
│  │   5. /ak-test-review                                             │   │
│  │   6. /review            ──▶ test:unit                            │   │
│  │   7. /cso               ──▶ test:unit                            │   │
│  │   8. /design-review (UI)──▶ test:unit                            │   │
│  │   9. /qa                (own fix loop)                           │   │
│  │  10. /benchmark     (UI)                                         │   │
│  │  11. convention check                                            │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                    │                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 4 · /ship                                                  │   │
│  │   merge base → tests → /review → bump VERSION → push → PR        │   │
│  │                                 → auto /document-release         │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                    │                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 5 · CI watch (gh pr checks --watch)                        │   │
│  │   on fail: read logs → fix → push, max 3 cycles, else @mention   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                    │                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 6 · audit-trail PR comment + "@user PR ready"              │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
       │
       ▼
   HUMAN REVIEW  (release notes + audit comment + preview URL)
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  /ak-go-live  — autonomous deploy (one command)                         │
│                                                                         │
│   1. /land-and-deploy   merge → wait for deploy → prod health check     │
│   2. /canary            ~15 min monitor; fail = stop + rollback SHA     │
│   3. structured reflection → CLAUDE.md / guide docs / TODOS / ROADMAP   │
│   4. notify: "@user deployed. Canary: pass/fail. Rollback SHA: xxx"     │
└─────────────────────────────────────────────────────────────────────────┘
```

Standalone skills (usable outside the pipeline): `/ak-status`, `/ak-spec`, `/ak-implement`, `/ak-pre-ship`, `/ak-test-review`, `/ak-new-project`, `/ak-migrate-project`.

## Step 1: Write rough notes

Problem description + rough solution idea. Not a full spec — just enough to seed the conversation.

## Step 2: `/office-hours` (gstack)

Interviews you, challenges framing, produces a product design doc. Forces you to articulate demand, urgency, and scope.

## Step 3: `/autoplan` (gstack)

Runs CEO, design, and engineering review sequentially. Locks in architecture, edge cases, and decisions. Output: a gstack plan in `.gstack/projects/<slug>/`.

- **3b: `/design-shotgun`** (optional) — visual variants before spec. Use for UI-heavy features only. Approve one direction before proceeding.
- **3c: `/design-html`** (optional) — turns approved mockup into an HTML reference file. Claude builds React from this instead of interpreting a description.

## Step 4: `/ak-build` (devshop skill) — autonomous pipeline

One command after autoplan. Chains everything through PR creation, CI verification, and notification. Resumable if the session is interrupted.

**Phase 0: Preview + decisions checkpoint** — the one interactive beat before
token-heavy work. Reads the roadmap section, design doc, and test plan for this
feature; produces a 3-section preview (decisions / scope / hierarchical tracker
simulation) for user approval. On approval, writes `specs/<name>/spec.md` as a
skeleton — provenance header, Sources list, and a fully-populated Decisions
section — and commits it on the feature branch so the user's judgment calls
survive a crash. Starts a live `TaskCreate` tracker mirroring the preview's
hierarchy (phases as rows, Phase 2 expanded into per-task sub-rows). Finally,
emits a remote-control nudge ("type `/remote-control` now if you want
phone/watch monitoring") right before spawning the first subagent — the last
main-context beat before autonomous work begins. On resume paths that skip
Phase 0, the same nudge fires once from Step 0 at the equivalent timing.

**Phase 1: `/ak-spec`** — reads the Phase 0 skeleton and expands it in place
into a full spec (In scope, Screens, Data model, API contracts, Tests, Task
order, Gotchas, Acceptance plan). Preserves the skeleton's Decisions section
verbatim — does NOT re-resolve. Creates the feature branch (`feat/<slug>` or
`fix/<slug>`) if currently on main (inherited from Step 0), and flips the
`PLAN.md` Planned row for this feature into `## Active`. The `## Task order`
section is the discriminator the resume check uses to tell "skeleton" from
"complete spec." METRICS.md confirmation only fires when the Phase 0 skeleton
didn't cover events (rare — only on manually-seeded feature branches).

**Phase 2: `/ak-implement`** — reads spec, decomposes into tasks, implements with tests. Confirms active branch against `PLAN.md § Active`. Stuck protocol: try fix → `/investigate` → ask user. Logs judgment calls in `specs/<name>/tasks.md` § Decisions.

**Phase 3: `/ak-pre-ship`** — quality gates only (no shipping). A Phase 0 preflight runs first: verifies required tooling (Chromium for browser gates) and aborts the whole pre-ship with a `blocked` status if tooling is missing, so gates can't silently turn a missing tool into a cheerful "skipped". After preflight passes:

1. Devshop docs check
2. Metrics check
3. Responsive + theme check (UI PRs) — captures 4-combo evidence screenshots
4. `/simplify` → test:unit checkpoint
5. `/ak-test-review`
6. `/review` → test:unit checkpoint
7. `/cso` → test:unit checkpoint
8. `/design-review` (UI PRs) → test:unit checkpoint
9. `/qa` (has own fix loop)
10. `/benchmark` (UI PRs)
11. Convention check

After all gates pass, hero screenshots are captured to `specs/<name>/hero/` (committed) for the PR audit comment — see `FAQ.md § How are specs and pipeline artifacts organized?` for the hero vs evidence split.

Gate outcomes use four categories: `pass`, `findings (N) [fixed|pending]`, `n/a`, `blocked`. `/ak-build` refuses to advance to `/ship` on any `blocked` gate.

Every gate's report must also include a `## Dismissals` section (body `None` or a bulleted list of findings-with-rationale). Pre-ship aggregates these into a `## Router Summary` block at the top of `review.md` and — when any body is non-`None` — hands the rationales to an adversarial reviewer (`kit/scripts/adversarial-review.sh dismissalLog`) that rejects weak, generic, or out-of-scope justifications. Rejection fails the gate the same as any `findings (N) pending` outcome. The check-type also applies severity-weighted shims for structured-output gates like `/cso` (TENTATIVE findings auto-dismiss with a mechanical rationale, no LLM call). See `hooks.md § Dismissal Log` for the full gating rules, env-var escape hatches, and forward-compatibility with the Phase 4 Finding Router.

**Phase 4: `/ship`** (gstack) — merges base, runs tests + review (final verification), bumps VERSION, pushes, creates PR, auto-invokes `/document-release`.

**Phase 5: CI watch + fix loop** — watches CI via `gh pr checks --watch`. On failure: reads CI logs, reads local test/source code, makes informed fix, verifies locally if possible, pushes. Max 3 fix cycles. Escalates via PR @mention if stuck.

**Phase 6: Audit trail + notify** — posts PR comment with quality gate results, implementation decisions, CI fix summary. Notifies user: "@username PR ready for review."

## Step 5: You review the PR

- Release notes (from `/ship`) + audit trail comment (from `/ak-build`)
- CI green + Vercel preview URL
- You merge or request changes

## Step 6: `/ak-go-live` (devshop skill) — autonomous deploy

One command after you approve the PR.

1. `/land-and-deploy` (gstack) — checks CI green, merges, waits for deploy, verifies prod health
2. `/canary` (gstack) — ~15 min post-deploy monitoring. If fail: stops, notifies with rollback info (no auto-rollback)
3. **Sanity-check PLAN.md + BUILD-LOG close-out** — `/ak-build` Phase 5.6 already removed the Active row from PLAN.md and appended the entry to BUILD-LOG on the feature branch before merge. Step 2b verifies the transition ran; does not auto-fix if skipped (Claude can't commit to main).
4. **Structured reflection** — routes learnings to committed files (CLAUDE.md, guide docs, backlogs)
5. **Notify** — PR comment: "@username deployed. Canary: pass/fail. Rollback SHA: xxx"

---

## Feature tracking: PLAN.md, BUILD-LOG.md, tasks.md

Three artifacts at three different grains:

- **`PLAN.md`** (at project root, forward-looking) — `## Active` and `## Planned` tables at the feature/PR grain. Source of truth for "what's being built right now, on what branch" and "what's next." Consumed by `/ak-implement` (resolves spec via Active row), `/ak-status` (surfaces both sections), `/ak-go-live` Step 2b (sanity check). Written by `/ak-spec` (flips Planned → Active) and `/ak-build` Phase 5.6 (removes Active row at ship).

- **`BUILD-LOG.md`** (at project root, backward-looking) — append-only shipped entries, no sections, most-recent first. One rich entry per merged PR with branch/PR number/spec path/summary/gate results. Written by `/ak-build` Phase 5.6 on the feature branch before merge, so the entry ships as part of the PR itself.

- **`specs/<name>/tasks.md`** (per-feature, live) — in-flight per-task status with commit SHAs. Written by `/ak-implement` as it progresses. Commit-level granularity — this is how you resume an in-progress feature across sessions.

Multiple rows may live in `PLAN.md § Active` at once — parallel feature work is supported, one row per live branch.

## Plan-level changes (rescope, reorder, drop)

The plan is a living doc. When scope shifts:

- **Reorder Planned**: edit `#` values; commit message captures why.
- **Drop a Planned row**: delete it; commit message is the audit record.
- **Defer "maybe later"**: move the entry from `PLAN.md` to `PRODUCT-ROADMAP.md` — explicit signal that it's not next.
- **Rename a feature**: edit the Feature cell; rename the spec folder if the feature is already Active.
- **History**: `git log --follow PLAN.md` shows the full evolution.

No `## Deprecated` section, no status column — git log is the audit trail.

---

## Workflow variants

The main pipeline diagram shows the idea-to-deployed flow. In practice five variants of that flow exist, differing in where you enter the pipeline:

| Variant                        | Entry point                  | Plan-time steps                                                                                                                          | PLAN.md handling                                                                                                           |
| ------------------------------ | ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **Idea → full app**            | Rough notes                  | `/office-hours` → `/autoplan` → seed PLAN.md with one Planned row per PR                                                                 | Planned rows initialized in build order; each `/ak-build` flips row → Active → (removed at ship, entry lands in BUILD-LOG) |
| **New feature (existing app)** | "Let's add X"                | Short `/office-hours` or skip → `/autoplan` scoped → add a Planned row                                                                   | `/ak-build` picks up the row and transitions it                                                                            |
| **Feature improvement**        | "Auth's error UX needs work" | `/autoplan` on the scoped improvement → add Planned row with a new spec folder name, Notes references the prior spec as `**Builds on**:` | Same transitions as a new feature; spec folder is new (original stays as a snapshot of what shipped)                       |
| **Bug fix**                    | Reported bug                 | `/investigate` for root cause → brief Planned row (Notes = "bug fix: X") → `/ak-build` on `fix/*` branch                                 | Row lives briefly; ships like any feature                                                                                  |
| **Urgent hotfix**              | Production incident          | Skip planning — branch, fix, PR, merge                                                                                                   | Optional: retroactive BUILD-LOG entry + PLAN.md row only if meaningful                                                     |

The pipeline machinery is the same across all five — only the pre-pipeline planning depth varies. `/ak-build` doesn't care whether the Planned row came from `/autoplan` or from a one-line edit.

Multiple features can be in flight at once — `/ak-build` and `/ak-implement` ask which one to resume if more than one line is active.

---

## Structured Reflection

After each feature ships, run structured reflection and route learnings to committed files (not memory files):

- What went well? What was surprisingly hard?
- New conventions, gotchas, calibration updates → `CLAUDE.md`
- New troubleshooting entries → guide docs (troubleshooting section)
- Decision log entries → guide docs (decision log section)
- Devshop friction or ideas → `kit/TODOS.md` (tactical) or `kit/ROADMAP.md` (strategic)
- Did confidence calibration need adjustment? (New items for "proceed" or "stop and ask" in `CLAUDE.md`)

---

## Starting a New Project

Run `/ak-new-project` from any devcontainer (the devshop's own or an existing project's).

- **Phase A** creates a GitHub repo populated with the `template/` skeleton.
- **Phase B** runs inside the new project's container for interactive setup (accounts,
  credentials, scaffolding, integrations, security).

The skill tracks progress in `/devshop/kit/notes/projects/<name>.md` (not in
the project repo — keeps project history clean). See
`.claude/skills/devshop/new-project/SKILL.md` for the full step-by-step process.

To adopt the devshop on an existing project, run `/ak-migrate-project` (skeleton —
see `kit/ROADMAP.md`).

---

## Build and Deploy Quick Reference

- `/ak-build` — autonomous pipeline: spec → implement → quality gates → ship → CI watch → notify. Say "build it" after autoplan.
- `/ak-go-live` — autonomous deploy: merge → deploy → canary → reflect → notify. Say "land it" after PR review.
- Individual skills (`/ak-spec`, `/ak-implement`, `/ak-pre-ship`) still work standalone.
- Test commands: `pnpm turbo run test:unit` (fast inner loop), `pnpm turbo run test` (full suite).

For the full pipeline detail, see Steps 1–6 above.

---

## gstack Skill Map

| Skill                  | When to use                            | What it expects           | What it produces                                                                                                     |
| ---------------------- | -------------------------------------- | ------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `/office-hours`        | Start of any feature/project           | Your rough notes          | Product design doc                                                                                                   |
| `/autoplan`            | After office-hours                     | Product design doc        | Architecture plan with resolved decisions                                                                            |
| `/design-consultation` | New project or major visual change     | DESIGN.md + context       | Updated DESIGN.md                                                                                                    |
| `/design-shotgun`      | UI-heavy feature, before spec          | Approved design direction | Visual variant mockups                                                                                               |
| `/design-html`         | After approving a mockup               | Approved mockup           | HTML reference for Claude                                                                                            |
| `/simplify`            | After tests green, before review       | Working code              | Cleaner code (reuse, dead code removal)                                                                              |
| `/review`              | Every PR                               | Diff against base branch  | Staff engineer code review                                                                                           |
| `/cso`                 | Every PR; infra baseline at Phase 0    | Repo state                | Security audit (OWASP, STRIDE, secrets, CI/CD)                                                                       |
| `/qa`                  | Every PR                               | Running app               | Bug reports + fixes + regression tests                                                                               |
| `/design-review`       | Every PR touching UI                   | Running app               | Visual audit + fixes. **Note**: when mobile is added, must explicitly check for visual divergence between platforms. |
| `/benchmark`           | Every PR touching UI                   | Running app               | Core Web Vitals + load time regression check                                                                         |
| `/ship`                | After all quality gates pass           | Clean code + tests        | PR with release notes                                                                                                |
| `/land-and-deploy`     | After PR merge                         | Merged PR                 | Deploy verification                                                                                                  |
| `/canary`              | After deploy                           | Production URL            | ~15 min error/perf monitoring                                                                                        |
| `/investigate`         | When stuck 3x on same error; prod bugs | Error context             | Root cause analysis                                                                                                  |
| `/document-release`    | After ship                             | Shipped code              | Updated README/ARCHITECTURE/CONTRIBUTING/CLAUDE.md                                                                   |
| `/retro`               | Weekly or after milestone              | Commit history            | Retrospective with metrics                                                                                           |

## Devshop Skill Map

| Skill                 | When to use                       | What it does                                                                                 |
| --------------------- | --------------------------------- | -------------------------------------------------------------------------------------------- |
| `/ak-build`           | After autoplan — "build it"       | Autonomous pipeline: spec → implement → quality gates → ship → CI watch → notify. Resumable. |
| `/ak-go-live`         | After PR review — "land it"       | Autonomous deploy: merge → deploy → canary → reflect → notify.                               |
| `/ak-spec`            | Standalone or inside /ak-build    | Converts gstack plan to implementation-ready spec + METRICS.md                               |
| `/ak-implement`       | Standalone or inside /ak-build    | Implements tasks with tests, stuck protocol, decisions log                                   |
| `/ak-pre-ship`        | Standalone or inside /ak-build    | Quality gates only (11 gates). Does not ship.                                                |
| `/ak-test-review`     | Standalone or inside /ak-pre-ship | Fresh-eyes test quality review (report only)                                                 |
| `/ak-status`          | Start of any session              | One-paragraph orientation briefing (read-only)                                               |
| `/ak-new-project`     | New project setup                 | Create repo (Phase A) + guided setup (Phase B). Single entry point.                          |
| `/ak-migrate-project` | Adopt devshop on existing project | Skeleton — two tiers (lightweight, full). See ROADMAP.md.                                    |

> **Skill autocomplete**: The `name` field in SKILL.md frontmatter drives `/` autocomplete,
> not the directory or symlink name. When adding or renaming a skill, set `name: ak-<skill>`
> in the frontmatter to match the desired slash command.
