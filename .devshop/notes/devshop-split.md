# Devshop Split Notes

Audit of the `chore/separate-devshop` branch (2026-04-13). Devshop infrastructure was separated from the lalista project repo into its own repo (abra-kadabra), symlinked back at container start.

## Result

No project content was lost. Everything deleted from the project repo exists in the devshop repo at `/devshop/` and gets symlinked back by `init-devshop.sh`.

## What Changed

| Area                          | Old (main)                                | New (branch)                                                        | Status                                                                  |
| ----------------------------- | ----------------------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `CLAUDE.md`                   | Tracked file, synced manually             | Generated at container start from devshop + `CLAUDE.project.md`     | Improved (more content)                                                 |
| `settings.json`               | Tracked in project                        | Symlink to devshop                                                  | Added `/devshop/**` permissions, broader hook patterns (`*git*commit*`) |
| `init-devshop.sh`             | Security hardening inline                 | Thin forwarder → devshop version                                    | All hardening preserved + expanded                                      |
| `pre-commit` hook             | Called `devshop-commit-guard.sh` directly | Recreates symlinks if missing, calls `.hooks/pre-commit` (injected) | Added `check-claude-md-freshness.sh`                                    |
| PreToolUse `check-clean-tree` | Hook in `settings.json`                   | Moved to `.hooks/pre-commit` (husky)                                | More reliable blocking point                                            |
| Memory setup                  | `postCreateCommand` in devcontainer.json  | `init-devshop.sh`                                                   | Same result, runs on every start                                        |
| `.dcg.toml`                   | Tracked file                              | Symlink to devshop (gitignored)                                     | Identical content                                                       |
| `.gstack/`                    | Tracked                                   | Still tracked, unchanged                                            | No diff                                                                 |

## Known Issues

1. **`.claude/README.md` symlink missing** — `init-devshop.sh` should create it but doesn't on current container. Low impact.
2. **gstack directory won't symlink** — workspace has a standalone gstack git clone; `ln -sfn` can't replace a real directory. Both copies currently generate identical SKILL.md files, but devshop updates won't propagate until the workspace clone is removed.
3. **Project-specific notes in devshop repo** — `setup-supabase.md`, `sign-in-with-apple.md`, `bootstrap/*` are lalista-specific but now live in the shared devshop repo.

## Comparing Against Pre-Split State

On 2026-04-13, the tag `pre-split-snapshot` was created in the **lalista repo** (`/workspace`) on commit `24652cf` — the last state where devshop files lived inside the project repo.

### When to use

If something breaks after the split and you suspect a devshop file was lost, changed, or misconfigured during the separation.

### How to compare

```bash
# View a devshop file as it was before the split (from lalista repo)
cd /workspace && git show pre-split-snapshot:.devshop/path/to/file

# List all devshop files that existed before the split
cd /workspace && git ls-tree -r --name-only pre-split-snapshot -- .devshop/ .claude/

# Compare a specific file: pre-split (lalista) vs current (devshop)
diff <(cd /workspace && git show pre-split-snapshot:.devshop/path/to/file) /devshop/.devshop/path/to/file

# List all pre-split devshop files and check which exist in the new repo
cd /workspace && git ls-tree -r --name-only pre-split-snapshot -- .devshop/ | while read f; do
  [ -f "/devshop/$f" ] && echo "✓ $f" || echo "✗ $f (missing)"
done
```

### Instructions for Claude

If the user says "compare against pre-split", "check what changed since the separation", or similar:

1. Run `cd /workspace && git ls-tree -r --name-only pre-split-snapshot -- .devshop/ .claude/` to list pre-split files
2. Compare specific files with `diff <(git -C /workspace show pre-split-snapshot:<path>) /devshop/<path>`
3. The tag `pre-split-snapshot` is in the **lalista repo**, not the devshop repo
