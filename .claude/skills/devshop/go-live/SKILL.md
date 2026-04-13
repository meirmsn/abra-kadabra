---
name: ak-go-live
version: 1.0.0
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

## Step 2b: Branch cleanup

After merge, clean up the feature branch locally and prune stale remote refs:

```bash
FEATURE_BRANCH=$(git branch --show-current)
git checkout main
git pull
git branch -D "$FEATURE_BRANCH"
git remote prune origin
```

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
See .devshop/GUIDE.md § When Things Go Wrong."
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
- Troubleshooting entries (date, symptom, cause, fix) → `.devshop/GUIDE.md § Troubleshooting`
- Decision log entries ("chose X over Y because Z, date") → `.devshop/GUIDE.md § Decision Log`
- Devshop friction → `.devshop/TODOS.md` (tactical) or `.devshop/ROADMAP.md` (strategic)
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
