---
name: ak-go-live
version: 1.2.0
description: |
  Autonomous deploy pipeline: merge → deploy → canary → reflect → notify.
  Runs after user approves PR. Chains /land-and-deploy → /canary → reflection.
  Does NOT auto-rollback — production rollbacks need human judgment.
  Use when asked to "land it", "go live", "deploy", or "merge and ship". (devshop)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
  - Agent
  - AskUserQuestion
---

# Go Live

Autonomous deploy pipeline: merge → deploy → canary → reflect → notify.

Run after the user has reviewed the PR and is ready to deploy.

## Step 1: Pre-flight

Verify the PR is ready:

```bash
PR=$(gh pr list --head "$(git branch --show-current)" --json number,mergeable,reviewDecision --jq '.[0]')
```

Check:

- PR exists
- CI is green (`gh pr checks`)
- No merge conflicts

If any check fails, report and stop.

## Step 1.5: Production health probe (catches pre-existing prod issues before merge masks them)

After PR readiness is confirmed but BEFORE invoking `/land-and-deploy`, curl the production URL from `CLAUDE.md § Deploy Configuration`. The goal isn't canary verification (that's Step 3 post-deploy); it's catching pre-existing production failures whose symptoms the about-to-land deploy might silently change or mask.

```bash
PROD_URL=$(grep -i 'production.*url' CLAUDE.md 2>/dev/null | head -1 | sed 's/.*: *//' | tr -d '[:space:]')
[ -z "$PROD_URL" ] && echo "PROD_URL not configured in CLAUDE.md § Deploy Configuration — skipping health probe" && exit 0
echo "Probing production at $PROD_URL ..."
HTTP=$(curl -s -o /tmp/prod-preflight.html -w "%{http_code}" --connect-timeout 8 "$PROD_URL/" 2>/dev/null)
echo "HTTP $HTTP"
```

**If `HTTP` is 2xx or 3xx**: production is healthy. Continue to Step 2.

**If `HTTP` is 000** (connection failed — typically firewall-IP-rotation, not a prod issue): the devcontainer's `init-firewall.sh` resolved the prod URL's IPs at container start, but the CDN (Vercel/Netlify/Cloudflare) has rotated to fresh IPs that aren't in the allowlist. **Do NOT treat this as a pre-existing prod issue** — it's an in-container connectivity issue, prod is probably fine. Surface the same 3 fallback paths as Step 3's canary fallback (in order of friction, lowest first):

1. **Operator-side curl via shell escape** — emit a single `!`-prefixed line the user can paste into their terminal:

   ```
   ! curl -sI <PROD_URL>/ | head -5
   ```

   Output lands in the conversation; you can read the HTTP status + headers and complete the pre-merge probe from there. If 2xx/3xx, continue to Step 2. If 4xx/5xx, treat as a real pre-existing prod issue (path below).

2. **Browser open** — ask the user to open `<PROD_URL>` in their browser and tell you what they see (200 + expected content vs 4xx/5xx error page).

3. **Devcontainer rebuild** — the heavy option. Re-runs `init-firewall.sh` and re-resolves CDN IPs. Higher friction than paths 1 + 2; only suggest if those don't work.

**If `HTTP` is 4xx or 5xx** (a real response from the server): production has a pre-existing issue. Surface to the user via AskUserQuestion:

