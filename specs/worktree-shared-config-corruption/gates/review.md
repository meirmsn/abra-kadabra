## Gate 6: /review

- Result: pass
- findings: high=0 medium=0 low=0
- vendor-bats-libs.sh — `set -euo pipefail` set; all three `rm -rf` targets are escape-safe: `$TMP_ROOT` (mktemp -d, EXIT trap), `$clone/.git` (under temp), `$dest=$LIB_DIR/$lib` ($LIB_DIR resolved absolute from BASH_SOURCE, $lib hardcoded in pin table, `set -u` aborts on any unset). No unbounded/relative deletion path.
- vendor-bats-libs.sh:79-80 — clone-then-checkout-SHA pins correctly; `git clone`/`checkout` under `set -e` abort on failure (network/bad-SHA), so a partial vendor can't be committed silently. `.git` stripped (line 83) before copy so no gitlink leaks in.
- vendor-bats-libs.sh:90-95 — per-path existence guard before `cp -a` catches a SHA whose layout lost a runtime path; `cp -a` preserves the executable bit on bin/bats + libexec. Manifest rewritten fresh each run (`: > "$MANIFEST"`, line 62) then appended per-lib — no stale residue.
- vendor-bats-libs.sh:104-105 — self-verify runs the FULL bats suite against the freshly-placed files; a broken vendor (missing/non-exec runner, broken load.bash) fails the suite and the script exits non-zero. Genuine catch, not a no-op.
- De-submodule clean: `.gitmodules` removed, `git ls-files -s kit/tests/lib | grep 160000` empty (no residual gitlinks), 41 plain files tracked under kit/tests/lib, bin/bats checked out 0755, no tracked `.git` pointers. No half-converted state.
- structural-invariants.bats:661 — rewritten "BATS runtime files are present" asserts real artifacts (bats-core/bin/bats executable + both load.bash files) with an accurate repair hint pointing at vendor-bats-libs.sh; vendor-bats-libs.sh correctly added to the infra-scripts (not-hook-wired) allow-list.
- util-ak-merge-devshop.bats:663-708 — rewritten assertions test something real: ordering check still enforces worktree-remove before branch -D; the new regression guard `! grep ... 'git ... submodule deinit'` matches an actual invocation (anchored to line-start git command, excludes prose) — a re-introduced deinit command would fail it.
- merge-devshop SKILL.md § 4.2 — submodule-deinit step removed; teardown is a single `git worktree remove --force` (Step 1). No dangling reference to the removed step; the `--force` rationale was correctly retargeted from "per-worktree submodule registry" to "uncommitted/untracked content (node_modules)". Coherent with workflow.md + architecture.md + CLAUDE.md edits (all submodule framing flipped to plain-files).
- Verification: full bats suite 1645 ok / 0 not-ok against vendored files; `gitleaks detect --no-git` over kit/tests/lib clean (no leaks). Merge-gate gitleaks path will not flag the vendored shell helpers.

## Dismissals

None
