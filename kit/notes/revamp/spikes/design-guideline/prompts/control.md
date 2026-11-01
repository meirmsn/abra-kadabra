You are a builder session making a UI change in the project at <scratch>/control-1 (a static site:
index.html, base.css, theme.js, and the project's files beside them). You may read anything and
edit files only inside that directory. Commit nothing. Run no gstack command and no design
review in this run; skip the stack-homes step (none apply).

Before writing, follow this section of the devshop's build skill, quoted verbatim. Where it says
/opt/devshop-current/guidelines/, use <scratch>/main/runtime/guidelines/ (the guidelines for this run); where it says
/opt/devshop-current/templates/ui/, the project already has its baseline.

## 2. Load what applies, nothing else

- **The project:** its `CLAUDE.md` and the docs its map (`docs/README.md`) links for what you touch.
- **Stack homes:** run `/opt/devshop-current/scripts/stack-homes.sh <project root>` and read each
  file it prints. Its `STACKS:` line goes in the PR's engineering details.
- **Disciplines:** each one touched (frontend, backend, data, UI, security…): its guideline in
  `/opt/devshop-current/guidelines/` if any; a UI with no baseline: `/opt/devshop-current/templates/ui/`.
- On conflict the project wins; say so in the PR.
- **CI:** none yet? Start from `/opt/devshop-current/templates/ci.yml`; declare
  `scripts/check-fast.sh` (unit) and `scripts/check-slow.sh` (end to end).

The task:

Add a section "Monthly totals" to index.html, after the "Summary" grid and before the form card:
its heading in the project's display typeface, one sentence of body text, and one highlighted
figure, the number 1,284, in the project's colour for figures that matter. Styles go in base.css or
in a new file linked from the page. The page must still pass the project's token and render checks
(every colour through a token defined for light and dark).

When done, reply with exactly two parts and nothing else:
1. "FILES READ, IN ORDER:" a numbered list of every file you read (with the Read tool or a shell
   command), in the order you read them, with a line "-- first edit --" at the point where you
   made your first edit to any file.
2. "DIFF:" the verbatim output of: git -C <scratch>/control-1 diff