> Production `$PROD_URL/` is currently returning HTTP `<code>`. This is pre-existing (caught before this PR's merge), not introduced by the diff about to land.
>
> Options:
>
> - **Investigate first** — pause `/ak-go-live`; spin up a separate session to diagnose the production failure before merging anything that may interact with the same code paths.
> - **Ship + flag** — proceed with the merge if you can confirm the diff doesn't touch the failing surface; file a TODO for the prod issue with the symptoms captured.
> - **Ship and ignore** — only if you already know about this issue and are tracking it elsewhere.

**Codified from**:

- The 4xx/5xx path: lalista PR 26 (2026-04-26). Prod `/` had been returning 500 since project setup (trailing newline in `NEXT_PUBLIC_SUPABASE_URL` from a copy-paste fat-finger; SSR `getUser()` fetched the malformed URL and threw uncaught). Nobody noticed because every authenticated flow goes through `/sign-in`, which worked. Caught during this Step 1.5 probe, fixed in the same PR before merge (added `.trim()` defense at every env var read site).
- The HTTP 000 split: lalista PR 28 (2026-04-27). Pre-merge probe AND post-merge canary BOTH hit HTTP 000 within ~10 minutes of each other (Vercel rotated edge IPs since container start). The previous Step 1.5 logic lumped 000 with 4xx/5xx and asked "investigate the prod failure?" — wrong category, costing ~30 sec of disambiguation per occurrence. Step 3 already had the firewall-fallback paragraph; mirroring it here closes the gap so the agent doesn't re-derive disambiguation each session.

The probe is a single curl; it adds <1s in the green path and saves a fix-loop on the red path.

## Step 1.6: Migration sequencing pre-flight (catches non-additive migrations before the parallel-deploy race)

Only fires when the PR diff touches `supabase/migrations/**`. The architecture's implicit assumption is that all migrations are backwards-compatible in **both** directions during the PR window — new code on old schema works (handles missing column gracefully), AND old code on new schema works (new NOT NULL column has a default). Additive migrations satisfy this; mutating migrations (renames, drops, NOT NULL without default, type changes) violate it — they break Vercel preview during the PR window AND cause a ~30–60s post-merge race where prod runs new code against the old schema before `deploy-migrations.yml` finishes.

```bash
BASE=${BASE:-main}
MIGRATIONS_TOUCHED=$(git diff --name-only "origin/${BASE}...HEAD" 2>/dev/null | grep -E '^supabase/migrations/' || true)
[ -z "$MIGRATIONS_TOUCHED" ] && : # no migration changes; skip the rest of Step 1.6
```

If the diff touches migrations, classify each touched file. Honor a pre-declared classification when present:

1. **Spec pre-declaration** (preferred). If `specs/<feature>/spec.md` has a `## Migration Sequencing` section recording the migration's compatibility + deploy plan, trust that classification. Track A of the migration-sequencing convention plants this at spec time; this step is its enforcement point.

2. **Heuristic classification** (fallback when the spec didn't pre-declare). Scan each touched file for mutating signals; if any fire, treat as mutating:

   ```bash
   for f in $MIGRATIONS_TOUCHED; do
     # Mutating signals (any one match → mutating):
     #   DROP TABLE / DROP COLUMN / DROP CONSTRAINT
     #   RENAME (table or column)
     #   ALTER COLUMN ... TYPE
     #   ALTER COLUMN ... SET NOT NULL (without an accompanying DEFAULT in same file)
     # Additive (none of the above):
     #   CREATE TABLE / CREATE INDEX / CREATE POLICY
     #   ALTER TABLE ... ADD COLUMN [... DEFAULT ...]
     grep -iE 'DROP (TABLE|COLUMN|CONSTRAINT)|RENAME (TABLE|COLUMN|TO)|ALTER COLUMN .* (TYPE|SET NOT NULL)' "$f" || true
   done
   ```

   When the heuristic is ambiguous (mixed signals, novel DDL shape), prefer the **mutating** default — a false positive costs one operator-question; missing a real mutating migration costs a ~30–60s prod brownout.

If every touched migration is **additive** → continue to Step 2. The post-merge `deploy-migrations.yml` race is fine per the existing comment in that workflow (new code handles missing column with default; old code ignores added column).

If any migration is **mutating** → BEFORE invoking `/land-and-deploy`, surface via AskUserQuestion:

> The PR's migration `<NNN>_<name>.sql` is mutating (rename / drop / NOT NULL without default / type change). After merge, Vercel auto-deploys the front-end in parallel with `deploy-migrations.yml`; for ~30–60s prod runs new code against the old schema → user-visible 500s. Vercel preview during the PR window also reads prod, so reviewers may see breakage that looks like a real bug.
>
> Options:
>
> - **Apply migration to prod first, then merge** (recommended). Run `supabase db push --include-roles` against prod via the operator-side path the project documented in `CLAUDE.md` (Path A: password-manager CLI like `op read`; Path B: `!`-prefix shell escape with `read -s`), OR trigger `deploy-migrations.yml` via `gh workflow run`. Confirm prod schema is M+1 (e.g. via `supabase db diff` or a direct query). THEN merge the code PR. Closes the parallel-deploy race window.
> - **Merge anyway, accept brief breakage** — only if `specs/<feature>/spec.md § Migration Sequencing` already documented this as an accepted trade-off (timeboxed: "preview is intentionally broken from PR-open to PR-merge; expect <2hr").
> - **Pause and re-spec** — the spec author skipped Track A's scoping question. Surface the gap, update the spec, then resume `/ak-go-live`.

**Codified from**: `kit/ROADMAP.md § Migration sequencing safety nets for the Vercel-preview window` (Track B). This step adds the **pre-merge** half of the migration-sequencing discipline; the **post-merge** half is already documented in the sequencing-note comment of `apps/web/.github/workflows/deploy-migrations.yml`.

## Step 1.7: Auth-config deploy reminder

Vercel app + Supabase migrations + edge functions all auto-deploy on push:main. **Auth config** (`site_url`, `uri_allow_list`, password policy, CAPTCHA, email templates) does NOT — it ships via the Supabase dashboard or `PATCH /v1/projects/{ref}/config/auth` manually.

If the spec or PR body references auth-config changes, surface to the user before merge:

> The PR references auth-config changes that don't auto-deploy with the merge. Apply them via the Supabase dashboard or Management API now, ideally **before** the app deploy if the new code relies on new redirect URLs / CAPTCHA / password policy. Auth-config changes are cheap to roll back (re-PATCH), so ordering is flexible — but they must ship manually.

Rollback is reverse-order across all surfaces with the same backwards-compatibility caveats: revert the app first to pull traffic off the new schema/functions, then roll back migrations (if the migration's `-- ROLLBACK` block supports it) and edge functions. Full surface table + rollback semantics: `kit/docs/guide/conventions.md § Deploy Boundaries`.

## Step 2: Land and deploy

Invoke `/land-and-deploy` via Skill tool.

gstack's `/land-and-deploy`: checks CI green, merges PR, waits for deploy, verifies
production health. If CI is failing, it stops (does not merge).

## Step 2b: Branch cleanup + PLAN.md / BUILD-LOG sanity check

After merge, clean up the feature branch locally and prune stale remote refs. `PLAN.md` + `BUILD-LOG.md` are closed by `/ak-build` Phase 5.6 on the feature branch **before merge**, so by this point main already has the ship entry in `BUILD-LOG.md` and no longer references `$FEATURE_BRANCH` in `PLAN.md § Active`. This step is branch hygiene only — no commits on main, no second PR.

```bash
FEATURE_BRANCH=$(git branch --show-current)
git checkout main
git pull
git branch -D "$FEATURE_BRANCH"
git remote prune origin
```

### Sanity check — did Phase 5.6 run?

Verify that `PLAN.md § Active` no longer references `$FEATURE_BRANCH`. If it does, Phase 5.6 was skipped (legacy build, manual PR that didn't use `/ak-build`, or Phase 5.6 silently failed). Do NOT auto-commit the close-out — Claude can't commit to main, and the whole point of Phase 5.6 was to avoid a second PR.

```bash
if awk '/^## Active/,/^## Planned/' PLAN.md | grep -qF "$FEATURE_BRANCH"; then
  echo "⚠  PLAN.md still shows $FEATURE_BRANCH under ## Active."
  echo "   /ak-build Phase 5.6 appears to have skipped."
  echo "   Ask the user to manually:"
  echo "     1. Edit PLAN.md — remove the $FEATURE_BRANCH row from ## Active"
  echo "     2. Edit BUILD-LOG.md — add the ship entry for $FEATURE"
  echo "     3. Commit on main as 'chore: close $FEATURE' (human-initiated commits to main are allowed)"
  echo ""
  echo "   Continuing /ak-go-live; the cleanup is non-blocking for deploy verification."
fi
```

The sanity check surfaces the issue; it does not block or auto-fix. Clean Phase 5.6 runs leave this check a silent pass.

## Step 3: Canary monitoring

Invoke `/canary` via Skill tool.

~15 min post-deploy monitoring: console errors, performance regressions, page failures.

### Firewall-IP-rotation fallback (if canary can't reach prod)

If `/canary`'s curl reports `HTTP 000` with `Failed to connect ... No route to host`, the devcontainer's `init-firewall.sh` resolved the prod URL's IPs at container start, but the CDN (Vercel/Netlify/Cloudflare) has rotated to fresh IPs that aren't in the allowlist. This is a known footgun documented in `kit/docs/guide/ops.md § Known Footguns § Firewall IP rotation` — but `/canary` doesn't currently detect-and-recover.

When this happens, surface the 3 fallback paths to the user (in order of friction, lowest first):

1. **Operator-side curl via shell escape** — emit a single `!`-prefixed line the user can paste into their terminal:

   ```
   ! curl -sI <PROD_URL>/ | head -5
   ```

   Output lands in the conversation; you can read the HTTP status + headers and complete canary verification from there.

2. **Browser open** — ask the user to open `<PROD_URL>` in their browser and tell you what they see (200 + expected content vs 4xx/5xx error page).

3. **Devcontainer rebuild** — the heavy option. Re-runs `init-firewall.sh` and re-resolves CDN IPs. User pastes a "verify prod after deploy" prompt in a fresh session; the merge state on main + BUILD-LOG entry are durable, so resumption is cheap.

Codified from lalista PR 26 (2026-04-26): `/ak-go-live` Step 3 hit `No route to host` on `lalista-ten.vercel.app` because Vercel rotated edge IPs since container start. User chose option 2 (browser-confirmed prod healthy in 5 seconds), pipeline closed out cleanly.

**If canary fails**: STOP. Do NOT auto-rollback. Post rollback info and notify user:

```bash
GITHUB_USER=$(gh api user --jq .login 2>/dev/null || git config user.name)
PR=$(gh pr list --state merged --head "$(git branch --show-current)" --json number --jq '.[0].number')

gh pr comment "$PR" --body "## Canary FAILED — action needed

@${GITHUB_USER} Canary detected issues after deploy.

**Issues found:** <summary from canary output>

**Rollback checkpoint:**
- Vercel deployment: \`vercel ls --meta\` (revert with \`vercel rollback\`)
- Migration version: <latest file in supabase/migrations/>
- Git SHA: $(git rev-parse HEAD)

**Recommended action:** \`vercel rollback\` then investigate on the branch.
See kit/docs/guide/ § When Things Go Wrong."
```

**If canary passes**: continue.

## Step 4: Rollback checkpoint

Record for future reference (even on success):

```bash
echo "Rollback checkpoint:"
echo "  Vercel: $(vercel ls --meta 2>/dev/null | head -2 || echo 'run vercel ls')"
echo "  Migration: $(ls -1 supabase/migrations/ 2>/dev/null | tail -1 || echo 'none')"
echo "  Git SHA: $(git rev-parse HEAD)"
```

## Step 5: Structured reflection

The natural reflection moment — the work just shipped, learnings are fresh. Two distinct categories of capture, both required:

### 5a: Project-side reflection

Ask yourself and route learnings to **committed files** (not memory):

- New conventions, gotchas, calibration updates → project `CLAUDE.md`
- Troubleshooting entries (date, symptom, cause, fix) → `kit/docs/guide/ § Troubleshooting`
- Decision log entries ("chose X over Y because Z, date") → `kit/docs/guide/ § Decision Log`
- Confidence calibration adjustments → project `CLAUDE.md § Confidence Calibration`

Commit (project repo): `docs: post-deploy reflection for <feature-name>`

If nothing project-specific to capture (the bug + commit message + spec docs already carry the context), skip this sub-step. Don't add CLAUDE.md noise for self-evident lessons — see today's prompt: _"the next time this kind of issue hits, the 500 itself is the signal."_

### 5b: Devshop-side generalization (catches lessons that should leave this project)

Did this PR's investigation surface anything that would generalize **beyond this project**? Most sessions produce 0; some produce many. Examples in order of typical leverage:

- **Skill amendment** — a rule that should fire in `/ak-build` / `/ak-go-live` / `/ak-spec` / `/ak-implement` / `/ak-test-review` / `/ak-pre-ship`. Add to the SKILL.md where the action happens, not just to a guide doc — guide docs are Tier 3 and don't auto-load (see `kit/docs/guide/conventions.md § SSR + E2E boilerplate canonical patterns` for the layout pattern of "operational copy in skill, brief reference pointer in guide").
- **Template fix** — boilerplate in `template/` (or referenced from `/ak-new-project Step <N>` if scaffolded inline). Other projects scaffolding from the template inherit on next setup.
- **New convention or extension to an existing one** — `kit/docs/guide/conventions.md` (per the audit, this is Tier 3 reference; pair with a skill amendment that actually fires the rule).
- **`/devshop/CLAUDE.md` Tier 1 entry** — for cross-cutting principles that need to be always-loaded.
- **`kit/ROADMAP.md § v0 / v1`** — work that's bigger than an inline edit and worth filing for later, OR an audit/sweep that needs a focused session.

For each lesson, present: _what was learned, proposed devshop placement, effort estimate_. The user picks which to ship now vs file vs skip.

If nothing this session, just say so — explicitly. Don't fish for lessons; most sessions don't produce them. The signal is high but the rate is low.

**Don't wait to be prompted.** Surfacing devshop-generalizable lessons is the agent's job, not the user's. Lalista PR 26 produced 8 generalizations (firewall closure rule, trace.zip discipline, conventions audit + reviewer-reads-conventions ROADMAP entries, prod-curl probe, firewall-IP-rotation fallback, .trim() defense convention, CSP scheme handling, Realtime publication, WebKit hydration race, edge-runtime retry — all shipped to devshop within the same session). Without this prompt earlier in the session, only 0-1 would have surfaced via ad-hoc memory or a follow-up "anything else?" from the user.

Commit (devshop repo, separate from project commit): per-concept atomic commits per `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships` and `/ak-build § Phase 5.6 step 4` (if any tracker entries close as part of the lessons surfaced).

## Step 6: Notify

```bash
GITHUB_USER=$(gh api user --jq .login 2>/dev/null || git config user.name)
PR=$(gh pr list --state merged --head "$(git branch --show-current)" --json number --jq '.[0].number')

gh pr comment "$PR" --body "## Deployed to production

@${GITHUB_USER} Deploy complete. Canary passed.

**Production URL:** <from deploy config>
**Rollback SHA:** $(git rev-parse HEAD)
**Reflection:** committed in $(git log --oneline -1)"
```
