---
name: ak-sync-from-devshop
version: 1.0.0
description: |
  Sync build tooling from the devshop and apply propagation steps.
  Shows version range, runs from-devshop.sh, summarizes file changes,
  presents propagation items for the version range, and offers to commit.
  Use when asked to "sync from devshop", "update from devshop", "run from-devshop",
  or when the session briefing shows a Sync drift warning. (devshop)
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - AskUserQuestion
  - Agent
---

# Sync from Devshop

Pull build tooling updates from the devshop into the current project.

## Phase 1 — Pre-flight

### 1a. Dirty working tree check

```bash
git status --porcelain | head -5
```

If there are uncommitted changes, stop and ask the user:

> You have uncommitted changes. Sync will modify files and make the diff hard to review. Stash first, continue anyway, or abort?

Options: `Stash and continue` / `Continue anyway` / `Abort`

If they choose stash: `git stash push -m "pre-sync stash"` and note it so you can remind them to pop after commit.

### 1b. Version detection

Read both versions:

```bash
cat /devshop/kit/version 2>/dev/null | tr -d '[:space:]'
cat .devshop-version 2>/dev/null | tr -d '[:space:]'
```

Three cases:

| Case                | Old version      | Display                                                                                                                                                                                                          |
| ------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **First sync**      | file missing     | `First sync → v{new}`                                                                                                                                                                                            |
| **Upgrade**         | differs from new | `v{old} → v{new}`                                                                                                                                                                                                |
| **Already current** | matches new      | Print `Already synced to v{current}. Nothing to do.` and **skip to Phase 3** (propagation review only, in case previous propagation items were not applied). If user says no propagation to review either, exit. |

Print the version line:

```
Devshop sync: v1.33.0 → v1.35.0
```

or:

```
Devshop sync: first sync → v1.35.0
```

## Phase 2 — Run sync

Run the sync script with `--yes` (no interactive prompt — the skill handles confirmation):

```bash
bash .devshopkit/scripts/sync/from-devshop.sh --yes 2>&1
```

After the script completes, capture the diff summary:

```bash
git diff --stat
```

If no files changed, say so and skip to Phase 3.

If files changed, show a summary table:

```
### Sync complete — v1.33.0 → v1.35.0

| File | Change |
|---|---|
| .devcontainer/README.md | modified (−280/+42) |
| .github/workflows/ci.yml | modified (−3/+11) |
| .gitignore | modified (−1/+0) |

3 files changed
```

Use `git diff --numstat` to get the +/− numbers.

### 2b. Check if package.json changed

```bash
git diff --name-only | grep -q "^package.json$"
```

If `package.json` was modified, run `pnpm install` and note the lockfile update in the summary.

### 2c. Devcontainer rebuild verdict

`from-devshop.sh` ends every run with a rebuild verdict. The `[locked]`
`.devcontainer/` leaves (`Dockerfile`, `devcontainer.json`, `init-firewall.sh`,
the init scripts, `compose.yml`, …) are **excluded from the sync rsync** —
`init-devshop.sh` owns them, refreshing each from `/devshop/template` on every
container start — so they never appear in the `git diff --stat` from Phase 2.
The script content-diffs the project's in-tree copies against the template and
prints one of:

- **drift** → a `Rebuild needed — .devcontainer changed (N file(s)):` block
  listing the differing leaves, or
- **clean** → `No .devcontainer changes — container rebuild not needed.`

The verdict fires even when Phase 2 reported no synced-file changes — a
locked-only devshop release (e.g. a Dockerfile or firewall bump) shows "No
changes to apply" for the synced tooling yet still needs a rebuild.

**Surface the verdict in the skill output.** Pass it through verbatim and, on
drift, raise it to a `☐` checklist item the operator must act on:

```
### Rebuild — required

  ☐ Rebuild the devcontainer to apply .devcontainer changes:
      Dockerfile, init-firewall.sh
    VS Code → Cmd/Ctrl+Shift+P → "Dev Containers: Rebuild Container".
    Image files (Dockerfile, devcontainer.json, compose.yml) strictly require a
    rebuild; init scripts also refresh on any container start.
```

On a clean verdict, show the one-line `✓ No .devcontainer changes — rebuild not
needed.` so the operator is never left guessing whether the check ran.

