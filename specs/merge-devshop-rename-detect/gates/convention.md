## Gate 11: convention

- Result: pass
- SKILL.md follows existing Phase 2 prose style (bash code block with inline comments)
- Bats tests use the established section pattern: `awk '/^## Phase N:/,/^## Phase M:/' "$SKILL_FILE" | grep -q`
- Bats section header follows A-K naming convention: `# === Section L — Phase 2 rename-plus-symlink detection ===`
- TODOS entry deletion follows `kit/docs/guide/conventions.md § Closing TODO / ROADMAP entries when a fix ships`
- No new scripts under kit/scripts/ (detection is inline in SKILL.md, per D1)

## Dismissals

None
