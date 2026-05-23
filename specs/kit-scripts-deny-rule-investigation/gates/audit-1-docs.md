### [domain: docs] [section: B] [severity: high]
**File**: kit/docs/guide/security.md:52
**What**: Docs assert deny rules use only absolute-path patterns, but settings.json still has relative patterns
**Why**: Mis-described security boundary — operator reading the docs would believe relative deny patterns (`Edit(kit/scripts/**)`, `Write(kit/scripts/**)`) were removed and worktree edits are fully unblocked, but the relative patterns are still present in `.claude/settings.json` lines 79-82. The "Worktree copies are intentionally editable" paragraph and the code-block example both claim only two absolute-path lines exist; four lines actually exist.
**Fix**: Either (a) remove the two relative-path deny lines from settings.json to match the docs, or (b) update security.md, CLAUDE.md, and the "Authoring locked files" section to document all four deny lines and explain the relative+absolute dual coverage.

### [domain: docs] [section: B] [severity: high]
**File**: CLAUDE.md:119
**What**: Known Footguns entry for denied paths lists `/devshop/kit/scripts/**` with "(canonical tree only -- worktree copies are intentionally editable)" but the relative deny patterns `Edit(kit/scripts/**)` / `Write(kit/scripts/**)` still fire on worktree paths
**Why**: Same root cause as above — the relative patterns `kit/scripts/**` match ANY path containing that segment, including worktree copies at `.worktrees/<topic>/kit/scripts/`. The claim that worktree copies are "intentionally editable" is contradicted by the actual settings.json deny rules.
**Fix**: Sync with the security.md fix — either remove the relative patterns from settings.json or correct the prose in both files.
