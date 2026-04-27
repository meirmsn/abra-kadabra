---
name: ak-go-live
version: 1.1.0
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

**If `HTTP` is 4xx, 5xx, or 000** (connection failed): production has a pre-existing issue. Surface to the user via AskUserQuestion:

> Production `$PROD_URL/` is currently returning HTTP `<code>`. This is pre-existing (caught before this PR's merge), not introduced by the diff about to land.
>
> Options:
>
> - **Investigate first** — pause `/ak-go-live`; spin up a separate session to diagnose the production failure before merging anything that may interact with the same code paths.
> - **Ship + flag** — proceed with the merge if you can confirm the diff doesn't touch the failing surface; file a TODO for the prod issue with the symptoms captured.
> - **Ship and ignore** — only if you already know about this issue and are tracking it elsewhere.

**Codified from**: lalista PR 26 (2026-04-26). Prod `/` had been returning 500 since project setup (trailing newline in `NEXT_PUBLIC_SUPABASE_URL` from a copy-paste fat-finger; SSR `getUser()` fetched the malformed URL and threw uncaught). Nobody noticed because every authenticated flow goes through `/sign-in`, which worked. Caught during this Step 1.5 probe, fixed in the same PR before merge (added `.trim()` defense at every env var read site). Without the probe, the `/ak-go-live` would have merged + the canary would have flagged it post-deploy as a "regression" rather than a pre-existing issue.

The probe is a single curl; it adds <1s in the green path and saves a fix-loop on the red path.

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

Ask yourself and route learnings to **committed files** (not memory):

- New conventions, gotchas, calibration updates → `CLAUDE.md`
- Troubleshooting entries (date, symptom, cause, fix) → `kit/docs/guide/ § Troubleshooting`
- Decision log entries ("chose X over Y because Z, date") → `kit/docs/guide/ § Decision Log`
- Devshop friction → `kit/TODOS.md` (tactical) or `kit/ROADMAP.md` (strategic)
- Confidence calibration adjustments → `CLAUDE.md § Confidence Calibration`

Commit: `docs: post-deploy reflection for <feature-name>`

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
