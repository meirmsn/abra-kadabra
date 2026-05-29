## Gate 6: review

- Result: pass

Structural review of the diff. The only "code" is shell snippets in the skill and the bats test; the rest is prose.

**`-c` flag injection into the GIT_CMD array (skill).** Correct.
- The retry is written `"${GIT_CMD[@]}" -c core.checkStat=minimal -c core.trustctime=false rebase "$ANCHOR"`. `GIT_CMD` expands to `git` or `git -C "$WORKTREE_PATH"`. git's argument parser accepts global options (`-C <path>`, `-c <key>=<val>`) in any order before the subcommand, so `git -C <path> -c core.checkStat=minimal -c core.trustctime=false rebase` parses cleanly — `-C` then `-c` then subcommand. The skill prose explicitly calls this out ("git parses `-C` then `-c`"). Verified against git's documented behavior.
- **No repo-global config leak.** Both flags are inline per-command (`-c`), never `git config core.checkStat ...`. The skill states the rule twice (rebase region + cherry-pick region) and explains why: the reduced stat comparison stays scoped to the single invocation and can't bleed into unrelated git operations in the same worktree/session. This is the security-correct form — a repo-global `core.checkStat=minimal` would silently weaken stat-dirtiness detection for all future operations, which could mask real local changes.
- **Cherry-pick recipe** uses bare `git -c ...` (not the GIT_CMD array) — correct, because those are standalone surgical operations run directly against the current worktree, not routed through the merge skill's `-C`-targeted array.

**bats ordering check soundness.** Sound.
- Region-scoped via `awk '/^### 1\.0:/,/^### 1\.1:/'` — confines both the presence grep and the ordering comparison to Phase 1.0, so a `merge "$ANCHOR"` elsewhere can't satisfy the invariant.
- `grep -n ... | head -1 | cut -d: -f1` extracts the first line number of each form *within the awk output* (consistent numbering basis for both sides since both pipe the same awk region). `[ "$checkstat_line" -lt "$merge_line" ]` is a numeric comparison; both are guarded non-empty first (`[ -n ... ]`). No off-by-one or basis-mismatch risk.
- Escaping: `core\.checkStat` / `\$ANCHOR` / `\$\{GIT_CMD\[@\]\}` are correctly escaped for ERE (`grep -E`). Confirmed the grep matches the live file.

No conditional-side-effect, trust-boundary, or SQL concerns (none in scope). No structural issues.

## Dismissals

None
