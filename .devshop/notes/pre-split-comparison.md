# Comparing Against Pre-Split Devshop State

## Context

On 2026-04-13, the devshop infrastructure was separated from the lalista project repo (`chore/separate-devshop`). The tag `pre-split-snapshot` marks the devshop state just before that branch merged.

## When to use

If something breaks after the split and you suspect a devshop file was lost, changed, or misconfigured during the separation.

## How to compare

```bash
# Full diff since the split
cd /devshop && git diff pre-split-snapshot..HEAD

# Changed files only
cd /devshop && git diff pre-split-snapshot..HEAD --name-status

# Check a specific file
cd /devshop && git diff pre-split-snapshot..HEAD -- .devshop/path/to/file

# View a file as it was before the split
cd /devshop && git show pre-split-snapshot:.devshop/path/to/file
```

## Instructions for Claude

If the user says "compare against pre-split", "check what changed since the separation", or similar:

1. Run `cd /devshop && git diff pre-split-snapshot..HEAD --name-status` to see what changed
2. Drill into specific files as needed
3. The tag `pre-split-snapshot` is the anchor — everything before it is the pre-split state
