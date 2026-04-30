---
description: Write a handoff doc so the next session with fresh context can continue this work. Use when context is full or asked to "handoff", "continue in a new session", "let's start fresh".
argument-hint: [name]
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

Write a comprehensive handoff document so a fresh-context Claude session can pick up exactly where this one left off, then print a brightly-formatted bootstrap message for the user.

This command does NOT enter plan mode, clear context, or create a new session — those actions are the user's. It only writes the doc and tells the user what to do next.

Optional argument (`$ARGUMENTS`) is the handoff name. If empty, auto-pick from session content.

## Steps

### 1. Detect the active session

Read the active session's JSONL to extract: session ID, slug, AI title, existing custom title, current permission mode, and current git branch.

```bash
CWD_SLUG="$(pwd | sed 's|/|-|g')"
PROJECT_DIR="$HOME/.claude/projects/$CWD_SLUG"
SESSION_JSONL="$(ls -t "$PROJECT_DIR"/*.jsonl 2>/dev/null | head -1)"

if [ -z "$SESSION_JSONL" ] || [ ! -f "$SESSION_JSONL" ]; then
  echo "ERROR: could not locate active session JSONL under $PROJECT_DIR" >&2
  exit 1
fi

SESSION_ID="$(basename "$SESSION_JSONL" .jsonl)"
SLUG="$(grep -o '"slug":"[^"]*"' "$SESSION_JSONL" | head -1 | sed 's/"slug":"//;s/"$//')"
AI_TITLE="$(grep -o '"aiTitle":"[^"]*"' "$SESSION_JSONL" | tail -1 | sed 's/"aiTitle":"//;s/"$//')"
CUSTOM_TITLE="$(grep -o '"customTitle":"[^"]*"' "$SESSION_JSONL" | tail -1 | sed 's/"customTitle":"//;s/"$//')"
PERM_MODE="$(grep -o '"permissionMode":"[^"]*"' "$SESSION_JSONL" | tail -1 | sed 's/"permissionMode":"//;s/"$//')"
PERM_MODE="${PERM_MODE:-default}"
```

If the slug is empty (very-new session, no records yet), fall back to the session ID's first 8 chars.

### 2. Pick the handoff name (no user confirmation)

Pick a single name to use both for the handoff filename AND for the `/rename` copy-paste line at the end. Use this priority order — first match wins, no asking the user:

1. **Command argument** — if `$ARGUMENTS` is non-empty (e.g. `/ak-handoff zod-validation`), sanitize it to `[a-z0-9-]` and use it.
2. **Existing custom title** — else if `$CUSTOM_TITLE` is set (user already ran `/rename`), use it as-is.
3. **Generated from session content** — else propose a name based on what the session has been about. Read the most recent user prompts and the AI title from `$SESSION_JSONL`, plus any active spec / branch name, and produce a short hyphenated slug (lowercase, alnum + dashes, ≤ 40 chars) that reflects the actual work. Drop filler words. Examples:
   - `aiTitle = "Design /ak-handoff command for context continuation"` → `ak-handoff-skill`
   - User has been debugging zod validation in `apps/web/.../sign-in.test.ts` → `zod-signin-validation`
   - Branch is `feature/realtime-cleanup` and recent prompts touch realtime → `realtime-cleanup`
   - Nothing distinguishing → fall back to `$SLUG`

Save the chosen value as `HANDOFF_NAME`. The command does NOT rename the session itself — that's a manual `/rename` copy-paste shown at the end.

Also compute `CONTINUATION_NAME` — the name for the next session. If `HANDOFF_NAME` already ends in `__continuation_<N>`, increment N. Otherwise append `__continuation_1`:

```bash
if echo "$HANDOFF_NAME" | grep -qE '__continuation_[0-9]+$'; then
  CURRENT_N=$(echo "$HANDOFF_NAME" | grep -oE '[0-9]+$')
  BASE=$(echo "$HANDOFF_NAME" | sed 's/__continuation_[0-9]*$//')
  CONTINUATION_NAME="${BASE}__continuation_$((CURRENT_N + 1))"
else
  CONTINUATION_NAME="${HANDOFF_NAME}__continuation_1"
fi
```

```bash
mkdir -p .handoff
HANDOFF_FILE=".handoff/${HANDOFF_NAME}.md"
rm -f "$HANDOFF_FILE"
```

Always overwrite — the handoff is a snapshot of "where to continue from now," not a history. If the user wants history, git tracks it.

If `.handoff/` is not in `.gitignore`, do NOT add it automatically — leave that decision to the user. Mention it in the closing message if it isn't ignored.