## Phase 3 — Propagation review

Read PROPAGATION.md and extract entries for the version range:

```bash
cat /devshop/kit/docs/PROPAGATION.md
```

### Parse relevant entries

- **First sync (no old version):** show ALL entries in PROPAGATION.md.
- **Upgrade:** show entries for versions > old and <= new. Parse `## v{x.y.z}` headers and filter by semver.
- **Already current:** show all entries (they may have been skipped last time). Say "These may already be applied — showing for review."

### Classify each bullet

Read each propagation bullet and classify it:

| Type                         | Detection                                                                   | Action                                |
| ---------------------------- | --------------------------------------------------------------------------- | ------------------------------------- |
| **No action needed**         | Contains "no migration needed", "no project-side migration", "devshop-only" | Show with ✓ prefix, skip              |
| **Automatable audit**        | Contains "audit", "verify", "check", "cross-reference"                      | Offer to run it                       |
| **Manual — GitHub Variable** | Contains "GitHub Variable", "GitHub Secret"                                 | Show as manual checklist item         |
| **Manual — other**           | Anything requiring external dashboard, host-side action                     | Show as manual checklist item         |
| **File copy**                | Contains "copy", "scaffold-once"                                            | Check if already present, show status |

### Present propagation

Show a formatted list grouped by version:

```
### Propagation — v1.34.0

  ✓ feat(conventions): require Existing projects block — no action needed (devshop-only)
  ✓ feat(template): rich PLAN.md schema — already present in project
  ✓ feat(sync): preview changes — no action needed (scripts via symlink)
  ✓ feat(ak-build): devshop mode — no action needed (devshop-only)
  ◐ feat(template): keepalive pings — check: does keepalive.yml exist and match template?
  ✓ chore(build-log): tracker entries — no action needed (devshop-only)
  ◐ feat(devcontainer): Supabase CLI checksums — check: does Dockerfile have checksum verification?
  ✓ feat(sync): version drift reminder — no action needed (auto via session-start)
  ✓ feat(sync): auto-generate propagation log — no action needed (auto)
  ◐ fix(sync): SUPABASE_PROD_ANON_KEY — manual: add GitHub Variable if missing

### Propagation — v1.35.0

  ◐ docs(migrations): explicit GRANT requirement — audit: check all CREATE TABLE migrations have GRANT
```

For items marked ◐ (automatable audits), ask the user:

> Want me to run the automatable checks? (audit migrations for GRANTs, verify keepalive.yml matches template, etc.)

If yes, run each audit and report results. For each audit:

1. Run the check (grep, diff, file existence)
2. Report pass/fail with specifics
3. If a fix is needed and automatable, offer to apply it

For manual items, just list them as a checklist the user can act on outside the session.

### Show propagation summary

After audits complete:

```
### Propagation summary

  ✓ 8 items — no action needed
  ✓ 3 audits — all passed
  ☐ 1 manual item remaining:
    - Add SUPABASE_PROD_ANON_KEY as GitHub Variable (if not already set)
```

## Phase 4 — Commit

If there are file changes from Phase 2, ask:

> Ready to commit the sync? (3 files changed)

Options: `Commit` / `Skip`

If commit:

- Build the commit message with version range:
  - Upgrade: `chore: sync from devshop v1.33.0 → v1.35.0`
  - First sync: `chore: sync from devshop (first sync, v1.35.0)`
- Stage all changed files: `git add -A`
- Commit with the message
- If a pre-sync stash was created in Phase 1a, remind: `Note: you have a pre-sync stash — run git stash pop when ready.`
- If Phase 2c reported drift, **repeat the rebuild reminder as the last line** of the commit handoff (`☐ Rebuild the devcontainer …`) — it's the operator's next action after committing, and burying it above the commit step means they scroll past it. A locked-only release can reach Phase 4 with nothing to commit (Phase 2 found no synced changes); in that case skip the commit prompt but still surface the rebuild reminder.

If skip: remind them the working tree has unstaged sync changes.

## Output conventions

- No emoji in prose (use ✓ ◐ ☐ for status only).
- Keep tables compact.
- Don't editorialize — state facts about what changed and what needs attention.
