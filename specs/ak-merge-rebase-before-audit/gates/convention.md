## Gate 11: convention

- Result: pass

Devshop convention check:

- SKILL.md frontmatter intact (`name: ak-merge-devshop`, description, allowed-tools).
- No new scripts under `kit/scripts/` → no new bats-for-scripts requirement.
  The changed bats file (`util-ak-merge-devshop.bats`) already covers the skill.
- Guide-doc routing unaffected (no new guide doc; `workflow.md` already indexed).
- Markdown-only + bats diff; no shell-script structure changes.
- Commit + PR text style: feature-branch commits use observable-change subjects
  (`fix(ak-merge-devshop): rebase before auditing to kill phantom revert findings`).

## Dismissals

None
