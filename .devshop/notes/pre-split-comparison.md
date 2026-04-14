# Comparing Against Pre-Split Devshop State

## Context

On 2026-04-13, the devshop infrastructure was separated from the lalista project repo (`chore/separate-devshop`). The tag `pre-split-snapshot` lives in the **lalista repo** (`/workspace`) on the commit where `main` bifurcated into `chore/separate-devshop` (`24652cf`). It marks the last state where devshop files lived inside the project repo.

## When to use

If something breaks after the split and you suspect a devshop file was lost, changed, or misconfigured during the separation.

## How to compare

The pre-split devshop files are in the lalista repo at the tag. The current devshop files are in the devshop repo (`/devshop`).

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

## Instructions for Claude

If the user says "compare against pre-split", "check what changed since the separation", or similar:

1. Run `cd /workspace && git ls-tree -r --name-only pre-split-snapshot -- .devshop/ .claude/` to list pre-split files
2. Compare specific files with `diff <(git -C /workspace show pre-split-snapshot:<path>) /devshop/<path>`
3. The tag `pre-split-snapshot` is in the **lalista repo**, not the devshop repo