### 3. Gather context for the doc

Pull state that wouldn't be obvious from a bare git checkout:

```bash
git status --short
git log --oneline -10
git branch --show-current
git stash list
ls specs/*/spec.md 2>/dev/null
```

Also re-read any active feature spec, recent BUILD-LOG entries, and the user's last few prompts in this session (from `$SESSION_JSONL`) to anchor the "Goal" section in the user's actual words.

### 4. Write the handoff document

Write `$HANDOFF_FILE` with this structure. Lead with everything the next agent needs to act, then provide the references it needs to dig deeper.

```markdown
# Handoff — <AI_TITLE or SLUG>

> Continuing from session `<SESSION_ID>` (slug: `<SLUG>`).
> Old transcript: `<SESSION_JSONL>` — read this if you need detail beyond what's below.

## Goal

<one-paragraph statement of what the user is trying to accomplish, in the user's framing>

## Status

- Branch: `<branch>` (clean | <N files modified>)
- Recent commits: <one line each, last 5>
- Open specs / WIP files: <list, or "none">

## Progress

<bullet list of what's been done in this session — concrete actions, files touched, decisions made>

## What worked

<approaches the user accepted or that succeeded — keep these so the next agent doesn't relitigate>

## What didn't work

<approaches the user rejected, dead ends, or things that failed — keep these so the next agent doesn't repeat them>

## Open questions

<anything ambiguous that the next agent should ask the user about before proceeding. If none, write "None — proceed with Next steps.">

## Next steps

<numbered list of concrete next actions, in priority order>

## Session metadata (for the next agent)

- Old session permission mode: `<PERM_MODE>` — user may want to restore this (see bootstrap message).
- Old session slug: `<SLUG>`
- Old session AI title: `<AI_TITLE>`
```

Be comprehensive. The next agent has zero context — it can only read this file and the project on disk. Anything in this session that influenced a decision and isn't visible in the code should land in **What worked** / **What didn't work** / **Open questions**.

### 5. Print the bootstrap message

After writing the file, output this exact text-to-user (Claude Code renders CommonMark — bold + emoji + blank-line spacing is what gives it the "bright" feel; do NOT emit raw ANSI escapes, they would render as literal characters). Substitute the bracketed values.

```
---

## ✅ Handoff written to `.handoff/<HANDOFF_NAME>.md`

---

### 🚀 Start the next session

Paste this in a new terminal — it opens a new Claude session named `<CONTINUATION_NAME>` and seeds it with the read-and-question prompt:

```

claude -n <CONTINUATION_NAME> "Read .handoff/<HANDOFF_NAME>.md. If anything is unclear, ask. Then list the pending next steps and wait for my go-ahead before starting."

```

### ⚠️ Restore your prior mode

Old session was in **`<PERM_MODE>`** mode. To restore it in the new session:

- **`default`** → no action needed
- **`acceptEdits`** → press **shift-tab** once
- **`auto`** → press **shift-tab** until you reach Auto mode
- **`bypassPermissions`** → run **`/yolo`** (only if you trust this session)
- **`plan`** → press **shift-tab** to enter Plan mode

### 🔁 If the new agent asks something you can't answer

Paste the question back into **THIS** session — I still have the full context and can answer. Then paste my answer into the new session.

### 🏷️ Rename this session for `/resume`

Run this in **THIS** session so it shows up clearly in `/resume` later:

```

/rename <HANDOFF_NAME>

```

---
```

(Only render the bullet line that matches `<PERM_MODE>` — drop the others. Substitute `<HANDOFF_NAME>` literally — it's the same name used for `.handoff/<HANDOFF_NAME>.md`.)

If `.handoff/` is not in `.gitignore`, append a single dim-italic line below the closing rule:

```
> _Tip: `.handoff/` is not gitignored — add it if you don't want handoffs committed._
```

### 6. Stop

Do not enter plan mode, do not clear context, do not start anything else. The user drives the new session manually.

## Notes on what this command cannot do

- **Cannot rename the session programmatically.** Sessions auto-name from `aiTitle`. If the user wants a custom name, they run `/rename` themselves.
- **Cannot enter plan mode programmatically.** Commands don't have that API. The user shift-tabs into plan mode if they want it.
- **Cannot fork the session.** Plan-mode "clear context and continue" overwrites the current session rather than forking. To preserve the original session as a separate `/resume` entry, the user starts the new session in a fresh terminal — that's what the bootstrap message instructs.
- **Cannot restore the prior permission mode programmatically.** It's reported in the bootstrap message so the user can re-enable it manually.
