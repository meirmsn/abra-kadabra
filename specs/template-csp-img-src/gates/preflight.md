## Preflight (devshop mode)

- MODE=devshop (worktree of /devshop; common-dir /devshop/.git)
- TOUCHES_KIT=kit/docs/guide/README.md
- TOUCHES_TEMPLATE=template/apps/web/next.config.ts
- TOUCHES_SCRIPTS=  (empty — no kit/scripts edits)
- TOUCHES_HOOKS=  (empty — no kit/hooks edits)
- UI surface: none (devshop self-mode)
- Supabase: n/a (devshop self-mode)
- Chromium: n/a (no UI gates)
- Diff shape: pure docs/boilerplate (markdown guides + 1 TS snippet inside markdown + 1 template header comment)
- Known pre-existing bats failure: util-build-phase58-audit-parser.bats test 14 (1d343bf desync; filed in kit/TODOS.md on branch chore/file-phase6-audit-test-stale; NOT caused by this diff)
- Result: pass
