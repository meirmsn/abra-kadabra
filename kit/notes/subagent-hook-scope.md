# PR 2 — Subagent Hook Scope

**Task for the new session:** figure out how to stop parent-process
workflow hooks from firing inside subagent bash calls. Then apply the
fix (or, if no feature surface exists, confirm the softening approach
is the right fallback).

This note is **self-contained** — the new session shouldn't need any
other file to start. Related context files are listed at the bottom
for when/if deeper history is useful.

---

## TL;DR

During lalista PR 2 (auth), running `/ak-pre-ship` in a subagent
caused two parent-scope hooks to fire inside the subagent's bash calls:

1. `check-dirty-after-commit.sh` — "BLOCKING: working tree still dirty after commit"
2. `check-pr-description.sh` — "MANDATORY: review PR title+description, Step 1 text-only, Step 2 later"

The subagent was explicitly told "don't touch the parent's staged files,
don't commit, PR narrative is the parent's job". Both hooks
contradicted that and hijacked the subagent's attention ~8 times.

The subagent correctly ignored them, but the experience is bad:
hooks should not tell a subagent to act outside its scope.

**Two approaches, in order of ambition:**

- **(a) Softening** — replace `MANDATORY`/`BLOCKING` wording with
  `Note`/`Reminder` + dedup by HEAD SHA. Partial fix: hook still fires,
  but no longer demands a specific control-flow dance. Fully designed
  - staged (scripts inline below). **NOT currently applied** — reverted
    before this doc was written to keep the lalista PR 2 devshop
    hardening PR focused on pre-ship gate quality.
- **(b) Subagent-context skip** — hook scripts detect subagent context
  and exit 0 early. Needs a reliable signal from Claude Code's tooling.
  Investigation required — the whole point of the new session.

The new session should try (b) first. If no reliable signal exists,
fall back to (a) — the scripts are already written.

---

## Environment facts (as of handoff)

- Project: `lalista` (Next.js + Supabase). Workspace at `/workspace`.
- Devshop: `abra-kadabra` at `/devshop`. Own git repo.
- Hooks live in `/devshop/kit/scripts/check-*.sh` (root-owned, write-denied to Claude — need sudo).
- Hooks are registered in `/devshop/.claude/settings.json` under `PostToolUse` → `Bash`. That file is also write-denied.
- Current active Claude Code version: whatever shipped April 2026 (see `CLAUDE_CODE_VERSION` in `.devcontainer/Dockerfile` ARG).

State when this doc was written:

- **Lalista** (`/workspace`):
  - Branch: `feature/auth`
  - Latest commit: `6618141 fix(auth): Tailwind workspace scan + touch target + layout centering + E2E email TLD`
  - PR #10 open: https://github.com/meirmsn/lalista/pull/10 — CI green, ready for review.
  - Tree clean; dev server may or may not be running on `:3000`.
- **Devshop** (`/devshop`):
  - Branch: `feature/pre-ship-hardening` (3 commits ahead of main, unpushed)
  - Commits: `c316d71` (preflight + blocked outcome + template Dockerfile + .env.local step), `978808e` (session resume notes), `d20bfd2` (Chromium symlink + screenshot convention + TODOs + doc sync).
  - Tree: the hook scripts may show as modified if the softening was applied — see "Revert path" below.

---

## Background — what happened

We were shipping lalista PR 2 (auth), and `/ak-pre-ship` had four
browser-dependent gates (responsive, `/design-review`, `/qa`,
`/benchmark`) that previously couldn't run because Chromium wasn't
available on the sandbox. After a Dockerfile fix landed (installs the
14 Chromium shared libs), we re-ran the gates via a subagent.

The subagent's own report of the hook interference (verbatim):

