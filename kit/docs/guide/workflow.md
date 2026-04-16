# Workflow: Idea to Deployed

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

**Phase 1: `/ak-spec`** — converts gstack plan into implementation-ready spec. May stop for METRICS.md confirmation (the one interactive moment before PR).

**Phase 2: `/ak-implement`** — reads spec, decomposes into tasks, implements with tests. Stuck protocol: try fix → `/investigate` → ask user. Logs judgment calls in `specs/<name>/tasks.md` § Decisions.

**Phase 3: `/ak-pre-ship`** — quality gates only (no shipping):

1. Devshop docs check
2. Metrics check
3. Responsive + theme check (UI PRs)
4. `/simplify` → test:unit checkpoint
5. `/ak-test-review`
6. `/review` → test:unit checkpoint
7. `/cso` → test:unit checkpoint
8. `/design-review` (UI PRs) → test:unit checkpoint
9. `/qa` (has own fix loop)
10. `/benchmark` (UI PRs)
11. Convention check

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
3. **Structured reflection** — routes learnings to committed files (CLAUDE.md, guide docs, backlogs)
4. **Notify** — PR comment: "@username deployed. Canary: pass/fail. Rollback SHA: xxx"

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

The skill creates `INIT-TRACKER.md` in the project root for resume tracking. See
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
