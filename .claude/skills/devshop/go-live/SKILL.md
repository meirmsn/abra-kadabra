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
