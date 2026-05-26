# Devshop propagation — port to project

I just rebuilt this project's container (after a devshop `main` pull) and
I'm about to run the sync. Walk through every part below in order.
Fail loud on any regression. Pause and confirm before any multi-commit
migration.

---

## Part 0 — Sync

Run `bash .devshopkit/scripts/sync/from-devshop.sh` (shows a preview +
prompts y/N/diff before applying — accept on y). Then `pnpm install`
(package.json gained `pg` + `@types/pg` devDeps, restructured
`ignoredBuiltDependencies`).

---

## Part 1 — Verify rebuild + sync

For each check: report pass / fail with specifics.

1. Container started cleanly — no hang at the "modules directory will be
   removed" prompt during postCreate.
2. `.devcontainer/.env` exists AND contains all 5 Supabase port keys
   (`SUPABASE_API_PORT`, `SUPABASE_DB_PORT`, `SUPABASE_STUDIO_PORT`,
   `SUPABASE_INBUCKET_PORT`, `SUPABASE_ANALYTICS_PORT`) auto-populated
   from `supabase/config.toml` by `derive-ports-from-config.sh`.
3. The 5 ports in `.env` match what `supabase/config.toml` declares (no
   drift).
4. `git status` shows NO `.devcontainer/compose.yml`, `init-firewall.sh`,
   `supabase-runner/*`, `firewall-extra-domains`, or `.husky/*` in the
   dirty tree (sync excludes these as `[locked]`/`[scaffold-once]`).
5. `.gitignore` has `specs/*/screenshots/` line AND the widened
   `.gstack/projects/**` + four-extension re-includes (`*.md`, `*.html`,
   `*.png`, `*.json`).
6. `.nvmrc` reads `22` (was `20`).
7. `.github/workflows/ci.yml` uses `node-version: '22'` and the slow-job
   block is uncommented / active (no more comment ritual).
8. `.github/workflows/keepalive.yml` runs Mon+Thu AND has the Supabase
   ping step referencing `vars.SUPABASE_PROD_ANON_KEY`.
