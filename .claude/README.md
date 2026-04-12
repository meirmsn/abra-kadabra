# .claude/

This directory contains Claude Code configuration for this project.

## Files

### `settings.json`

Team-wide Claude Code configuration, committed to git and shared across all developers.

**Permissions:**

- Denies Claude from reading or writing sensitive files (`.env*`, credentials, private keys, certificates)
- The deny list is enforced at the tool level — even if a parent folder is explicitly referenced in a prompt, denied files will be excluded

### `settings.local.json`

Personal overrides — automatically gitignored by Claude Code when created. Use this for individual preferences that shouldn't be shared with the team.

### `commands/`

Custom slash commands available in Claude Code sessions. Add a Markdown file in each to create a new command.

| File                 | Command   | Purpose                                  |
| -------------------- | --------- | ---------------------------------------- |
| `commands/review.md` | `/review` | Code review against team standards       |
| `commands/pr.md`     | `/pr`     | Generate a PR description in team format |
| `commands/debug.md`  | `/debug`  | Structured debugging prompt              |

## Notes

- Add an `allow` whitelist in `settings.json` to restrict Claude to only `npm run *`, `git *`, and `npx *` bash commands if tighter control is needed
  - This prevents Claude from running arbitrary bash commands outside your expected toolchain
  - "allow": ["Bash(npm run *)", "Bash(git *)", "Bash(npx *)"],
- Hooks for auto-running Prettier and ESLint on file write are intentionally omitted — VS Code extensions handle this on save
  // Not sure if this is needed (test whether prettier and eslint run automatically by vs code extensions when claude applies changes)
  // "hooks": {
  // "PostToolUse": [
  // {
  // "matcher": "Write|Edit|MultiEdit",
  // "hooks": [
  // {
  // "type": "command",
  // "command": "cd \"$CLAUDE_PROJECT_DIR\" && npx prettier --write \"$CLAUDE_TOOL_INPUT_FILE_PATH\" 2>/dev/null || true"
  // },
  // {
  // "type": "command",
  // "command": "cd \"$CLAUDE_PROJECT_DIR\" && npx eslint --fix \"$CLAUDE_TOOL_INPUT_FILE_PATH\" 2>/dev/null || true"
  // }
  // ]
  // }
  // ]
  // }
- Environment variable documentation lives in `.env.example` at the project root
