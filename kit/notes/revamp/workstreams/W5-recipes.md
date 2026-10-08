# W5 — Stack-agnostic core + recipes

The core names no vendor; services are **recipes** selected by the project's
`stack.yaml`. Depends on D-08 and W4.2 (install layout).
Finding: F-STACK-01 (and F-TPL-06, F-PIPE-13 for migrate).
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]`.

Shape (to be confirmed in W5.1):

```
.devshop/stack.yaml            hosting: vercel | cloudflare-workers | …
                               database: supabase-postgres | d1 | neon | …
                               auth / frontend / e2e / analytics / errors …
recipes/<capability>/<provider>/
  SKILL.md   conventions (loaded on demand)     checks/   capability-contract scripts
  setup.md   new-project steps                  template/ files it contributes
  network.txt  domains        secrets.txt  keys (and where they live: network secret / GH env)
```

## W5.1 Capability contract + `stack.yaml` + deterministic gate resolution — P2 · M4 · M

Done when: the gate runner selects checks purely from `stack.yaml` + recipe
manifests; "no recipe" is reported visibly; contract tests exist per capability.

- [ ] **W5.1.1** Define capabilities and their required checks (e.g. database: `migrations-reversible`, `access-control-coverage`; hosting: `preview-url`, `prod-health`; local-env: `services-up`) — design note, reviewed
- [ ] **W5.1.2** `stack.yaml` schema + validator — V2
- [ ] **W5.1.3** Gate resolver script: capability → recipe check → run; outputs a machine-readable result per gate — V2
- [ ] **W5.1.4** Recipe contract test harness (each recipe must implement or explicitly n/a each check) — V2

## W5.2 Extract existing recipes, no behaviour change — P2 · M4 · L

Done when: the fixture project and one real project produce identical gate results
before/after extraction (V4 + V5).

- [ ] **W5.2.1** `database/supabase-postgres`: supabase-bootstrap, rollback round-trip, RLS coverage, advisor, local-env health, SSR/migrations/database-queries guides, prod-URL test guard (also broaden guard beyond `*.supabase.co`) (F-TPL-06)
- [ ] **W5.2.2** `hosting/vercel`: preview URL, env piping, prod health, go-live checks
- [ ] **W5.2.3** `frontend/nextjs`: lint/build conventions, SSR boilerplate, tailwind guide
- [ ] **W5.2.4** `e2e/playwright`: changed-tests-local E2E part, Chromium handling, hero screenshots
- [ ] **W5.2.5** Remove vendor names from core scripts/skills/hooks; bats test that core contains no vendor tokens outside an allowlist — V2

## W5.3 Neutral core template + starters — P2 · M4 · M

- [ ] **W5.3.1** Core template: repo hygiene, CI skeleton with recipe-contributed jobs, docs skeleton — V3
- [ ] **W5.3.2** Starter `next-supabase-vercel` = today's template, produced from core + recipes; diff vs current template reviewed — V3
- [ ] **W5.3.3** `/ak-new-project` asks for starter or recipes; vendor setup steps come from recipes' `setup.md` — V4

## W5.4 Stack detection + real `/ak-migrate-project` — P2 · M4 · M

- [ ] **W5.4.1** Detector proposes `stack.yaml` from repo files (`wrangler.toml`, `vercel.json`, `supabase/config.toml`, `next.config.*`, …) — V2
- [ ] **W5.4.2** `/ak-migrate-project` = detect → confirm → install pinned devshop + recipes → report uncovered capabilities (F-PIPE-13) — V4 on an existing non-devshop repo

## W5.5 Second recipe via contract tests — P2 · M4 · M

- [ ] **W5.5.1** Write the first non-current-stack recipe when a project needs it (likely `hosting/cloudflare-workers` + `database/d1`) on a tiny fixture; passes contract tests — V4
- [ ] **W5.5.2** Recipe authoring guide (short): how to add a provider, contract checklist — V1