9. `scripts/advisor-probe.mjs` exists (new sync'd file).
10. `pnpm db:start` (or `curl supabase-runner:9000/start`) boots Supabase
    on the project's port set without errors.
11. `kit/notes/projects/<thisproject>.md` frontmatter has
    `supabase_port_offset:` matching the offset in `supabase/config.toml`.
12. `~/.gstack/projects` is a symlink to `/workspace/.gstack/projects`
    (gstack artifact redirect, auto-created by `init-devshop.sh`).
13. Playwright cache stubs exist under `~/.cache/ms-playwright/` (auto-
    populated by `init-devshop.sh` on rebuild — `/qa` should work first
    try).

---

## Part 2 — Manual ports (packages/core)

These files are NOT in `kit/manifest.txt` — `from-devshop.sh` does not
touch them. Port by hand. For each: check current state first, only
change if needed.

2a. **`packages/core/vitest.setup.ts`** — NEW file. WebSocket stub that
prevents `@supabase/supabase-js >= 2.105` from crashing on
`createClient()` in unit tests (Node has no global WebSocket). Copy
from `/devshop/template/packages/core/vitest.setup.ts`.

2b. **`packages/core/vitest.config.ts`** — add `setupFiles:
    ['./vitest.setup.ts']` to the `test:` block (picks up 2a).

2c. **`packages/core/src/supabase.ts`** — two changes: - `const PRODUCTION_PROJECT_REF` gains `: string` type widening - The self-disable comparison changes from
`=== 'PROJECT_REF_PLACEHOLDER'` to `=== 'UNSCAFFOLDED'`
In a scaffolded project, the const already holds the real project ref
(Step 10 sed'd it). The comparison target is the only line to change.
Do NOT touch the const's value.

2d. **`packages/core/src/supabase.test.ts`** — the `guardActive`
variable and all `it.skipIf(!guardActive)` wrappers are removed.
Tests run unconditionally. Diff against
`/devshop/template/packages/core/src/supabase.test.ts` and port the
new shape, preserving any project-specific test additions.

---

## Part 3 — Project-owned file catch-up

Each item: check first, report "already done — verified by X" or
"not done — here's the plan, OK to proceed?".

3a. **CLAUDE.md architecture migration** (per
`/devshop/kit/docs/guide/claude-md.md § Migration recipe`).
Multi-wave migration from bloated to slim. Check `wc -c CLAUDE.md` —
if under ~9k bytes the trim is likely done; verify any drift is
organic per the 3-class taxonomy. If not done, this is ~3-5 hours,
multiple commits. Pause and confirm before starting. Pre-reading: - `kit/docs/guide/claude-md.md` - `kit/notes/claude-md-migration.md` - `kit/notes/home-os-claude-md-classification.md` (worked example) - `kit/notes/lalista-claude-md-classification.md` (if lalista —
refresh against current state, some entries now covered by newer
guide docs)

3b. **CLAUDE.md hand-edits** (independent of 3a — do these regardless): - Fix hook reference: `check-docs-freshness-project.sh` →
`check-docs-coverage-project.sh` - Add `pnpm db:advisor` to the Database Commands section - Add SQL conventions block: security definer `search_path` pinning,
RLS `auth.uid()` subquery wrap, FK index requirement,
`ADVISOR-EXEMPT` annotation syntax. Copy from
`/devshop/template/CLAUDE.md § SQL conventions`.

3c. **PLAN.md Lev-scored schema migration** (`9ce4662`).
Canonical shape is now 8 columns: Feature | Hook | Impact | Risk |
Cost | Lev | Deps | Source. Check current shape — if NOT the
Lev-scored table, migrate. Scoring scale + Lev formula in
`/devshop/PLAN.md § How to add entries` (or
`/devshop/template/PLAN.md`). Honest per-row scoring. Order
`## Planned` by Lev descending. Pause before committing — may warrant
its own PR depending on row count.

3d. **PLAN.md version scoping** (`e9c88ba`).
`## Planned` becomes `## Planned (vN)` with a preamble noting the
plan is scoped to one version at a time. Fold into 3c if that's
happening; otherwise apply standalone.

3e. **`.devcontainer/.env.example`** — NEW `[scaffold-once]` file. Copy
from `/devshop/template/.devcontainer/.env.example`. Diff against the
project's actual `.devcontainer/.env` to surface any key drift —
report differences.

3f. **`PRODUCT-ROADMAP.md` pre-seeded entries** — the template stripped 3
sample entries (PWA SW caching, visual regression testing, API perf
baselines). If still verbatim in the project, delete them.

3g. **`METRICS.md` hook reference** — template fixed
`check-docs-freshness-project.sh` → `check-docs-coverage-project.sh`
in the header comment. Fix by hand if stale.

3h. **`README.md` local URLs** — template added a "Local URLs" section
(App, Studio, Mailpit, API) and `pnpm db:advisor` to the commands
list. `README.md` is `[scaffold-once]`. Hand-add if desired (use the
project's actual ports, not template defaults).

---

## Part 4 — GitHub-side configuration

4a. **Add `SUPABASE_PROD_ANON_KEY` as a GitHub Actions Variable** — the
updated `keepalive.yml` pings Supabase with it. Without it the step
fails silently.

4b. **Verify `PRODUCTION_URL` in `.devcontainer/.env`** — if deployed
before devshop `85036de`, the canary may be silently disabled. Check
`.env` has `PRODUCTION_URL=<url>`, and after rebuild
`/etc/refresh-allowed-ips/production_url` is populated. If not, add
URL + rebuild.

4c. **Workflow file push may need human PAT** — if the sync touched
`.github/workflows/`, `git push` from the devcontainer will fail
(PAT lacks `workflow` scope). Push that commit from the host with a
personal PAT.

4d. **Verify CI green** after pushing. The slow-job is now always active
(short-circuits via `hashFiles` guards when no integration/E2E tests
exist). If branch protection requires `slow` as a required check,
verify it resolves correctly.

---

## Reporting

For each Part 1 check: pass / fail with what specifically broke.

For each Part 2–4 item: "already done — verified by X", "partial — did Y,
deferred Z", or "not done — needs full migration, here's the plan +
estimated effort, OK to proceed?".

If any work spans more than one PR (design decision needs buy-in, row
count warrants batching, unexpected scope), pause and tell me — don't plow
through. Commit per logical change on a feature branch.