> **Hook interference.** Two project hooks fired ~8 times during my
> run: a "working tree dirty" hook demanding I stash/commit the parent's
> 5 staged files, and a "review PR #10" hook demanding I edit the PR
> title/description. I ignored both since they directly contradicted
> my scope instructions ("don't touch the 5 WIP files", "don't commit",
> PR narrative is parent's job). Worth narrowing those hooks' patterns
> so they don't trip on subagent tasks that are intentionally scoped
> around a parent's staged work.

Two problems in one bug:

1. **Wrong audience.** The hooks address the top-level agent's
   workflow (you're mid-commit, you have a dirty tree, your PR has
   new commits) but fire on every subagent that happens to do bash.
2. **Wrong tone.** The hooks use `MANDATORY`/`BLOCKING`/`MUST`
   language that forces a specific control-flow response. A subagent
   (or a top-level agent mid-subtask) may legitimately need to
   proceed without stopping.

(a) fixes #2 only. (b) fixes #1 and obsoletes the need for #2.

---

## Approach (b) — subagent-context skip (investigate first)

### Candidate signals the hook script might see

| Signal                                         | Where it lives | Known?                                           |
| ---------------------------------------------- | -------------- | ------------------------------------------------ |
| `$CLAUDE_AGENT_ID` / `$CLAUDE_AGENT_NAME`      | Env            | Not verified — may not exist                     |
| `session_id` in hook-input JSON                | stdin          | Verified — parent + subagent may share or differ |
| `tool_use_id` / `tool_input.*`                 | stdin          | Verified to exist; content ad-hoc                |
| `transcript_path` / subagent metadata          | stdin?         | Unknown — inspect empirically                    |
| Process tree (walk up for Agent-tool ancestor) | ps             | Brittle — don't rely on it                       |

The goal of the investigation is to find any stable distinguishing
signal, add a 2–3 line guard to each hook script that `exit 0`s when
the signal indicates subagent context, and move on.

### Step-by-step investigation protocol

**Step 1: install a probe hook**

Add a PostToolUse Bash hook that dumps everything the hook can see,
to a log file. Do NOT modify the existing hooks — add a new entry in
`settings.json`. The probe is read-only; it doesn't block anything.

```json
{
  "PostToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "bash /devshop/kit/scripts/probe-hook-context.sh"
        }
      ]
    }
  ]
}
```

Create `/devshop/kit/scripts/probe-hook-context.sh` (needs sudo to place):

```bash
#!/bin/bash
# Probe: dump hook input + env to /tmp/probe-<timestamp>-<pid>.log
# for side-by-side comparison of parent-agent vs subagent contexts.
# Read-only, never blocks.
set -u
TS=$(date +%s%N)
OUT="/tmp/probe-${TS}-$$.log"
{
  echo "=== TIMESTAMP ==="
  date -Iseconds
  echo
  echo "=== PROCESS ==="
  echo "PID=$$ PPID=$PPID"
  ps -o pid,ppid,comm --ppid "$PPID" 2>/dev/null || true
  echo
  echo "=== ENV (CLAUDE_*, AGENT*, TOOL*) ==="
  env | grep -iE '^(CLAUDE|AGENT|TOOL|SESSION|SUBAGENT)' | sort || true
  echo
  echo "=== STDIN (hook input JSON) ==="
  cat
} > "$OUT" 2>&1
```

Make it executable: `sudo chmod 755 /devshop/kit/scripts/probe-hook-context.sh`.

**Step 2: collect two data points**

In the new Claude Code session, after the probe is installed:

1. **Parent-agent bash**: have Claude (top level) run any `bash` call, e.g. `git status`. One log file lands in `/tmp/probe-*`.
2. **Subagent bash**: have Claude spawn an Agent (general-purpose works) with the instruction `run 'git status' via bash and return the output`. Another log file lands in `/tmp/probe-*`.

Find the two most recent files with `ls -t /tmp/probe-*.log | head -2`.

**Step 3: diff them**

```bash
diff <(ls -t /tmp/probe-*.log | head -1 | xargs cat) <(ls -t /tmp/probe-*.log | sed -n 2p | xargs cat)
```

Anything in ENV or STDIN that differs stably between the two runs is
a candidate signal. Good candidates: env vars that are only set in one
context; JSON keys in `tool_input` that differ; `session_id` with
different values.

**Step 4: write the guard**

Once a signal is confirmed, add to the top of each hook script:

```bash
# Exit quietly if running inside a subagent — these hooks address the
# top-level agent's workflow (commits, PR lifecycle), not subagent-scoped
# tool use. Signal used: <describe what you found>.
if <condition-for-subagent>; then exit 0; fi
```

Apply to both `check-dirty-after-commit.sh` and `check-pr-description.sh`.

**Step 5: regression-test**

Run a subagent that does some bash calls — verify no hook output in
the subagent's context. Then have the parent agent do bash work that
should trigger the hooks — verify they still fire as intended.

**Step 6: remove the probe hook**

Remove the probe-hook entry from `settings.json` and delete the probe
script. Either leave the `/tmp/probe-*.log` files for debugging or
`rm -f /tmp/probe-*.log`.

### If no signal exists

Approach (b) is infeasible without a Claude Code feature request.
File it upstream as a hook-context enhancement. In the meantime:

- Apply approach (a) softening (scripts below).
- Document the limitation in `/devshop/kit/docs/guide/hooks.md`.
- Add a `kit/TODOS.md` entry to revisit when Claude Code exposes
  subagent metadata in hook inputs.

---

## Approach (a) — softened scripts (apply only if (b) fails)

Both scripts below are drop-in replacements for the current
`/devshop/kit/scripts/check-*.sh`. They **don't** fix the root
problem — hooks still fire everywhere — but they change tone so a
subagent that hits them can acknowledge and move on.

### `/devshop/kit/scripts/check-dirty-after-commit.sh` (softened)

```bash
#!/bin/bash
# PostToolUse hook: after git commit, check for remaining work.
# Two checks:
#   1. Current repo still dirty — agent should know (not a block; agent may be
#      doing WIP work and knows the state intentionally).
#   2. Other repo has uncommitted changes — commit there too (still a block;
#      cross-repo-dirty is a common footgun that's NOT usually intentional
#      unless the agent is mid-stash-dance, in which case the check is fine
#      to hit and then dismiss).
set -euo pipefail

MESSAGES=()

# --- Check 1: Current repo still dirty ---
# Soft reminder — the agent is mid-commit and knows the state. A block here
# forces a "text-only assessment" dance that's excessive for intentional WIP.
DIRTY=$(git status --porcelain 2>/dev/null | head -10 || true)
if [ -n "$DIRTY" ]; then
  DIRTY_COUNT=$(echo "$DIRTY" | grep -c . || true)
  MESSAGES+=("Note: working tree still has ${DIRTY_COUNT} uncommitted file(s) after this commit:
$DIRTY
If this is WIP, continue. Otherwise: stage + commit, stash, or add to .gitignore.")
fi

# --- Check 2: Other repo has uncommitted changes ---
# Still a block — forgetting the sibling repo is a real footgun, especially
# during devshop ↔ project cross-repo work.
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
case "$GIT_ROOT" in
  /workspace) OTHER_REPO=/devshop;  OTHER_NAME="devshop (abra-kadabra)" ;;
  /devshop)   OTHER_REPO=/workspace; OTHER_NAME="project" ;;
  *)          OTHER_REPO="" ;;
esac

if [ -n "$OTHER_REPO" ] && [ -d "$OTHER_REPO/.git" ]; then
  OTHER_DIRTY=$(git -C "$OTHER_REPO" status --porcelain 2>/dev/null | head -5 || true)
  if [ -n "$OTHER_DIRTY" ]; then
    MESSAGES+=("Cross-repo: the $OTHER_NAME repo ($OTHER_REPO) has uncommitted changes:
$OTHER_DIRTY
Commit or stash there too before moving on (forgetting this is a common footgun).")
  fi
fi

# --- Reminder: cwd may have changed after cd-ing to the other repo ---
if [ "$GIT_ROOT" != "/workspace" ]; then
  MESSAGES+=("You are in $GIT_ROOT — use 'cd /workspace' or absolute paths for project work.")
fi

[ ${#MESSAGES[@]} -eq 0 ] && exit 0

# Combine all messages and output as properly escaped JSON
COMBINED=$(printf '%s\n\n' "${MESSAGES[@]}")
jq -n --arg ctx "$COMBINED" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'
```

### `/devshop/kit/scripts/check-pr-description.sh` (softened)

```bash
#!/bin/bash
# PostToolUse hook: after git push, remind to review PR title/description
# if the push may have changed the PR scope.
#
# Changes from v1:
# 1. Dedup by HEAD SHA — don't re-fire on the same commit (push retries,
#    concurrent runs, or multiple pushes with no new commits all deduplicate).
# 2. Softer wording — the previous version used "⚠️ MANDATORY" / "You MUST" /
#    a 2-step scaffold that forced a text-only assessment dance. This one is a
#    reminder: quote the current state, say "consider updating", let the agent
#    decide whether to re-assess or skip.
# 3. Still fires on every push with new commits — scope drift is cheap to
#    catch and expensive to miss. The dedup just prevents spam on no-op pushes.
set -euo pipefail

# Read hook input — check the actual push command
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Skip branch deletions
echo "$COMMAND" | grep -q '\-\-delete' && exit 0

BRANCH=$(git branch --show-current 2>/dev/null || true)
[ -z "$BRANCH" ] && exit 0
[ "$BRANCH" = "main" ] && exit 0

# Check if there's an open PR for this branch
PR=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number // empty' 2>/dev/null || true)
[ -z "$PR" ] && exit 0

# Dedup: skip if we already fired for this HEAD SHA
HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || true)
[ -z "$HEAD_SHA" ] && exit 0
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ak"
STATE_FILE="$STATE_DIR/pr-description-hook-$PR"
mkdir -p "$STATE_DIR" 2>/dev/null || true
if [ -f "$STATE_FILE" ]; then
  LAST_SHA=$(cat "$STATE_FILE" 2>/dev/null || true)
  [ "$LAST_SHA" = "$HEAD_SHA" ] && exit 0
fi
echo "$HEAD_SHA" > "$STATE_FILE" 2>/dev/null || true

# Get current state
COMMITS=$(git log --oneline origin/main..HEAD 2>/dev/null || true)
COMMIT_COUNT=$(echo "$COMMITS" | grep -c . || true)
PR_DATA=$(gh pr view "$PR" --json title,body 2>/dev/null || true)
CURRENT_TITLE=$(echo "$PR_DATA" | jq -r '.title // empty')
CURRENT_BODY_PREVIEW=$(echo "$PR_DATA" | jq -r '.body // empty' | head -5)

# Build context with proper JSON escaping — informative reminder, not a mandate
CONTEXT=$(jq -n --arg pr "$PR" --arg branch "$BRANCH" --arg count "$COMMIT_COUNT" \
  --arg commits "$COMMITS" --arg title "$CURRENT_TITLE" --arg body "$CURRENT_BODY_PREVIEW" \
  '"Reminder: new push to PR #\($pr) (\($branch), \($count) commits). If the newest commits changed the PR''s scope, update the title and/or description before the reviewer sees it.\n\nCurrent title: \($title)\n\nCurrent description (first 5 lines):\n\($body)\n\nRecent commits:\n\($commits)\n\nIf scope is unchanged, skip. If it changed, update via `gh pr edit \($pr)`."')

# Output as PostToolUse additionalContext
jq -n --argjson ctx "$CONTEXT" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'
```

Apply with:

```
sudo cp <the-softened-content-above> /devshop/kit/scripts/check-dirty-after-commit.sh
sudo chmod 755 /devshop/kit/scripts/check-dirty-after-commit.sh
sudo chown root:root /devshop/kit/scripts/check-dirty-after-commit.sh

sudo cp <the-softened-content-above> /devshop/kit/scripts/check-pr-description.sh
sudo chmod 755 /devshop/kit/scripts/check-pr-description.sh
sudo chown root:root /devshop/kit/scripts/check-pr-description.sh
```

---

## Originals — for verification + revert

If the softening has been applied and you need to restore the
originals (to keep a PR clean of hook changes, for example):

### `/devshop/kit/scripts/check-dirty-after-commit.sh` (original)

```bash
#!/bin/bash
# PostToolUse hook: after git commit, check for remaining work.
# Two checks:
#   1. Current repo still dirty — address remaining files
#   2. Other repo has uncommitted changes — commit there too
set -euo pipefail

MESSAGES=()

# --- Check 1: Current repo still dirty ---
DIRTY=$(git status --porcelain 2>/dev/null | head -10 || true)
if [ -n "$DIRTY" ]; then
  MESSAGES+=("BLOCKING: Working tree still dirty after commit. You MUST address every remaining file BEFORE doing anything else. Remaining files:
$DIRTY
For each file: stage + commit, stash, or add to .gitignore. If you do not know what to do with a file, ask the user. Do NOT move on to other work until the tree is clean.")
fi

# --- Check 2: Other repo has uncommitted changes ---
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
case "$GIT_ROOT" in
  /workspace) OTHER_REPO=/devshop;  OTHER_NAME="devshop (abra-kadabra)" ;;
  /devshop)   OTHER_REPO=/workspace; OTHER_NAME="project" ;;
  *)          OTHER_REPO="" ;;
esac

if [ -n "$OTHER_REPO" ] && [ -d "$OTHER_REPO/.git" ]; then
  OTHER_DIRTY=$(git -C "$OTHER_REPO" status --porcelain 2>/dev/null | head -5 || true)
  if [ -n "$OTHER_DIRTY" ]; then
    MESSAGES+=("BLOCKING: The $OTHER_NAME repo ($OTHER_REPO) still has uncommitted changes:
$OTHER_DIRTY
You MUST commit or address these files BEFORE doing anything else. If you do not know what to do, ask the user.")
  fi
fi

# --- Reminder: cwd may have changed after cd-ing to the other repo ---
if [ "$GIT_ROOT" != "/workspace" ]; then
  MESSAGES+=("You are in $GIT_ROOT — use 'cd /workspace' or absolute paths for project work.")
fi

[ ${#MESSAGES[@]} -eq 0 ] && exit 0

# Combine all messages and output as properly escaped JSON
COMBINED=$(printf '%s\n\n' "${MESSAGES[@]}")
jq -n --arg ctx "$COMBINED" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'
```

### `/devshop/kit/scripts/check-pr-description.sh` (original)

```bash
#!/bin/bash
# PostToolUse hook: after git push, prompt Claude to review PR title/description.
# Fires once per push. No output if on main, no open PR, or non-PR pushes.
set -euo pipefail

# Read hook input — check the actual push command
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Skip branch deletions
echo "$COMMAND" | grep -q '\-\-delete' && exit 0

BRANCH=$(git branch --show-current 2>/dev/null || true)
[ -z "$BRANCH" ] && exit 0
[ "$BRANCH" = "main" ] && exit 0

# Check if there's an open PR for this branch
PR=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number // empty' 2>/dev/null || true)
[ -z "$PR" ] && exit 0

# Get current state
COMMITS=$(git log --oneline origin/main..HEAD 2>/dev/null || true)
COMMIT_COUNT=$(echo "$COMMITS" | grep -c . || true)
PR_DATA=$(gh pr view "$PR" --json title,body 2>/dev/null || true)
CURRENT_TITLE=$(echo "$PR_DATA" | jq -r '.title // empty')
CURRENT_BODY_PREVIEW=$(echo "$PR_DATA" | jq -r '.body // empty' | head -5)

# Build context with proper JSON escaping
CONTEXT=$(jq -n --arg pr "$PR" --arg branch "$BRANCH" --arg count "$COMMIT_COUNT" \
  --arg commits "$COMMITS" --arg title "$CURRENT_TITLE" --arg body "$CURRENT_BODY_PREVIEW" \
  '"⚠️ MANDATORY: Review PR #\($pr) title and description NOW before doing anything else.\n\nBranch: \($branch) (\($count) commits)\n\nCommits:\n\($commits)\n\nCurrent title: \($title)\nCurrent description (first 5 lines):\n\($body)\n\nThis is a TWO-STEP process. You MUST complete Step 1 before Step 2.\n\n## Step 1: ASSESS (text output only — NO tool calls)\n\nTell the user what needs changing and why. For each of title and description:\n- Quote the current version\n- Compare against the full commit history above\n- State: \"needs update because...\" or \"no change needed because...\"\n\n⚠️ DO NOT call gh pr edit or any other tool in the same response as Step 1. Output text ONLY. Wait for the user to see your assessment.\n\n## Step 2: UPDATE (after user has seen Step 1)\n\nIn your NEXT response, run `gh pr edit \($pr)` commands as needed.\n- Title update: tell user \"Title: old → new\"\n- Description update: tell user what changed\n- No change: skip the command\n\nDo NOT combine Steps 1 and 2 into one response. Do NOT run gh pr edit without showing the assessment first."')

# Output as PostToolUse additionalContext
jq -n --argjson ctx "$CONTEXT" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'
```

### Revert path (if you find the softening applied)

The new session should start from a clean devshop tree (originals
restored). If the softening is present, restore originals:

```
# Extract HEAD versions to /tmp
git -C /devshop show HEAD:kit/scripts/check-dirty-after-commit.sh > /tmp/check-dirty-after-commit.original.sh
git -C /devshop show HEAD:kit/scripts/check-pr-description.sh > /tmp/check-pr-description.original.sh

# Apply as root (user must run these)
sudo cp /tmp/check-dirty-after-commit.original.sh /devshop/kit/scripts/check-dirty-after-commit.sh
sudo chmod 755 /devshop/kit/scripts/check-dirty-after-commit.sh
sudo chown root:root /devshop/kit/scripts/check-dirty-after-commit.sh

sudo cp /tmp/check-pr-description.original.sh /devshop/kit/scripts/check-pr-description.sh
sudo chmod 755 /devshop/kit/scripts/check-pr-description.sh
sudo chown root:root /devshop/kit/scripts/check-pr-description.sh

# Verify
git -C /devshop status --short kit/scripts/
# Should be empty — tree clean on the scripts
```

---

## What a successful session looks like

When we're done, we want **one** of these outcomes in the devshop repo:

**Outcome 1 (preferred — approach (b) worked):**

- New commit on a new devshop branch (e.g. `feature/hook-subagent-scope`).
- Touches: both `check-*.sh` scripts (gain a 2–3 line subagent guard at the top), `kit/docs/guide/hooks.md` (document the guard + the signal used), possibly `kit/docs/FAQ.md` (if the signal surface is worth explaining there).
- No changes to the actual hook LOGIC — just a guard that exits early in subagent context.
- Probe hook + script removed from `settings.json` + the filesystem.

**Outcome 2 (fallback — approach (b) infeasible):**

- New commit on a new devshop branch applying the **softened scripts** (content above).
- Touches: both `check-*.sh` scripts, `kit/docs/guide/hooks.md` (note the softened wording + rationale + dedup semantics), `kit/TODOS.md` (add an entry to revisit once Claude Code exposes subagent metadata).
- Reference this file (`kit/notes/subagent-hook-scope.md`) from the commit message.

In both cases: verify the parent-agent path still works (hook still fires on a real dirty-tree commit), and the subagent path is now clean (no more interference).

---

## Files referenced

All absolute paths from the container:

| Path                                               | What                                                                                               |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `/devshop/kit/scripts/check-dirty-after-commit.sh` | The dirty-tree hook — subject of the bug                                                           |
| `/devshop/kit/scripts/check-pr-description.sh`     | The PR-review hook — subject of the bug                                                            |
| `/devshop/.claude/settings.json`                   | Where the hooks are registered (root-owned + write-denied)                                         |
| `/devshop/kit/docs/guide/hooks.md`                 | Operational reference for hooks — will need a docs update whichever approach lands                 |
| `/devshop/kit/docs/guide/workflow.md`              | Currently has the `/ak-pre-ship` phase description — no change expected                            |
| `/devshop/kit/TODOS.md`                            | Devshop tactical backlog — may add upstream/hook-scope items                                       |
| `/devshop/kit/notes/phase-1-next-steps.md`         | Forward-looking handoff for PR 3 + beyond (pointer only; no need to load to continue this session) |

---

## Why this is a separate session

PR 2's devshop-side work (`feature/pre-ship-hardening`) is a coherent
unit: preflight, blocked outcome, screenshot convention, Chromium
symlink, template Dockerfile, TODOs. Adding hook-script behavior
changes on top expands the scope and mixes unrelated concerns.
Separating it gives:

- A clean PR 2 hardening PR that reviewers can evaluate on
  pre-ship-gate quality alone.
- A clean follow-up PR for hook scope with its own reviewer.
- A focused session that isn't juggling two different problems
  (product shipping + devshop plumbing).

---

## Session kickoff prompt (copy-paste)

Here's a prompt for a fresh Claude Code session. Paste the whole
thing:

> I want you to implement the subagent-hook-scope fix described in
> `/devshop/kit/notes/subagent-hook-scope.md`. Read that file first — it
> is self-contained and tells you exactly what to do.
>
> Start by reading the file. Then:
>
> 1. If the softened hooks are currently applied (tree dirty in
>    `/devshop/kit/scripts/`), restore the originals per the revert
>    path in the doc.
> 2. Install the probe hook (step 1 of investigation protocol).
>    The probe requires sudo placement — I'll run sudo commands
>    when you hand them to me.
> 3. Collect the two data points (parent-agent vs subagent).
> 4. Diff them and tell me what distinguishing signal you see.
> 5. Based on that, pick Outcome 1 or Outcome 2 and implement it.
>
> Confirm you've read the doc before starting, and quote the TL;DR
> so I know we're on the same page.
