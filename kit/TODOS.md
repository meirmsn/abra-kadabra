# Devshop TODOs

Devshop friction, bugs, and small fixes — things to do soon.
Strategic capabilities go in `ROADMAP.md`. Project issues go in root `TODOS.md`.

---

<!-- Items discovered during use. Tag with [v0.2], [v1] etc. to schedule into ROADMAP versions. -->

- [ ] **Per-project catch-up workflow after devshop changes — two-part design split.** No tracked artifact today captures how project repos catch up to recent devshop changes. The workflow naturally splits into two parts with materially different shapes that resist being skill-ified together:

  **Part 1 (mechanical, repeatable):** rebuild devcontainer → `bash .devshopkit/scripts/sync/from-devshop.sh` → review diff + commit → verify symlinks exist + check key locked files refreshed (e.g. `ls -la ~/.gstack/projects`, `cat .nvmrc`, check `.github/workflows/ci.yml` slow-job shape). Same dance every time. Probably belongs as a one-page doc under `kit/docs/guide/workflow.md § Per-project catch-up` rather than a skill — skill ceremony isn't justified for a 5-step mechanical recipe.

  **Part 2 (per-change one-shots, non-generic):** every devshop change that requires per-project follow-up has its own migration recipe. Examples: CLAUDE.md L1/L2 architecture migration (per-project 8-step recipe in `kit/docs/guide/claude-md.md`); `supabase/config.toml` backfill for rebound projects post-Option-C inversion (one-time commit per project); ad-hoc `.env` additions when new keys ship. These don't generalize — the recipe is specific to what shipped.

  **Proposed durable design:**
  - Part 1 → doc in `kit/docs/guide/workflow.md`. Cheap, ~30 min. Deferred (no PLAN row yet — surface when next-project catch-up surfaces friction worth doc-ifying).
  - Part 2 → convention. Codify the `**Existing projects:**` commit-body block as required for any devshop change with a per-project migration step. Precedents already exist (`44e53fc` supabase auto-stop, `4ec8cdd` ci.yml propagation, `87107fe` supabase port partial fix). **Filed as PLAN row `existing-projects-commit-convention`.**

  Separating into TODO (Part 1) + PLAN row (Part 2) reflects the divergent costs and timing: convention codification ships in ~30 min and immediately tightens the discipline going forward; the mechanical doc waits until a next-project catch-up genuinely needs it. [convention, workflow, ergonomics, references `kit/docs/guide/conventions.md § Commit + PR Text Style` + `kit/docs/guide/workflow.md`, surfaced-by 2026-05-23 session reflection on supabase-port-backlog merge catch-up]

- [ ] **[v0] Update `template/PLAN.md` schema to match devshop's rich Lev-scored shape, then propagate to existing projects.** Devshop's `PLAN.md` evolved from the simple `# | Feature | Notes` schema into a rich Lev-scored table (Feature | Hook | Impact | Risk | Cost | Lev | Deps | Source with glyph rating scale + numeric formula + Bundling cheatsheet + lifecycle conventions) — but `template/PLAN.md` (42 lines) still ships the old simple schema. New projects scaffolded today get the old shape; existing projects (lalista, home-os) likely on the old shape too unless manually upgraded.

  **Scope:**
  - **Template rewrite:** rewrite `template/PLAN.md` to mirror the rich devshop schema. Drop the devshop-specific `## Bundling cheatsheet` (overkill for project-side planning), keep Lev formula + glyphs + Deps + Source columns + Active/Planned section split + lifecycle rules. Keep the project-friendly tone (e.g. project Source pointers go to `PRODUCT-ROADMAP.md` / `TODOS.md` rather than `kit/ROADMAP.md`).
  - **Skill alignment:** verify `/ak-spec § Step 4` (which flips Planned → Active by adding `Branch` + `Spec` columns) still makes sense with the new schema. The Lev/Deps/Source columns likely stay through the Active transition.
  - **Existing-project migration:** `template/PLAN.md` is `[scaffold-once]` in `kit/manifest.txt` so `from-devshop.sh` won't auto-propagate. Per-project: rewrite each project's PLAN.md to the new schema as a one-time conversion (manual or scripted). Each existing project gets a one-time cleanup commit. Captured in the change's `**Existing projects:**` block per the per-project catch-up convention (separately filed above).

  **Why v0:** every new project that's about to scaffold gets the wrong schema, and our shipping discipline depends on Lev sorting + Deps tracking + Source pointers that don't exist in the old shape. The richer schema is what's working for devshop-side tracking; projects should benefit from the same. **Filed as PLAN row `template-plan-md-schema-uplift`.** [v0, template, scaffold-once, convention, references `kit/manifest.txt` + `.claude/skills/ak-spec/SKILL.md § Step 4`, surfaced-by 2026-05-23 session reflection on devshop-PLAN-rich-vs-template-simple gap]

- [ ] **Skip bats on docs-only devshop commits.** `.husky/pre-commit` runs all 1240 bats on every commit (~30s, measured 2026-05-23 on docs-only commit `20ca68b`). On pure-docs changes the suite is guaranteed-noop — wasted wallclock on every PLAN/ROADMAP/TODOS/BUILD-LOG/`*.md` commit.

  **First pass (cheap, ~15 min)**: inline ~15 lines of bash in `.husky/pre-commit`, inserted between the `gitleaks` line and the `bats` block, that early-exits the bats run when `git diff --cached --name-only` matches ONLY `*.md`, `PLAN.md`, `kit/ROADMAP.md`, `kit/TODOS.md`, `BUILD-LOG.md`, and `kit/docs/**`. Print a one-line "✓ Kit tests: skipped (docs-only diff)" so the operator sees signal, not silence.

  **Eventual (clean, ~1–2 hr)**: extend `kit/scripts/preship/path-classifier.sh` with a `--mode=devshop` flag + a devshop-flavored glob table (`kit/scripts/**`, `kit/hooks/**`, `template/**`, `.claude/skills/**`, `.husky/**`, `.claude/settings.json`, `.dcg.toml` → test-needing; everything else → skip). Call from `.husky/pre-commit` instead of the inline grep. Mirrors the project-side pattern where `kit/scripts/preship/changed-tests-local.sh` (Gate 2d) already uses the classifier for vitest/Playwright skip decisions — single source of truth for the "does this diff need the test suite?" question across project pre-ship + devshop pre-commit. Bats coverage for the new mode under `kit/tests/path-classifier-devshop-mode.bats`. Updated `localTestSkipReason` adversarial check is NOT needed for the devshop side — pre-commit's docs-only short-circuit is mechanical, not LLM-judged (low blast radius: false-negative is "ran bats unnecessarily", false-positive is "didn't run bats on a code change" — and the next non-docs commit catches it).

  **Saves**: ~30s per docs-only devshop commit. Rough git-log sample suggests ~30–50% of devshop commits are docs-only (ROADMAP/PLAN/TODOS/BUILD-LOG hygiene). Net: ~10–20s amortized per commit, plus the ergonomic improvement of "instant docs commit". [pre-commit, performance, ergonomics, references `kit/scripts/preship/path-classifier.sh` + `kit/ROADMAP.md § Cheap-test-gates-local sub-fix 2 stage 2`, surfaced-by 2026-05-23 reflection on the supabase-port-backlog-entries commit]

- [ ] **DCG `core.git:push-force-short` rule false-positives on compound commands containing `git push` + any `-f` flag.** Surfaced 2026-05-20 during `home-os-skill-polish-batch` teardown. Empirically verified via `dcg test`:
  - `git push -f origin main` — BLOCKED (correct behavior; this is what the rule is for)
  - `git push origin --delete fix/x` — ALLOWED (correct; `--delete` is not force-push)
  - `git submodule deinit -f --all && git worktree remove --force /tmp/x` — ALLOWED (no `git push` present)
  - `git submodule deinit -f --all && git worktree remove --force /tmp/x && git branch -D fix/x && git push origin --delete fix/x && rm -f /tmp/x.txt` — **BLOCKED on `push-force-short`** (FALSE POSITIVE — no `git push -f` exists, but the rule fires because `git push` + `-f` both appear in the compound command)
  - `git push origin main && rm -f /tmp/x.txt` — **BLOCKED on `push-force-short`** (minimal reproducer; benign push + `rm -f` is enough to false-positive)
  - The rule also false-positives when the `git -c devshop.docsReviewed="<reason>" commit ...` reason TEXT mentions `git push -f` as a literal string discussing the rule itself, even though the command being run is a `git commit` with no push at all.

  **Investigation (completed 2026-05-20)**: extracted regexes from the dcg 0.4.0 binary via `strings /usr/local/bin/dcg`. The `core.git:push-force-short` pattern is approximately:

  ```
  git\s+(?:\S+\s+)*push\s+.*-f\b
  ```

  (sibling `push-force-long` is `git\s+(?:\S+\s+)*push\s+.*--force(?![-a-z])`; the strict-git pack's `push-force-any` is `git\s+(?:\S+\s+)*push\s+.*(?:--force|--force-with-lease|-f\b)` — same shape, all three share the same greedy-`.*` bug.) **Root cause: the unanchored `.*`.** Once the regex matches `git ... push`, `.*` greedily consumes anything up to the next `-f` literal, INCLUDING shell separators (`&&`, `;`, `|`, newlines). So `git push origin main && rm -f /tmp/x.txt` matches because `.*` swallows `origin main && rm`.

  **Fix shape (upstream)**: change `.*` → `[^;&|\n]*` so the match stops at the nearest shell-command separator. Same fix applies to all three rules. The 5 test cases above become the verification matrix — all currently BLOCKED would flip to ALLOWED post-patch (except `git push -f origin main` and `git push --force origin main`, which would correctly stay BLOCKED).

  **Upstream repo**: `https://github.com/Dicklesworthstone/destructive_command_guard` (confirmed via `strings` against the embedded reference URL inside the dcg binary). DCG ships as a stripped ARM ELF; in-place patching the binary is not viable.

  **Current workarounds** (already shipped):
  - `/ak-merge-devshop § Phase 4.2` instructs operators to run each teardown step as a SEPARATE Bash tool call (no chaining). Documented empirically-verified false-positive shape inline.
  - When `git -c devshop.docsReviewed="$REASON" commit ...` is needed AND the reason text would mention `git push -f`, sanitize the reason (use phrases like "force-shortcut variant" / "push command + a separate short-dash-f flag" instead of literal `git push -f`).

  **Path forward** (post-investigation, in order of preference):
  - (a) **File upstream issue + PR** at `Dicklesworthstone/destructive_command_guard` proposing the `.*` → `[^;&|\n]*` patch on `push-force-short`, `push-force-long`, and `strict_git:push-force-any`. Include the 5 empirical test cases as the verification matrix. **Recommended first step** — single-line regex change with high signal-to-noise ratio.
  - (b) **Devshop-side wrapper** `kit/scripts/dcg-pre-check.sh <command>` that decomposes a compound command into per-shell-separator atoms, runs each through `dcg test` independently, and pre-filters false-positives before the harness hook fires. Tracked here because the wrapper would need to be a real PreToolUse hook upstream of dcg, which requires restructuring `.claude/settings.json`'s hook chain. Deferred unless upstream-patch is rejected.
  - (c) **Operator documentation only** (current state — workarounds shipped, root cause tracked here). Acceptable interim posture; revisit if a fourth false-positive event surfaces.

  Codified from `home-os-skill-polish-batch` + `ak-merge-devshop-hardening` + `session-followups` sessions (2026-05-20). Three false-positive events in one session, all empirically verified; root cause confirmed via binary inspection. Upstream patch is the canonical fix path.

- [ ] **`check-branch-not-main.sh` PreToolUse hook didn't block a `git commit` on main during a multi-session interleaving.** Surfaced 2026-05-20 during `fix/notify-suppress-deferred-work` work. Created `fix/structural-invariants-fault-injected-qa` branch, ran `Edit` + `git update-index --chmod=-x` + bats verification + commit — the commit landed on `main` (`ef6db18`), not on the fix branch. Two possible root causes:
  - (a) **Hook didn't fire / silently allowed.** The hook is filtered via `Bash(*git*commit*)` in `.claude/settings.json`. The commit invocation was `git -c devshop.docsReviewed='…' -c devshop.docsCoverageReason='…' commit -m '…'` — the `-c` flags may or may not interact with the matcher. Verify by simulating the exact invocation and observing hook stdin/stdout.
  - (b) **Parallel session ran `git checkout main` on /devshop between commands.** The same 2026-05-20 session had a second Claude in a worktree (`feat/skill-tempfile-stash-fixes`) explicitly asking the operator for `git checkout main` on /devshop. If the user ran that mid-session, the checkout would switch /devshop to main between my `git checkout -b` and the subsequent `git commit`, bypassing any branch-state check the hook performed.

  **What to investigate**:
  1. Reproduce: branch off main, run `git -c devshop.docsReviewed="x" -c devshop.docsCoverageReason="y" commit -m "…"`. Does the hook fire and block? If not, the `-c` flag prefix is breaking the matcher.
  2. Read `check-branch-not-main.sh` to confirm it queries `git branch --show-current` at the moment the commit is invoked, and whether there's any race window where a concurrent checkout could change branch state between hook fire and `git commit` execution.
  3. Add a `kit/tests/structural-invariants.bats` test: "every commit-from-Claude lands on a non-main branch" — exercise via running the hook against a fake `Bash(*git*commit*)` invocation with a pre-checked-out main state. Should always block.

  **Fix shape (once root cause known)**:
  - If (a): patch the matcher / `command` to be robust against `-c` flag prefixes; add bats coverage.
  - If (b): document the multi-session-on-shared-checkout footgun in `CLAUDE.md § Known Footguns` + propose a session-acquired lock on `/devshop`'s working tree (or strengthen the convention against shared-checkout interleavings — worktrees should be used for parallel work, but the parent /devshop checkout is still shared).

  **Why a TODO not an immediate fix**: root cause unknown — could be hook bug, parallel-session race, or both. Investigation precedes fix-shaping. The 2026-05-20 incident was self-corrective (the commit was a tightly-scoped, pre-tested fix-forward that was safe on main); a similar incident with a less-safe commit would be more painful.

  Cross-ref: `kit/scripts/commit-hooks/check-branch-not-main.sh` (the hook in question); `.claude/settings.json` § PreToolUse Bash matcher (the wiring); fix/notify-suppress-deferred-work bundle commits `ef6db18` + `fd271f3` (the incident); `CLAUDE.md § Known Footguns` "Never commit directly to main" (where the multi-session note would go if confirmed). [hook, branch-guard, multi-session-coordination, surfaced 2026-05-20]

- [ ] **`/ak-merge-devshop § Phase 2`: auto-detect rebase phantom-fail and switch to merge-fallback.** The skill already documents the virtiofs / lint-staged "Aborting / rescheduled" failure mode and the merge-fallback recipe under the `Phantom "local changes would be overwritten" — fall back to merge` callout, but the detection-and-switch is operator-mediated: the agent has to recognize the failure pattern in `git rebase` output (`Aborting`, `It has been rescheduled`, `currently editing a commit while rebasing`) and remember to switch paths. During the 2026-05-20 session, both merges (`feat/phase3-blocked-halt` and `chore/plan-hygiene-shipped-rows`) hit this pattern and required the manual fallback. Each occurrence costs a `git rebase --abort` + recovery loop (~30s + cognitive overhead). Fix shape: parse the rebase return for the signature triple (`Aborting`, `rescheduled`, `currently editing`) and, when matched, automatically `git rebase --abort` + run the merge-fallback sequence without operator handoff. Could go even further with a pre-flight env probe (`grep -q virtiofs /proc/mounts` + lint-staged version check) that picks the merge path proactively before attempting rebase on environments known to hit this — saves the abort cycle entirely. Underlying virtiofs / lint-staged interaction is tracked separately (the upstream issue isn't fixed yet; this TODO is about the orchestrator-side mitigation). [orchestrator, ak-merge-devshop, ergonomics, surfaced-by feat/phase3-blocked-halt + chore/plan-hygiene-shipped-rows merges 2026-05-20]

- [ ] **advisor-probe.mjs: live-Postgres integration coverage.** The 9 `pg_catalog` SQL queries in `template/scripts/advisor-probe.mjs` (function_search_path_mutable, auth_rls_initplan, unindexed_foreign_key, multiple_permissive_policies, security_definer_view, rls_disabled_in_public, rls_enabled_no_policy, extension_in_public, duplicate_index) are not exercised against any Postgres instance today. The bats spec is source-grep only; the pre-ship `advisor-clean` gate stubs both `psql` and `pnpm` in tests. A typo in any lint's WHERE clause (e.g. `pg_policy` vs `pg_policies`, missing schema filter, wrong column type cast) ships invisibly. Manual smoke against a project devcontainer's supabase-runner is the current dogfood path but not regression coverage. Add an integration spec under `kit/tests/` that either boots a throwaway Postgres via `pg-mem` / one-shot `docker run postgres` (gated on docker-daemon reachability in the devshop's own devcontainer) or runs against `supabase-runner:54322` when reachable. Per-lint fixtures: seed a known-buggy schema for each lint and assert the probe flags the expected object. Blocks: today's devshop devcontainer has no Postgres binary and no Docker daemon — needs either a setup step that brings one of those in, or CI-side coverage with a Postgres service. [tests, db-hardening, blocked-by-environment, surfaced-by audit-1 of db-hardening-template-lift, 2026-05-20]

- [ ] **advisor-probe.mjs: behavior-test `loadExemptions()` instead of source-grep.** The bats test for ADVISOR-EXEMPT marker parsing greps the source for the regex literal and the `exemptions.has(...)` call site. A regression where `loadExemptions()` returns an empty Set unconditionally (broken readdir loop, case-mismatched regex flag, typo in the marker scan) passes the test cleanly — operators would see findings on a lint they had annotated and have no signal that the exemption mechanism is dead. Refactor `loadExemptions` into an exported helper; unit-test it by writing fixture migrations under a temp dir and asserting the returned Set contains expected lint names (and rejects unknown ones). Small change (extract function + 3-4 bats); deferred only because v0 ships and the medium-blast-radius live-Postgres gap above is the bigger lever. [tests, db-hardening, surfaced-by audit-1 of db-hardening-template-lift, 2026-05-20]

- [ ] **Existing-project migration: strip pre-seeded PRODUCT-ROADMAP + CLAUDE.md gotcha content from lalista and home-os.** The `chore/convention-housekeeping` bundle (2026-05-19, devshop commit `3633daa`) stripped 3 pre-seeded entries from `template/PRODUCT-ROADMAP.md` (PWA SW caching, visual regression testing, API perf baselines) and the pre-seeded PostgREST `data: null` gotcha from `template/CLAUDE.md § Gotchas`. Both files are `[scaffold-once]` in `kit/manifest.txt` — sync-from-devshop skips them on purpose (projects own their CLAUDE.md / roadmap content), so existing projects don't get the strip automatically.

  **Per-project recipe** (run inside each project's container, on a feature branch):
  1. `diff PRODUCT-ROADMAP.md <(cat /devshop/template/PRODUCT-ROADMAP.md)` — if the 3 sample entries are still verbatim, delete them; if the project has edited any of them into project-shaped content, leave that one and delete only the verbatim ones.
  2. `diff CLAUDE.md <(cat /devshop/template/CLAUDE.md)` against the § Gotchas section — if the PostgREST entry is still verbatim, delete it (the recipe still lives at `kit/docs/guide/database-queries.md`); if the project has added real gotchas alongside it, leave the project's entries and delete only the verbatim seed.
  3. Commit per project on its own feature branch with subject `chore: strip devshop-meta seed content from PRODUCT-ROADMAP + CLAUDE.md`.

  **Why this is a TODO and not auto-applied**: scaffold-once is the correct classification (projects own these files); a sync-script that overwrites them would clobber any project-specific edits. The cleanup needs to be a one-time per-project pass with diff-and-decide judgment.

  Cross-ref: `/devshop` commit `3633daa` (template strip); `kit/notes/projects/lalista.md` + `kit/notes/projects/home-os.md` for per-project pre-state.

- [ ] **Flip `sync/from-devshop.sh` (and `to-devshop.sh`) from apply-first-show-after to show-first-confirm-then-apply.** Both sync scripts currently copy files to disk BEFORE showing the diff — the `git diff` at the end of the script is post-hoc; the closing "Review the changes above. If they look good: git add -A && git commit ..." message is theater (the working tree is already mutated). Quitting the diff pager (typically `less`, exit with `q`) does NOT roll anything back. Recovery is `git checkout -- <path>` for tracked files; gitignored content deleted by `rsync -a --delete` is unrecoverable.

  **Where it bit**: 2026-05-22 home-os sync — `.devcontainer/.env` was deleted silently (gitignored → invisible in `git status`), four `[locked]` devcontainer files + one `[scaffold-once]` overlay were clobbered before the operator could see the diff and abort. The fixes in `ba0ab3e` + `af104ac` close the destructive-clobber surface (.env preserved via `!path` excludes, [locked] + [scaffold-once] leaves excluded, screenshots gitignore preserved), but the apply-first shape itself remains a sharp edge: any future widening of sync scope inherits the same "operator can't say no" trap.

  **Fix shape**: insert a dry-run preview between manifest parse and the actual apply.
  1. **Dry-run pass**: replace each `cp` / `rsync -a --delete` with `rsync -an --delete --itemize-changes` (or `cp -n` + manual diff) to a temp dir under `/tmp/sync-preview-$$/`, building a unified diff of every proposed change.
  2. **Render preview**: pipe the aggregated diff through `git --no-pager diff --no-index --color=always` for syntax highlighting (or fall back to `less -R` for paging). Show a one-line summary header: `N files would change (M modified, K added, L deleted), continue? [y/N/diff]`.
  3. **Confirm gate**: read a single keypress from `/dev/tty` (NOT stdin — same controlling-terminal lesson as the pnpm prompt). `y` = apply; `N` (default) = abort cleanly with `rm -rf /tmp/sync-preview-$$/`; `diff` = re-show the diff and re-prompt.
  4. **Apply pass**: only on `y`, run the actual copy commands. Same exclude logic as today (the `ba0ab3e` three-source model — `!path` + `manifest_locked_under` + `manifest_scaffold_once_under`).
  5. **Bypass for CI / scripted invocation**: support `--yes` / `-y` flag that skips the prompt for automation contexts. Symmetric with the convention used by `apt-get install`, `gh pr merge`, etc.

  **What this unlocks** — addresses the deferral reason in the entry above (`Existing-project migration: strip pre-seeded PRODUCT-ROADMAP + CLAUDE.md gotcha content`). That entry's "Why this is a TODO and not auto-applied" rationale was _"a sync-script that overwrites [scaffold-once] files would clobber any project-specific edits."_ With show-first-confirm-then-apply, the operator sees the proposed strip per-file and accepts or declines — exactly the "diff-and-decide judgment" that entry calls for. Once this lands, the [scaffold-once] strip becomes a candidate for sync-driven propagation (with a manifest annotation like `[scaffold-once-syncable]` or a per-file confirm) rather than per-project manual recipe. The dependency direction: show-first ships first, then the strip-propagation entry can be revisited with a path forward.

  **Symmetry note**: `to-devshop.sh` (project→template push) has the same shape and should get the same treatment in the same PR. Pushing project content back to template is more catastrophic per failure (clobbers the seed for ALL future projects), so the operator-confirm gate is arguably more important on the push direction.

  **Tests**: bats coverage in `kit/tests/manifest-lifecycle.bats` should add: (a) `--yes` flag bypasses the prompt + applies, (b) `N`/empty response aborts without touching the working tree, (c) the dry-run preview shows the same set of files the apply pass would touch (no drift between preview and apply). The "no drift" assertion is critical — if preview and apply diverge, the operator's "yes" is uninformed.

  **Scope**: ~1-2 hr for the basic y/N/diff loop + `--yes` flag + 3-4 bats. Per-file or per-hunk select (à la `git add -p`) is a v1 enhancement, deferred until an operator needs partial-apply.

  Cross-ref: this entry's predecessor (above) — strip propagation becomes safer once show-first lands; `kit/docs/guide/architecture.md § Build tooling sync § Apply-first-show-after semantics` (the architecture doc currently describes apply-first as intentional; will need rewrite when this lands); 2026-05-22 home-os sync surfaced via `fix/pnpm-modules-purge-ci-bypass` commits `ba0ab3e` + `af104ac`. [sync, devshop, ux, 2026-05-22]

- [ ] **`/ak-merge-devshop` Phase 2 — mechanize the virtiofs phantom-rebase fallback (auto-retry or auto-switch-to-merge).** Surfaced twice on 2026-05-19: first during `sandbox-qa-close-gap` merge (multi-commit rebase fired the error twice in one run — 4 files on `d31af1a` pick + 1 file on `9dcdd4d` pick), then again during `ci-rollback-explain-marker-loud` merge (rebase aborted on `PLAN.md` even with a clean `git status` + zero `git ls-files -m`). `git rebase origin/main` fires `error: Your local changes to the following files would be overwritten by merge` on files git itself reports clean. Root cause: virtiofs stat-cache mismatch between Docker Desktop's macOS-side view and the container's stat-cache view. Same error also surfaces during direct `git merge --ff-only` (hit during the `ci-rollback-explain-marker-loud` Phase 3 ff-merge on /devshop's main worktree).

  **Current state (post-2026-05-19):** Phase 2 of the skill now documents an operator-facing fallback — fall back to `git merge origin/main` + transient commit + soft-reset + squash. Verified end-to-end on `ci-rollback-explain-marker-loud`. The fallback works but the operator (or agent) has to recognize the symptom and switch paths manually.

  **Fix shape (two options, pick one):**
  - **Auto-retry:** on rebase failure, grep stderr for the literal string `Your local changes to the following files would be overwritten by merge`; if matched AND `git status --porcelain` returns empty, run `git update-index --really-refresh` and `git rebase --continue`; cap at 2-3 retries (more suggests a real conflict). The error string is stable across git versions — anchor the grep on it.
  - **Auto-switch:** on rebase failure matching the same symptom, abort the rebase and switch automatically to the merge-then-soft-reset fallback the skill already documents. Avoids the retry loop entirely; the merge path is unaffected by the stat-cache bug. Slightly more code (transient merge commit + docsReviewed trailer composition) but strictly more reliable than retry-until-clean.

  **Value:** today the rebase failure halts the merge subagent's autonomy. The agent either bails (manual operator intervention) or burns context guessing at root causes. A mechanical resolution routes the common case to recovery without humans, leaving the halt path for genuine conflicts. Estimated cost: ~30-45 min skill edit + a bats test against a mocked rebase-failure scenario.

  Cross-ref: `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 2 — Phantom "local changes would be overwritten"` (the operator-facing fallback this entry mechanizes); `kit/docs/guide/architecture.md § Docker Desktop / virtiofs` for the broader stat-cache-mismatch class of bugs.

- [ ] **Investigate Mac host-resource constraints as the real cause of home-os PR #27 / #28 `blocked` outcomes.** Codified 2026-05-19 during `sandbox-qa-close-gap` PR. The original ROADMAP framing of those incidents attributed `blocked (n/a per scope: sandbox)` outcomes to workspace tooling gaps. Operator pushback flagged a different hypothesis: "QA was working on many PRs on lalista and home-os until it didn't, and it seemed to be about resource constraints on my host Mac." If the hypothesis is right, the workspace-tooling fixes (Chromium apt-bake 2026-04-23, env-aware Supabase ports 2026-05-19) don't address the actual recurring failure mode.

  **What to investigate**:
  1. Re-read home-os PR #27 + PR #28 audit comments. Was the `blocked` reason "Chromium failed to launch" / OOM signals / "Playwright timeout waiting for browser" — i.e. resource pressure? Or was it tooling-not-installed?
  2. Cross-correlate failure timestamps with Docker Desktop's Resource Saver activity, macOS swap usage (`vm_stat`), and any heavy host apps running (Chrome with many tabs, Slack, Spotify, etc.).
  3. Test under controlled conditions: rebuild home-os's devcontainer with all gates intact, close every other macOS app, then run `/ak-pre-ship` on a no-op branch. If gates pass clean, host-resource hypothesis is confirmed.

  **Likely fixes if confirmed** (mutually exclusive — pick one):
  - **(a) Docker Desktop resource allocation bump** — increase the VM's memory cap (Settings → Resources). Cheapest, but caps at host's available RAM.
  - **(b) Concurrency cap inside the devcontainer** — `pnpm test:unit --max-workers=2`, Playwright `workers: 1` in `playwright.config.ts`. Trades wall-clock for stability.
  - **(c) `/ak-pre-ship` preflight resource check** — emit a `findings (1)` (not `blocked`) when free memory < threshold, with operator guidance to close heavy apps before re-running. Most surgical, but `/ak-pre-ship` doesn't currently introspect host resources.

  **Why this is a TODO and not a v0 ROADMAP entry**: needs investigation before fix-shaping. Once the hypothesis is confirmed (or refuted), promote to ROADMAP with concrete fix shape. Until then, this is a debugging breadcrumb so future sessions don't re-discover the question.

  Cross-ref: `sandbox-qa-close-gap` shipped 2026-05-19 (only addressed the iptables port issue, NOT this resource hypothesis); `kit/notes/projects/home-os.md` for PR #27 / #28 details.

- [ ] **Apply CLAUDE.md architecture migration to lalista.** Codified 2026-05-19 after the home-os migration shipped (8 commits across `feature/claude-md-architecture` in `/workspace` and `/devshop`; final state in `kit/notes/claude-md-migration.md`). Lalista's CLAUDE.md was not touched by the home-os migration; it remains pre-migration shape and will benefit from the same trim. Run from inside lalista's workspace container, on a fresh `feature/claude-md-architecture` branch.

  **Pre-reading** (do these in order, all in `/devshop/kit/`):
  1. `kit/docs/guide/claude-md.md` — the convention doc that defines the inclusion rule, 3-class taxonomy, bypass mechanism, and `§ Migration recipe for an existing project` (8 numbered steps).
  2. `kit/notes/claude-md-migration.md` — the home-os migration record. Read § Design principles + § Wave plan + § Decisions that shaped the migration. The mid-wave architecture pivots (mechanical gates dropped Wave 4; symmetric devshop trim Wave 5) carry decision-context lalista's migration may need.
  3. `kit/notes/home-os-claude-md-classification.md` — fullest worked example. 28 gotchas + every non-Gotcha section classified.
  4. `kit/notes/lalista-claude-md-classification.md` — earlier classification work on lalista's gotchas. **Useful as a starting point but pre-dates this migration's refinements**: some entries may now be covered by guides that didn't exist then (`llm-trust-boundaries.md`, `date-handling.md`, `conventions.md § Verify state before public assertion`, `conventions.md § Closing TODO / ROADMAP entries when a fix ships`, `security.md § Authoring locked files`, `ops.md § Browse daemon binary drift` + `§ Playwright cache population`).
  5. `kit/notes/migration-info-loss-audit.md` — the audit format. Reproduce a similar audit for lalista at the end of the migration.

  **Wave plan** (mirrors home-os's; estimated ~3-5 hours of focused work, possibly faster since lalista has a classification baseline):
  1. **Wave 1 — Foundation docs.** Re-classify lalista's CLAUDE.md against current state (refresh `kit/notes/lalista-claude-md-classification.md`). Verify each "Lift to <guide>" target — for any entry now covered by a new guide (per item 4 above), update target. Create `/workspace/DEPLOY.md`, `/workspace/KNOWN-ISSUES.md` if not present. Lift operator TODOs to `/workspace/TODOS.md`.

  2. **Wave 2 — Area READMEs + guide extensions.** Populate `apps/web/README.md`, `supabase/README.md`, `packages/*/README.md`, `supabase/functions/README.md` (as applicable) by fanning out from CLAUDE.md § Where Things Happen entries. For any "Generalizable — lift" entries whose canonical recipe isn't already in a devshop guide, extend the relevant guide BEFORE proceeding. Lalista likely has different gotchas than home-os; some may require new sections in existing guides or even new guide files.

  3. **Wave 3 — Trim lalista CLAUDE.md.** Apply the classification. Move file-specific gotchas as code comments at their call sites (some may already be there from prior PRs; verify with grep). Measure final size.

  4. **Wave 4 — n/a for project migration.** The enforcement layer (Layer A router via routing index → `claude-md.md` guide + Layer C audit via `/ak-docs-review § Section E`) is already devshop-wide; lalista inherits it automatically. No per-project toolchain change needed.

  5. **Wave 5 — n/a for project migration.** The hook fix + devshop CLAUDE.md trim shipped with home-os's migration. Lalista benefits without additional work — the SessionStart hook delivers slim devshop CLAUDE.md (~22k) to lalista's project sessions identically.

  6. **Final — Info-loss audit.** Produce `kit/notes/lalista-migration-info-loss-audit.md` mirroring the home-os audit format. Grep distinctive phrases at every lift target + every area README + every code-comment relocation + every operational-content move. Confirm no content lost.

  **Why the home-os ordering doesn't quite map for lalista**:
  - Home-os shipped Waves 1-5 because Wave 4 (enforcement) and Wave 5 (hook fix + devshop trim) had to land devshop-wide. Lalista is downstream of those — they're already in effect for every project including lalista.
  - Lalista's "Wave 5 equivalent" is just running the migration on its own CLAUDE.md, with the toolchain + devshop CLAUDE.md already in their post-migration shape.

  **Lalista-specific considerations**:
  - Lalista is a Supabase + Next.js + lists-app stack. Some gotchas in lalista CLAUDE.md may be highly lalista-specific (specific RPC names, household-membership invariants, etc.) — those are "Project-specific stay" by default.
  - Lalista already has well-developed wrapper-boundaries patterns (`packages/core/src/api/*`) — the codified pattern lives in `kit/docs/guide/wrapper-boundaries.md`. Verify lalista's wrapper-related gotchas point at the canonical home rather than restating.
  - Lalista's "single-household v0 invariant" + "Realtime channel keeps delivering to removed members" are project-specific stay-class entries per the original classification — leave verbatim.
  - The lalista classification has synthetic `S*` rows (S1: middleware allow-list bypass, S2: removed-member realtime leak, S3: DB constraint as loud backstop). Verify these have lifted to devshop guides — per the original doc they had targets like `supabase-ssr-boilerplate.md § Pattern 8`, `wrapper-boundaries.md § Removed-member realtime leak`, `migrations.md § DB constraint as loud structural backstop`. Grep to confirm.

  **Bypass mechanism (informational, not gate-bypassing)**:
  - `kit/scripts/justify-claude-md.sh "<reason>"` produces the inline marker + commit trailer when adding a CLAUDE.md entry whose home is unclear or that the reviewer might challenge. Useful for any "Project-specific stay" entry whose rationale future audits should re-examine.

  **Done when**:
  - Lalista CLAUDE.md is under ~10k chars (post-trim), with the inclusion rule applied per entry.
  - Lalista's `apps/*/`, `supabase/`, `packages/*/` have area READMEs absorbing the Where Things Happen fan-out.
  - The info-loss audit confirms every original entry has a documented destination.
  - `/ak-docs-review § Section E` on the migration PR produces a clean audit (or only LOW severity findings).

- [ ] **Codify regression coverage for `/ak-build` Phase 3→4 LLM-mediated-`n/a` awk halt grep.** Surfaced 2026-05-17 by `/ak-merge-devshop` Phase 1 audit on `fix/pre-ship-llm-gate-contract`. The third halt rung (`.claude/skills/devshop/build/SKILL.md:478-487`) is an inlined `awk` script that the orchestrator agent runs against `review.md` to catch forbidden `n/a` outcomes on Gates 6/7/8/9. The mid-branch commit `3ed6e8b` fixed a mawk-portability bug (`\b` is GNU-awk-only; mawk silently treats it as empty) — verified by manual smoke test against a fixture, but the smoke test was not codified. A future "simplify" or rename edit to the prose can silently re-introduce the gap and the failure only surfaces when `/ak-build` next runs against a real `n/a` violation. **Fix** (cheapest): add `kit/tests/util-ak-build-llm-mediated-na-grep.bats` exercising the inlined awk against fixture `review.md` files — plain `n/a` on Gate 8 (should print gate line, regression target for the mawk `\b` bug), `blocked (n/a per scope: ...)` (should print nothing, scope-exempt shape), non-LLM-mediated gate `n/a` (should print nothing, carve-out preserved). Run with `mawk` explicitly. Higher-scope alternative: extract the awk to `kit/scripts/preship/check-llm-mediated-na.sh` and bats-test the script directly — also makes the mechanism a first-class testable surface instead of orchestrator-prompt prose. Parallel coverage exists for the related adversarial-review.sh fast-path (`kit/tests/util-adversarial-review-blocked-dismissal.bats`); this gap closes the symmetric one.

- [ ] **Migrate lalista's local Supabase stack off `project_id = "workspace"`.** Surfaced 2026-05-13 while inspecting `docker ps` for home-os: lalista's stack containers are named `supabase_*_workspace` rather than `supabase_*_lalista`, because `supabase init` defaults `project_id` to the basename of `$PWD` — which is `/workspace` inside the container. Lalista's `supabase/config.toml` was never substituted at scaffold time (the bug `/ak-new-project § Step 15` fix in this same commit closes for future projects). Symptom is mostly cosmetic (Docker Desktop UI groups the lalista stack under "workspace" — misleading when multiple projects run on the same host) but **becomes a real container-name collision the moment a second project is also stuck on `project_id = "workspace"`** (only one such project can run a local stack at a time). Home-os was scaffolded correctly with `project_id = "home-os"` only because the operator noticed and edited it manually — the template still ships the bug pre-Step-15-fix.

  **Migration recipe (run from inside lalista's workspace container, on a clean tree)**:

  ```bash
  # 1. Stop the current stack (frees container names + host port 54321/54322)
  curl -X POST http://supabase-runner:9000/stop
  #    or, if not using compose isolation:
  #    supabase stop

  # 2. Rename project_id in the committed config
  sed -i 's/^project_id = "workspace"$/project_id = "lalista"/' supabase/config.toml
  git add supabase/config.toml
  git commit -m "fix(supabase): rename project_id from workspace to lalista"

  # 3. Bring the stack back up under the new name
  curl -X POST http://supabase-runner:9000/start
  #    or: supabase start

  # 4. Verify (from the host) — new names appear, no stale workspace orphans persist
  docker ps --format '{{.Names}}' | grep '^supabase_.*_lalista$'   # expect 10 containers
  docker ps -a --format '{{.Names}}' | grep '^supabase_.*_workspace$'   # expect empty after step 1's stop

  # 5. If step 4 shows lingering `supabase_*_workspace` containers (the stop call only
  #    pauses, doesn't remove), force-delete them — their data is reproducible from
  #    `supabase/migrations/` + `supabase/seed.sql` so no dump/restore is needed for
  #    a local dev stack:
  docker rm -f $(docker ps -aq --filter "name=^supabase_.*_workspace$")
  ```

  No project code references `project_id` directly (it's a Supabase-CLI-internal namespace), so no source-file or `.env` updates are needed beyond the one-line `supabase/config.toml` edit. After step 3, `pnpm db:reset` + `pnpm db:gen-types` continue to work unchanged because the relay address (`supabase-runner:9000`) and the host-bound REST/Postgres ports (54321/54322) don't depend on `project_id`. Delete this entry from `kit/TODOS.md` in the same commit that lands step 2.

- [ ] **Migrate remaining 10 inline `[ -d "$X/kit" ] && [ ! -L "$X/kit" ]` detections to `kit/scripts/sync/lib/detect-mode.sh`'s `is_devshop_self_mode`.** The lib + `DEVSHOP_FORCE_MODE` env override shipped in `fix/init-devshop-tolerate-missing-password` (2026-05-12) but only the 3 surfaces with currently-broken bats tests were migrated: `kit/hooks/pre-commit.sh`, `kit/scripts/commit-hooks/commit-guard.sh`, `kit/scripts/commit-hooks/check-security-files-freshness.sh`. The other 10 callers still inline the check: `kit/hooks/pre-push.sh`, `kit/scripts/init-devshop.sh`, `kit/scripts/sync/create-devshop-symlinks.sh`, `kit/scripts/adversarial-review.sh`, `kit/scripts/commit-hooks/{check-docs-coverage-project,check-docs-coverage-devshop,check-tests-coverage-project,check-tests-coverage-devshop,check-manifest,check-exempt-additions}.sh`. Their tests aren't currently broken in the devshop devcontainer (none try to simulate project mode while running there), but any future test that does will hit the same trap. Migrate incrementally — each script is a single-line replacement (source the lib, swap the inline conditional for `is_devshop_self_mode "$X"`). `adversarial-review.sh:88` has an explicit `[ "$GIT_ROOT" = "/devshop" ] || ...` short-circuit that the lib's auto branch already covers (when `GIT_ROOT=/devshop`, `/devshop/kit` IS a real dir in production); preserve the simplification but verify against `kit/tests/adversarial-review-*.bats`. `commit-guard.sh` already had a `!= "/devshop"` guard removed in this fix — same pattern in others, safe to drop.

- [ ] **`sudo /usr/local/bin/init-firewall.sh` hangs the Claude Code session when re-run mid-session.** Observed twice during lalista PR 2 close-out (2026-04-20). Container rebuild is the only known recovery. Root-cause hypothesis (unconfirmed): iptables/ipset rebuild drops the session's own established API connection; when Claude Code reconnects against the new network state, commands stall indefinitely.

  **Workaround**: never re-init the firewall during a session. If outbound HTTPS to a new domain fails mid-session (CDN IPs rotate), treat it as an infrastructure TODO — don't hot-patch.

  **Proper fix**: investigate whether `init-firewall.sh` can be made connection-preserving (atomic ipset swap instead of destroy-and-recreate), or run in a separate network namespace so the current session's TCP state isn't affected. Target file is the one shipped in the devcontainer image at `/usr/local/bin/init-firewall.sh` — locate the source in `template/.devcontainer/` (Dockerfile COPY target) and fix there.

  **Related: bootstrap chicken-and-egg in the [locked] file refresh model.** Surfaced 2026-05-02 (lalista rebuild failed when `statsig.anthropic.com` NXDOMAIN'd — Anthropic appears to have retired that subdomain). `init-devshop.sh:115` refreshes `<workspace>/.devcontainer/init-firewall.sh` from `/devshop/template/.devcontainer/init-firewall.sh` on every container start, but it runs _after_ `init-firewall.sh` in `postStartCommand` (gated by `&&`). When init-firewall itself is broken, init-devshop never runs, the workspace copy stays stale, and the next rebuild bakes the old broken version into `/usr/local/bin/` again — because the Dockerfile's `COPY init-firewall.sh /usr/local/bin/` reads from the workspace's local copy (Docker build context can't reach outside the workspace, so `/devshop/template/` is invisible at build time). The `[locked]` model assumes init-firewall succeeded at least once on a previous start; there's no out-of-band bootstrap path when the locked file itself is what's broken.

  **Practical mitigation shipped 2026-05-02**: made `init-firewall.sh`'s domain loop tolerant of single-domain DNS misses — warn-and-continue instead of `exit 1`, with a loud yellow inline banner + an end-of-run summary banner listing all skipped domains. Same warn-pattern the GitHub Actions blob-shards loop already used in the template variant. Applied to both `template/.devcontainer/init-firewall.sh` (every Option-3 project) and `.devcontainer/init-firewall.sh` (devshop's own container); also dropped the now-NXDOMAIN'd `statsig.anthropic.com` from the allowlist. This collapses bootstrap-breaking failure modes into a much narrower set (e.g. github.com unreachable, which would brick a lot more than this one script). Operator workaround when the bootstrap _does_ break: `sudo /usr/local/bin/init-devshop.sh` from inside the degraded container hand-cranks the [locked] refresh (this is the wrapper path with the Dockerfile-baked NOPASSWD entry; `sudo bash /devshop/kit/scripts/init-devshop.sh` looks like the same thing but isn't — that path doesn't match the sudoers rule and prompts for `node`'s password, which isn't set), then rebuild bakes the patched version normally.

  **Architectural fixes worth considering** (deferred — practical mitigation closes the immediate concrete failure mode):
  - Move the [locked] refresh portion of init-devshop into `initializeCommand` (host-side, pre-build) so workspace is synced from template _before_ Dockerfile reads it. `init-host-env.sh` already runs in initializeCommand and resolves `/devshop/` on the host for compose isolation, so the plumbing exists — but splits init-devshop into pre-build + post-start halves.
  - Reorder postStartCommand so init-devshop runs first. init-devshop's [locked] refresh is a pure-filesystem operation (template→workspace `install`) so doesn't strictly need network — but doesn't help the immediately-running `/usr/local/bin/init-firewall.sh` (which is the baked image copy); only helps the _next_ rebuild.
  - Multi-stage Dockerfile that exposes `/devshop/template/` as a build stage so `COPY --from=devshop-source` works at build time. More invasive; ties build to a path layout; doesn't survive scaffold-from-zero where `/devshop/` doesn't exist yet.

  [container-infrastructure, documented 2026-04-20, related-bootstrap-finding 2026-05-02, mitigation-shipped 2026-05-02]

- [ ] **`init-devshop.sh` mtime-bumps `[locked]` files even when content already matches, training operators to dismiss VS Code's "Configuration file(s) changed" rebuild prompt.** Surfaced 2026-05-09 during the firewall-hardening rebuild (PR #59 follow-up). After a clean rebuild where `/devshop/template/.devcontainer/{Dockerfile,devcontainer.json,init-firewall.sh,refresh-allowed-ips.sh,init-prod-url.sh}` matches `<workspace>/.devcontainer/...` byte-for-byte, init-devshop's `[locked]` refresh pass at boot still rewrites every locked file (the `install`/`cp` runs unconditionally inside the loop), bumping mtime. VS Code's "did this file change since last build" detector compares mtimes against its build-time baseline, so it flags identical-content files as changed and prompts to rebuild again. The prompt is benign (`diff -q template workspace` shows no diff; the next rebuild would produce an identical image), but it's **persistent across rebuilds** — every fresh boot re-arms the prompt — and trains operators to dismiss "rebuild needed" notices reflexively, which is bad signal-to-noise hygiene for a real-life "you actually do need to rebuild" event later.

  **Fix**: make the `[locked]` refresh content-aware in `template/.devcontainer/init-devshop.sh` — wrap the `install`/`cp` in `cmp -s "$src" "$dst" || ...` so the write only fires when content actually differs. Apply the same guard to the chown+chmod step (skip when ownership and mode already match — e.g. compare `stat -c '%U:%G %a' "$dst"` against the desired tuple). Net effect: on a quiet boot where nothing changed in `template/`, init-devshop becomes a true no-op and VS Code's rebuild prompt clears after the first post-update rebuild, never to return. Single edit target: `template/.devcontainer/init-devshop.sh`'s `[locked]` refresh loop. Also worth applying to the devshop self-lock loop if it follows the same pattern.

  [container-infrastructure, low-priority, surfaced-by firewall-hardening-2026-05-09]

- [ ] **Docker Desktop daemon-level `no-new-privileges: true` breaks the workspace devcontainer's postStartCommand.** Surfaced 2026-05-02 (lalista operator). Setting `"no-new-privileges": true` in Docker Desktop's Engine JSON applies it as the default to every new container, including the workspace devcontainer. The workspace's `postStartCommand` (`devcontainer.json:80`) is `sudo /usr/local/bin/init-firewall.sh && sudo /usr/local/bin/init-devshop.sh && …` — and sudo is a setuid binary, which NNP disables. Container rebuild fails with: `sudo: The "no new privileges" flag is set, which prevents sudo from running as root.` The other two flags currently recommended alongside it (`userland-proxy: false`, `icc: false`) are safe. Currently documented in `kit/docs/guide/macos-host-setup.md` Step 2, `kit/docs/guide/local-supabase-compose-isolation.md`'s Option 3 hardening table, and `kit/notes/security/local-supabase-isolation-options.md`.

  **Two ways to resolve in the doc**, pick one:
  1. **Add per-container opt-out instructions.** Tell the operator to also add `security_opt: ["no-new-privileges:false"]` to the `workspace` service in `template/.devcontainer/compose.yml`. Daemon default still hardens rogue ad-hoc `docker run` and the supabase-runner sibling + spawned supabase containers; only the trusted workspace opts back in. Better security posture, but creates a divergence operators need to maintain.

  2. **Drop NNP from the recommendation entirely** for Option 3 setups. Under Option 3 the workspace has no docker socket, so the threat NNP is supposed to mitigate (compromised dep → `docker run -v /Users:/h alpine`) is already closed by no-socket + File Sharing allowlist. NNP becomes belt-and-suspenders that breaks more than it adds. Cleaner for the operator; loses defense-in-depth against an unlikely path.

  **Architectural alternative (deferred)**: refactor the devcontainer so postStartCommand doesn't need sudo — e.g. run init-firewall.sh + init-devshop.sh as root via a tini-wrapped entrypoint, or move the firewall init into `initializeCommand` (host-side) and the devshop refresh into a USER-root step in the Dockerfile. Eliminates the conflict at the root, makes NNP straightforwardly compatible. More invasive than fixing the doc.

  **Edit targets**: `kit/docs/guide/macos-host-setup.md` (the Step 2 JSON block + the rationale paragraph), `kit/docs/guide/local-supabase-compose-isolation.md` (the matching row in its Option 3 hardening table), `kit/notes/security/local-supabase-isolation-options.md` (the `daemon.json` snippet at line 61).

  [container-infrastructure, doc-bug, surfaced-by lalista-operator-2026-05-02]

- [ ] **When GitHub re-enables Checks permission on fine-grained PATs, revert `/ak-build` Phase 5 to `gh pr checks`.** The Check Runs API isn't accessible to fine-grained PATs — GitHub removed the Checks permission after initial release (see https://github.com/orgs/community/discussions/129512). Phase 5 currently uses `gh run list` + `gh run watch` which goes through the Actions API and works with `Actions: Read`. When the Checks permission returns:
  - Swap `gh run list --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId' | xargs gh run watch --exit-status` back to `gh pr checks "$PR" --watch --fail-fast` in `.claude/skills/devshop/build/SKILL.md § Phase 5.2`.
  - Update `.claude/skills/devshop/new-project/SKILL.md § Step 4` to add `Checks: Read` to the required PAT permissions.
  - Remove the link-to-discussion rationale from both files.

- [ ] **Pin template base image by digest.** `template/.devcontainer/Dockerfile` currently uses `FROM mcr.microsoft.com/devcontainers/javascript-node:20` — an unpinned tag. Every rebuild could theoretically pick up a different upstream base (security patches, package-universe drift). Every apt + binary install below inherits the drift. Tags are mutable; digests are not.

  **Fix**: resolve the current digest (`docker buildx imagetools inspect mcr.microsoft.com/devcontainers/javascript-node:20 | grep -m1 Digest`) and pin it:

  ```dockerfile
  FROM mcr.microsoft.com/devcontainers/javascript-node:20@sha256:<digest>
  ```

  Apply to:
  - `template/.devcontainer/Dockerfile`
  - Document a refresh cadence (when to re-resolve the digest — e.g. when Microsoft ships a base-image security advisory, or every N months).

  Surfaced during lalista PR 2 hardening discussion — deferred because we didn't have registry access from the sandbox to resolve the digest. User should run the resolve command from their host.

- [ ] **Upstream fix: gstack `browse` daemon Chromium version autodetection.** The compiled daemon is pinned to `chromium-1208` path; Playwright may install newer versions (1217 observed). `/ak-pre-ship` Phase 0 now creates a symlink as a workaround, but the daemon should discover the highest-version dir under `~/.cache/ms-playwright/` on its own. File upstream in gstack, remove the symlink workaround when the fix ships.

- [ ] **Route init tracking out of project BUILD-LOG.** Currently `ak-new-project` logs all 25 init steps into the project's `BUILD-LOG.md`, mixing devshop infrastructure with project setup. BUILD-LOG should only contain entries from `/ak-build` (feature ships).

  **Changes needed:**
  1. `ak-new-project/SKILL.md`: write INIT-TRACKER to `/devshop/kit/notes/projects/<name>.md` instead of project root
  2. `session-start.sh`: read init progress from devshop notes file (not BUILD-LOG Status section); surface both project build status and init progress
  3. `init-devshop.sh`: remove BUILD-LOG.md creation (lines 77-81) — `ak-new-project` copies it from template during Phase A
  4. `template/BUILD-LOG.md`: remove init-tracking Status fields (`Current phase`, `Current step`, `Remaining`); keep only `Last build`
  5. Separate ak-new-project steps into devshop-infra vs project-setup so only project steps appear in project-facing records

  **Devshop infrastructure steps** (go to `/devshop/kit/notes/projects/<name>.md`):

  | Step                                     | Why devshop-specific                     |
  | ---------------------------------------- | ---------------------------------------- |
  | 1. Check binary versions                 | Devshop-managed binaries in devcontainer |
  | 4. [HUMAN] Fill credentials              | Devshop `.devcontainer/.env` pattern     |
  | 6. [HUMAN] Add firewall domains          | Devshop firewall infrastructure          |
  | 7. [HUMAN] Rebuild devcontainer          | Devshop container lifecycle              |
  | 8. Disable turbo telemetry               | Container env config                     |
  | 9. Install gstack                        | Devshop tooling dependency               |
  | 19. Enable doc enforcement hooks         | Devshop convention enforcement           |
  | 21. [HUMAN] Lock security-critical files | Devshop security model                   |
  | 25. Run /cso baseline audit              | Devshop quality gate                     |

  **Project setup steps** (could appear in project-facing records):

  | Step                                      | What it does                      |
  | ----------------------------------------- | --------------------------------- |
  | 2. Customize project docs                 | README, PRODUCT-ROADMAP           |
  | 3. [HUMAN] Create accounts                | Vercel, Sentry, PostHog, Supabase |
  | 5. [HUMAN] Add GitHub Secrets + Variables | Repo configuration                |
  | 10-16. Scaffold packages + apps           | Core project code                 |
  | 17. Run /setup-deploy                     | Deploy configuration              |
  | 18. Create project CLAUDE.md              | Project docs                      |
  | 20. Update .gitleaks.toml                 | Project-specific secret patterns  |
  | 22. Create keepalive.yml                  | Project CI                        |
  | 23. [HUMAN] Service quota alerts          | Project ops                       |
  | 24. [HUMAN] Branch protection             | Repo configuration                |

  [post-separation, documented 2026-04-16]

- [ ] Investigate scoping node user's sudo access — base image gives full passwordless sudo, which means Claude could bypass root-owned file protections via `sudo chown`. See `kit/notes/sudo-hardening.md` for analysis and approach. [post-Phase-1]
- [ ] **Instrument subagent drift rate, then decide whether to codify a cleanup pattern.** Phased plan in [`kit/notes/roadmap/subagent-cleanup-pattern.md`](notes/roadmap/subagent-cleanup-pattern.md). Phase 1 adds a deterministic bash logger (`subagent-drift-log.sh`) to `/ak-build` and `/ak-implement` `Agent()` call-sites that snapshots repo state before + after each subagent spawn and writes deltas to a gitignored log. Phase 2 (contingent on Phase 1 data) codifies a clean-state prompt block in `kit/docs/guide/agents.md` + optional helper script `check-subagent-cleanup.sh` — parent verifies subagent-left state against baseline and negotiates via `SendMessage` if drift lacks a structural reason. **Decision gate after ~30 spawns**: <5% drift → skip Phase 2; 5–15% → prompt block only; >15% or multi-session accumulation → full helper + bats tests. **Hard guardrail**: pattern MUST stay at prompt/agent-to-agent layer — a `SubagentStop` hook would recreate the hook-injection bug the 2026-04-19 hook migration killed. [ergonomics, measured-before-built, documented 2026-04-19]

- [ ] **`prTextHygieneReason` reviewer auto-rejects even when PR text is fine.** `.husky/pre-push` Check 1 always invokes `adversarial-review.sh prTextHygieneReason` (formerly `prDescStaleReason`, renamed 2026-05-19 when title-readability + body-shape were folded in) on non-trivial commits + open PR; when no bypass reason is set the reviewer short-circuits to FAIL even when the PR title is readable, the body matches the commits, AND the body has the required `## Product update` + `## Engineering details` structure (adversarial prompt item 2(a): _"PR description genuinely matches the commits — the reviewer is wrong"_). Surfaced during hook-migration verification — pushed an aligned-description PR update and still got blocked with `"No reason given — automatic rejection."`

  **Full analysis** (alternatives A–E, current lean B + E, decision trigger): see [`kit/ROADMAP.md` § "PR-description staleness check — layer + approach decision"](ROADMAP.md#pr-description-staleness-check--layer--approach-decision). Trigger to act: post-PR-3 (`/ak-build core-flows`) data on the false-positive rate of the current always-fires implementation. [ergonomics, 2026-04-19]

- [ ] Upgrade root ESLint from v9 to v10 — blocked by `eslint-config-next` which depends on `eslint-plugin-react@7.x` (uses `getFilename()` API removed in ESLint 10). **Trigger**: when Next.js ships an `eslint-config-next` version that supports ESLint 10, bump root `eslint` + `@eslint/js` to `^10` across all projects. Check: `npm info eslint-config-next peerDependencies` for eslint range. [blocked-upstream]
- [ ] Check if `anthropics/claude-code#22583` is resolved — CLAUDE.md from `additionalDirectories` not loaded despite `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1`. Workaround in `session-start.sh` injects `/devshop/CLAUDE.md` via hook context. Remove workaround when fixed. [blocked-upstream]
- [ ] **Deny rules with absolute paths don't fire for paths outside cwd.** Confirmed empirically 2026-04-16 during a security audit session. From cwd=`/workspace`: `Edit(/workspace/.devcontainer/devcontainer.json)` was DENIED (matched by the relative `**/.devcontainer/*` glob, normalized against cwd), but parallel `Edit(/devshop/.devcontainer/devcontainer.json)` and `Edit(/devshop/template/.devcontainer/devcontainer.json)` calls **succeeded** — neither the relative `**/.devcontainer/*` rule nor the explicit absolute `Edit(/devshop/.devcontainer/*)` and `Edit(/devshop/template/**)` rules fired. Claude Code's permission matcher appears to be cwd-anchored: relative globs only match paths under the current workspace root, and absolute-path deny patterns for other `additionalDirectories` targets aren't enforced.

  **Scope of affected deny rules** (in `/devshop/.claude/settings.json`) — all of these look enforced but don't fire from the "wrong" cwd:
  - `Edit(/devshop/.devcontainer/*)` + `Write(/devshop/.devcontainer/*)`
  - `Edit(/devshop/.claude/settings.json)` + `Write(/devshop/.claude/settings.json)`
  - `Edit(/devshop/.dcg.toml)` + `Write(/devshop/.dcg.toml)`
  - `Edit(/devshop/kit/scripts/**)` + `Write(/devshop/kit/scripts/**)` (relative `kit/scripts/**` variants removed in `fix/kit-scripts-deny-rule-investigation` — see `specs/kit-scripts-deny-rule-investigation/spec.md`)
  - `Edit(/devshop/template/**)` + `Write(/devshop/template/**)`
  - `Read(/devshop/.devcontainer/.env)` + `Read(/workspace/.devcontainer/.env)`

  (Symmetric assumption: when cwd=`/devshop`, the `/workspace/...` absolute denies likewise don't fire. Not directly verified but same matcher logic.)

  **Now mitigated at the filesystem layer (as of v1.5.5, 2026-04-16):** critical files are `root:root 644` and parent dirs have the sticky bit (`chmod 1755`) on both repos' `.claude/` and `.devcontainer/` plus `template/.devcontainer/`. So `settings.json`, `.dcg.toml`, `devcontainer.json`, `Dockerfile`, `init-*.sh`, `.env`, and all `kit/scripts/*.sh` are kernel-protected against node regardless of which cwd Claude is working from. The deny rules become belt-and-suspenders with a known cwd-asymmetric limitation.

  **What remains vulnerable** — non-critical cross-repo files still editable from any cwd: `/devshop/kit/notes/*.md`, `/devshop/CLAUDE.md`, `/devshop/kit/docs/*.md`, `/devshop/README.md`. These aren't filesystem-locked. Commit guards catch changes before they reach remote, but in-session edits happen freely. This is acceptable for the doc/notes files but means the absolute-path deny rules in `settings.json` read more protectively than they actually behave.

  **Resolution options** (pick when triggered):
  - **A. Document the limitation in-place**: add a comment block above the absolute-path deny rules in `settings.json` noting they only enforce when cwd matches. Also update `guide/security.md` §"Layer 3" to spell out the cwd-relativity. Low effort, calibrates reader expectations.
  - **B. File upstream issue**: report to `anthropics/claude-code` — "absolute-path Edit/Write deny rules don't enforce when target is outside the primary working directory, even when the target is in `additionalDirectories`." Include the minimal repro from this session.
  - **C. Custom PreToolUse hook**: a bash script that parses Edit/Write tool calls and rejects based on a path-matcher that handles absolute paths correctly. Bypasses Claude Code's matcher entirely for the paths we care about. More robust but more moving parts.
  - **D. Rely on filesystem + drop absolute denies**: since Layer 2 (root ownership + sticky bit) is the real defense after v1.5.5, remove the `Edit(/devshop/...)` rules from `settings.json` to stop giving false confidence. Keep relative forms as advisory. Accepts that non-critical files are editable cross-cwd.

  **Trigger**: when someone files upstream and it's fixed (resolves automatically), OR when a real attack/mistake exploits the gap (bump priority), OR when a second audit surfaces the false-confidence cost. Until then, filesystem locks carry the load.

  [blocked-upstream, security-hygiene, documented 2026-04-16]

- [ ] **`/home/node/.gstack/` not volume-backed — container rebuild wipes gstack state.** [v+] The gstack state dir (`~/.gstack/`) holds per-project fingerprints, analytics, learnings, session timeline, and review history. The `claude-code-config-${devcontainerId}` volume mount only covers `/home/node/.claude/`, not `/home/node/.gstack/` — so every container rebuild wipes gstack state, even though nothing about the project changed.

  **Concrete impact**: `/land-and-deploy` Step 1.5 checks `~/.gstack/projects/$SLUG/land-deploy-confirmed` to decide whether to run the full dry-run walkthrough. After a rebuild, the file is gone and the skill re-presents the full "teacher mode" dry-run table (deploy platform, prod URL, what-will-happen) asking for re-approval, even though the deploy config is byte-identical to the previous approved version. Not broken, but annoying — one extra confirmation every rebuild. Observed on lalista PR-15 and PR-17 post-merge cycles (2026-04-23).

  Same footgun affects any gstack state future skills accumulate: timeline history, learning records, analytics trends.

  **Fix options**:
  1. Add `/home/node/.gstack` to the template `devcontainer.json` volume mount list (cleanest — one line, maps to a named volume like `claude-code-gstack-${devcontainerId}`).
  2. Move gstack state under `/home/node/.claude/gstack/` which IS volume-backed (cleaner from a "one mount, many state dirs" perspective, but requires touching gstack binaries that resolve `$GSTACK_HOME`).

  **Edit targets**: `template/.devcontainer/devcontainer.json` (option 1), or `kit/docs/guide/ops.md` + gstack skill files for the env var override (option 2).

  [v+, deploy-hygiene, surfaced-by lalista-PR17-land, 2026-04-23]

- [ ] **`git ls-remote` via HTTPS-with-token URL produces garbled output against abra-kadabra.** [v+] `/ak-clean-branches` Phase 1 enumerates remote branches via `git ls-remote "https://x-access-token:${TOKEN}@github.com/meirmsn/abra-kadabra.git" 'refs/heads/*'`. Output arrived as broken fragments ("Permission", "Could", "make", "the" — one word per line) instead of the expected `<sha>\trefs/heads/<branch>` rows. Fetch with the same URL worked fine; only ls-remote broke.

  **Workaround**: swap to `gh api repos/meirmsn/abra-kadabra/branches --paginate --jq '.[].name'`, which returns clean branch names and respects PAT scope. Already used this path in the lalista-PR17 cleanup run.

  **Hypothesis**: token contains a special character (`$` / newline / URL-reserved) that's interpreted by the shell or by git's URL parser, breaking the argv. `/etc/devshop-env` is `echo DEVSHOP_GITHUB_TOKEN=$TOKEN` into a file — if the token has an embedded newline or `$` it'd mangle. Low-effort fix is switching the skill to `gh api` unconditionally; higher-effort is sanitizing the URL construction.

  **Edit targets**: `.claude/skills/devshop/clean-branches/SKILL.md` (swap Phase 1 remote enumeration to `gh api`).

  [v+, tooling-nit, surfaced-by lalista-PR17-cleanup, 2026-04-23]

- [ ] **Filesystem-lock erosion via git operations.** [v1] `init-devshop.sh` runs at container start as root and locks security-critical scripts (`chown root:root + chmod 644` on the recursive `find $DEVSHOP/kit/scripts/ -name '*.sh'`). The lock is intended as Layer 2 of the agent-bypass-prevention model (Layer 1 = settings.json deny rules). But the lock erodes whenever git modifies a locked file: `git checkout`, `git merge`, `git pull`, `git rebase` etc. all rewrite file content via the running user (`node`), and the rewritten file is recreated with `node:node` ownership. After that, the root lock is gone until the next container restart — and the agent (running as `node`) can `Edit` / `Write` the file freely.

  **Empirical state at v1.20.0** (devshop main, post-session 2026-04-27): `kit/scripts/release.sh` + `kit/scripts/init-devshop.sh` + `kit/scripts/commit-hooks/check-clean-tree.sh` etc. are still `root:root 644` (haven't been git-modified since last container start). But `kit/scripts/commit-hooks/commit-guard.sh` and `kit/scripts/adversarial-review.sh` are `node:node 644` — both are actively-evolving files that git has rewritten in recent sessions. The lock loop ran at container start and locked them then; subsequent git activity un-locked them. This was directly exploited (without intent) in the 2026-04-27 session: cross-repo blocking check removal edited `commit-guard.sh` + `adversarial-review.sh` via the standard `Edit` tool with no friction at the filesystem layer. Layer 1 (settings.json deny `kit/scripts/*` single-segment glob) had a separate gap that didn't cover `commit-hooks/`; that gap was fixed in the same session by widening the glob to `kit/scripts/**`. With Layer 1 hardened, Layer 2's erosion is the remaining vector.

  **Why v1, not v0**: the model still works for any file git hasn't recently touched, and the single-character Layer 1 fix landed in v1.20.0 closes the immediate concrete attack surface (any kit/scripts subdirectory script is now blocked by deny rules at the Claude Code permission layer, regardless of filesystem ownership). Layer 2 erosion is a defense-in-depth gap, not a load-bearing one once Layer 1 is correct. v1 is the right tier — fix before second-project onboarding so two-layer defense is real, not aspirational.

  **Implementation options** (pick one or combine):
  1. **Re-lock on commit**: add a `kit/scripts/init-devshop.sh`-equivalent lock loop to a `pre-commit` or `post-merge` git hook. Idempotent (chown is a no-op when ownership is already correct); cheap; runs in every interactive git operation that could erode the lock. Caveat: requires sudo to chown to root, which means the hook either needs passwordless sudo (already true in devshop devcontainer per init-devshop.sh's sudoers config) or the hook's chown step gets gated behind a condition.

  2. **Use immutable bit instead of ownership**: `chattr +i $f` makes the file immutable even to root. git can't modify an immutable file at all (write fails). This removes the erosion path entirely — git rewrites become hard errors instead of silent ownership-flips. Caveat: requires `CAP_LINUX_IMMUTABLE` in the container; need to verify devcontainer has it.

  3. **Check + restore at session start**: extend `kit/scripts/session-start.sh` to verify that all scripts in the lock list are still root:root, and re-lock any that aren't (with sudo). This catches erosion at session boundaries rather than every commit. Slightly less defense-in-depth than (1) but cheaper and simpler. Caveat: gap window between erosion and next session-start.

  4. **Move logic out of locked files**: rewrite `commit-guard.sh` etc. as a thin wrapper that exec's a binary or jq config. The binary/config is signed/verified rather than just owned. Higher complexity.

  Recommend (1) + (3) combo: session-start re-lock as a baseline + pre-commit re-lock as the immediate-correction layer.

  **Edit targets**: `kit/scripts/init-devshop.sh` (factor out the lock loop into a reusable function), `kit/scripts/session-start.sh` (call the lock function), `template/.husky/pre-commit` (call the lock function before guard checks fire). Update `kit/docs/guide/security.md` to document Layer 2's actual semantics (locked-at-session-start, re-locked-at-commit) rather than the current (incorrect) "All `kit/scripts/*.sh` are also root-locked" claim that doesn't survive git operations.

  **Cross-ref**: 2026-04-27 session — the cross-repo check removal exercised this gap directly. Fix landed in v1.20.0 was Layer 1 only (`kit/scripts/*` → `kit/scripts/**` in settings.json deny rules). Layer 2 erosion remains. See devshop commit history for the v1.20.0 Layer 1 fix.

  [v1, security-defense-in-depth, surfaced-by 2026-04-27-session, 2026-04-27]

- [ ] **Pre-ship gate: middleware-matcher public-asset coverage check.** When `apps/web/middleware.ts` exists and uses a negative-lookahead matcher (`'/((?!...).*)'` shape), scan `apps/web/public/` for root-level static assets and warn if any aren't covered by the matcher's exclusions. Specifically: any file with `.png`/`.jpg`/`.jpeg`/`.gif`/`.svg`/`.webp`/`.ico` extension at the public root that isn't matched by an exclusion pattern → warn. Catches the failure mode where browsers (and Gmail's image proxy) get auth-walled when fetching public assets, with no error visible to the developer.

  **Context**: lalista PR 45 (2026-05-05). Chapter 1l (2026-05-04) shipped an inline email-template logo at `https://lalista-ten.vercel.app/lalista-email-logo.png` (later `lalista.store/...`). Middleware matcher excluded `_next/static`, `_next/image`, `favicon.ico`, `manifest.json`, and the `/icons/` folder — but NOT root-level public images. Result: every confirmation/recovery email rendered Gmail's blue-square question-mark placeholder where the lalista logo should be, because Gmail's image proxy hit the auth wall and got HTML back instead of PNG. Bug pre-existed since chapter 1l ship; surfaced 2026-05-05 only because the lalista.store custom-domain cutover triggered a smoke-test of the rendered email body. Fix in PR 45 extended the negative-lookahead with `.*\.(?:png|jpg|jpeg|gif|svg|webp|ico)$`.

  **Why this generalizes**: every Next.js + Supabase Auth project ships a middleware that gates auth, and most ship root-level public assets (icons, OG images, robots.txt, email-template logos). The default Next middleware matcher example in the official docs only excludes `_next/static`/`_next/image`/`favicon.ico` — same gap. Without this gate, the next project that adds a new email-template logo or PWA-related root asset re-discovers the bug.

  **Implementation**: bash script in `kit/scripts/preship/middleware-public-coverage.sh`, invoked from `/ak-pre-ship` (likely as a Gate alongside RLS coverage). Parse the matcher's negative-lookahead string, list `apps/web/public/*.{png,jpg,jpeg,gif,svg,webp,ico}` files, fail-with-recipe if any aren't covered. Recipe is the regex pattern that would close the gap.

  **Edit targets**: `kit/scripts/preship/middleware-public-coverage.sh` (new), `.claude/skills/devshop/pre-ship/SKILL.md` (add gate invocation). Reference implementation: lalista commit `ec62818` in PR 45.

  [pre-ship-gate, surfaced-by lalista-PR45-cutover-smoke-test, 2026-05-05]

- [ ] **Email-template visual-QA gate / convention.** When PR diff touches files matching `supabase/templates/*.html` (or future analogues — `apps/*/email-templates/**`, `packages/*/emails/**`), require the test plan to include a "rendered email screenshot" attachment OR an explicit "trigger fresh email + open in real client" step. Prevents shipping email-template changes that pass typecheck/lint but render broken in actual mail clients (logo missing, layout breaking, fonts not falling back, links wrong).

  **Context**: lalista chapter 1l (2026-05-04, PR #43) shipped two new branded email templates (`confirmation.html`, `recovery.html`) and a logo asset. Code review + visual review of the HTML in a browser passed. Nobody triggered an actual email and opened it in Gmail — so nobody saw that the inline logo was broken (Gmail's image proxy hit the auth wall, blue-square placeholder rendered). Bug shipped silently for 24 hours until lalista.store cutover smoke test triggered a fresh email and the operator visually saw the broken logo.

  **Why visual QA is non-substitutable**: HTML in a browser ≠ HTML in Gmail (or Outlook, or Apple Mail). Email clients aggressively rewrite/strip styles, proxy images, sandbox CSS, override colors in dark mode, and rate-limit external fetches. The only way to know an email template renders correctly is to send a real email and open it in a real client. Static review catches HTML errors, not deliverability or rendering quirks.

  **Why this generalizes**: every project that ships transactional emails will have email templates. Every operator will be tempted to skip "send a real email and open it" because it's a manual step in an otherwise-automated pipeline. Encoding the convention prevents the omission.

  **Implementation options**:
  1. **`/ak-spec` checkpoint** — when spec adds/touches email templates, prompt for a "rendered email screenshot will be attached to PR test plan before merge" commitment in the spec's test plan section. Soft enforcement via spec review.
  2. **`/ak-pre-ship` gate** — when diff touches `supabase/templates/*.html`, require a `specs/<feature>/email-rendered.png` attachment (or similar evidence) before merge. Hard enforcement.
  3. **`/ak-test-review` checkpoint** — when reviewing tests, flag the gap if email-template files are touched but no E2E test exercises an end-to-end send (paired with reading the rendered output via mailpit + screenshot).

  Option (2) has highest leverage since /ak-pre-ship runs on every PR. Option (1) prevents the issue at the planning stage. Best is probably both.

  **Edit targets**: `.claude/skills/devshop/pre-ship/SKILL.md` (add gate, possibly conditional on `supabase/templates/**` or `apps/*/emails/**` glob), `.claude/skills/devshop/spec/SKILL.md` (add test-plan checkpoint when emails touched). Reference: lalista PR 45's "Smoke test from a fresh inbox" line in the test plan — that's the convention codified.

  [pre-ship-gate, spec-checkpoint, surfaced-by lalista-chapter-1l-broken-logo, 2026-05-05]

- [ ] **Generalize lalista's `scripts/ci-rollback-explain.sh` + `scripts/ci-type-drift.sh` into devshop kit-level scripts.** Both are project-specific in implementation but the patterns are reusable: every Supabase project with `-- ROLLBACK:` blocks in migrations wants the round-trip EXPLAIN check, and every project with codegen'd types (`supabase gen types typescript`) wants the drift check. Today these live in lalista's `scripts/` folder, hand-edited, and would need to be re-derived for any second project that adopts the devshop.

  **Context**: surfaced 2026-05-05 in PR #46 review (lalista email-logo cutover follow-up). The user noted "those other 2 scripts in there look like hooks that should be devshop level." Correct — they're CI gates, not project-specific business logic.

  **Project-specific bits today** (to abstract):
  - Hardcoded paths: `supabase/migrations/*.sql`, `packages/core/src/supabase.types.ts`, the local Supabase REST URL, project-specific seed loading
  - Project-specific assumptions: lalista runs Supabase via `pnpm db:start` (the compose-isolation runner relay); other projects might use direct host-Supabase or skip-supabase variants

  **Shape for kit-scripts version**:
  - `kit/scripts/ci/rollback-explain.sh` — accepts the migrations-glob + the local Supabase URL as args (or reads from CLAUDE.md § Deploy Configuration like `/setup-deploy` does). Falls back to project-default paths.
  - `kit/scripts/ci/type-drift.sh` — same pattern; configurable types-file path + supabase project ref.
  - `template/.github/workflows/ci.yml` — references `kit/scripts/ci/...` paths (cross-repo: workflows in projects, scripts in devshop kit). Or copied per-project via `/ak-new-project` Step 17 (the `/setup-deploy` path).

  **Migration**: existing projects (lalista) keep their hand-edited copies until the next `/ak-migrate-project` adoption sweep, OR the `template/scripts/` shipped variant gets a clean diff against lalista's that surfaces drift to address. The "second project adopts devshop" event is the natural trigger to do this work — until then lalista's are functional.

  **Edit targets**: `template/scripts/ci/{rollback-explain,type-drift}.sh` (new), `template/.github/workflows/ci.yml` (path updates), `.claude/skills/devshop/new-project/SKILL.md` (Step 17 — sync these alongside `/setup-deploy`'s output).

  [v1, kit-script-generalization, surfaced-by lalista-PR46-review, 2026-05-05]

- [ ] **lint-staged stash backup chokes on rename + new-symlink-at-old-path.** Surfaced 2026-05-07 during `/ak-merge-devshop`'s post-ship layout fix. When a single staging round combines (a) `git mv OLD/file -> NEW/file` AND (b) a new symlink at OLD pointing to NEW, the pre-commit hook's lint-staged backup fails with `error: 'OLD/file' is beyond a symbolic link` from `git stash` itself. This is a git-plumbing limitation, not strictly a lint-staged bug — but lint-staged unconditionally runs `git stash` for backup, so the failure surfaces as a hook block.

  **Blast radius**: blocks `git merge --squash` whenever the squashed diff has this combination. Any future skill with a "move to canonical layout + symlink-at-old-path-for-back-compat" diff hits this. Caught during the `/ak-merge-devshop` layout-fix's failed squash; fallback was a 2-commit ff-merge of the fix branch (loses the squash convention).

  **Implementation options**:
  1. **lint-staged config tweak** — set `stash: false` (suppresses the stash backup entirely; loses the rollback-on-failure safety net but unblocks the rename+symlink combo).
  2. **Custom backup strategy** — replace lint-staged's default with a thin wrapper that uses `git diff > /tmp/backup.patch` instead of `git stash`. Preserves the rollback safety, dodges the symbolic-link limitation.
  3. **Detect-and-defer in /ak-merge-devshop** — Phase 2 detects the rename+symlink-at-old-path combo in the staged diff before invoking commit; suggests the ff-merge fallback automatically. See companion entry below.

  Option (1) is fastest but reduces safety; option (2) is the cleanest long-term fix; option (3) is complementary (fixes the user-visible blast at the skill level even if the hook stays as-is).

  **Edit targets** (option 1): `package.json` lint-staged config OR `.lintstagedrc` (whichever the repo uses). **Edit targets** (option 2): replace lint-staged with a thin wrapper script under `kit/scripts/`. **Edit targets** (option 3): see companion entry.

  [v0+, hook-bug, surfaced-by ak-merge-devshop-smoke-test, 2026-05-07]

- [ ] **`/ak-merge-devshop` Phase 2: detect rename-plus-symlink-at-old-path combo and fallback to ff-merge.** Companion to the lint-staged stash bug above. When the skill's Phase 2 attempts `git merge --squash` and the staged diff includes both `R OLD -> NEW` and `A OLD` (a new symlink at the rename source), the squash WILL fail at commit time on the lint-staged stash bug. The skill should detect this combo BEFORE attempting the squash, surface the issue, and offer the ff-merge fallback inline.

  **Behavior shape**:
  - After `git merge --squash <branch>` stages changes, scan `git diff --cached --name-status` for matching `R<sim>` + `A` entries where the `A` path equals the `R`'s source path.
  - On hit: abort the squash (`git reset`), print a one-screen explanation referencing this TODOS entry + the lint-staged-stash entry, AND surface ff-merge as an alternative ("the fix branch's commits will land as-is on main, preserving N separate commits instead of squashing — same end-state on the file system, different git history shape").
  - On the operator's confirmation, run `git merge --ff-only <branch>` instead of the squash.

  **Why detect-and-defer is the right shape**: the hook bug is harder to fix (option 2 from the companion entry); `/ak-merge-devshop`'s user surface is where operators feel the pain; surfacing the workaround at skill-invocation time avoids the manual recovery dance every time.

  **Edit targets**: `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 2` adds the detection block; new `## Known limitations` section documents the rename-plus-symlink combo; `kit/tests/util-ak-merge-devshop.bats` adds a content-validation test for the detection prose.

  [v0+, skill-improvement, surfaced-by ak-merge-devshop-smoke-test, 2026-05-07]

- [ ] **Root-cause investigation: operator stashes vanish silently during `/ak-merge-devshop` flows.** [v0+] Symptom and recovery recipe are documented (recovery: `kit/docs/guide/hooks.md § Practical recipes § Recovering a vanished stash`; symptom + worked incident: `.claude/skills/devshop/merge-devshop/SKILL.md § Known limitations § Operator stashes can vanish silently mid-merge`; footgun pointer: `CLAUDE.md § Known Footguns`). What's still pending: confirming the actual mechanism so the upstream fix can land.

  **Why the hypothesis is unsettled**: lint-staged is the leading suspect — it's the only routine `git stash` caller on the pre-commit path (config in `package.json` `"lint-staged"`, invoked from `.husky/pre-commit:5`) — but the simple "lint-staged drops operator stash by index confusion" theory doesn't fit because lint-staged v15 stores its backup under a separate `refs/lint-staged/*` namespace, not `refs/stash`. The two ref namespaces don't directly collide. Some interaction (perhaps during pop-on-failure, or via a hook that runs `git stash drop` against the wrong ref) is the working assumption.

  **First action to reproduce**: `GIT_TRACE=1 git stash push -m "test"` immediately before a known-to-trigger operation (`git checkout main && git merge --ff-only origin/main` while a pre-commit hook fires elsewhere), then `git stash list` after. If the named stash is gone, capture the GIT_TRACE log around the disappearance — should show whether `git stash drop` / `git update-ref -d` fired and what called it. Pair with `pnpm exec lint-staged --debug` if the trigger involves a commit; the lint-staged debug log enumerates its own stash operations.

  **Candidate fixes once root cause is known**: `package.json` lint-staged `"stash": false` config (suppresses the backup mechanism entirely — loses the rollback-on-failure safety net but eliminates the suspect path), OR a thin `kit/scripts/` wrapper that replaces lint-staged's stash with `git diff > /tmp/backup.patch` (preserves rollback, dodges the ref-machinery interaction). Both candidates also apply to the rename+symlink lint-staged entry above — fixing either may close both.

  [v0+, hook-bug, surfaced-by feat/gstack-artifact-symlink-redirect-merge, 2026-05-20]

- [ ] **Port the `tap-feedback` press-state contract from lalista into the template's `globals.css`.** Lalista PR (2026-05-13, polish bundle) added a low-specificity `:where(button, a[href], [role="button"]):active` rule that scales 0.97 + drops brightness to 0.9 within `--duration-micro` (75ms), with `touch-action: manipulation` to kill iOS's 300ms tap delay. Without it, taps on iOS PWA give no native press cue and users assume the app froze (or double-tap). Every devshop-generated project should ship this on day one.

  **Why generalize**: this is a stack-wide pattern (touch-input UX on PWA), not lalista-specific — it should live in the kit so new projects don't have to discover the iOS PWA "feels frozen" problem from a soak. The CSS is ~12 lines and depends only on a `--duration-micro` token, which template projects already ship via the design-system token CSS layer.

  **Edit targets**:
  - `template/apps/web/app/globals.css` (or wherever the template puts its global stylesheet) — copy the `Tap feedback` block verbatim from `lalista/apps/web/app/globals.css`. Keep the `:where(...)` wrapper (zero-specificity, easy to override per component) and the `.no-tap-feedback` escape hatch class.
  - `kit/docs/guide/` — short guide entry "Touch feedback" under the design-system / UX section explaining the contract (scale + brightness drop on press, fires within one frame, inherited by every `<button>` / `<a href>` / `[role="button"]`, opt-out via `.no-tap-feedback`). Reference DESIGN.md analog in lalista if useful.
  - `kit/CHANGELOG.md` — note the new template baseline.

  **Validation**: after porting, a fresh `/ak-new-project` should produce a project where every button/link visibly presses in on tap with no per-component opt-in needed. Lalista's `tap-feedback` rule has been dogfooded for the duration of the polish bundle — promote it to standard once it's been stable for one full lalista release cycle.

  [ui, design-system, touch-input, surfaced-by lalista-polish-2026-05-13]

- [ ] **`/ak-check-docs-and-tests` Step 1 scaffolds `specs/<feature>/review.md` even for doc-only commits with no source surface — leaves orphan stubs.** Witnessed twice in two sessions:
  - `/ak-merge-devshop` for devshop `aa0b498` (roadmap-supabase-port-registry, doc-only) → left `specs/roadmap-supabase-port-registry/` empty dir.
  - `/ak-merge-devshop` for devshop `0b49682` (plan-synthesis, doc-only) → left `specs/plan-synthesis/review.md` 28-byte stub (`# Review — plan-synthesis`).

  Both runs triggered Phase 1 audit. The orchestrator's Step 1 says "If the resolved feature dir doesn't exist: scaffold an empty stub so the appender has a target." Then Step 4's appender writes the `## Audit N` section. But when the appender runs (after `/ak-docs-review` + `/ak-tests-review`), Step 4 also doesn't commit — and the operator typically discards the working-tree change to clear `gh pr merge --delete-branch`'s `git checkout main` (per the separate TODOS entry "/ak-check-docs-and-tests orchestrator appends `## Audit N` to `review.md` but never commits the change"). For devshop merges that path is shorter — the audit may not run to completion at all if the diff is purely tracker-shaped (PLAN/TODOS/ROADMAP), since both sub-skills emit "clean — no findings" trivially.

  **Fix shape**: short-circuit Step 1 when the diff has zero non-tracker / non-doc surfaces. Detection: `git diff --name-only "$RANGE"` returns ONLY paths matching `^(PLAN|TODOS|BUILD-LOG|PRODUCT-ROADMAP|DEPS-WATCH)\.md$|^kit/(TODOS|ROADMAP|notes|version)|^kit/docs/CHANGELOG\.md$` (or the devshop-self analogues). If so, skip scaffold + skip sub-skill invocation + print "✓ audit short-circuited: diff is tracker-only, no source surface to audit." This is consistent with the existing carve-outs in `/ak-docs-review § Section A` and `kit/scripts/commit-hooks/check-docs-coverage-{project,devshop}.sh` — the audit machinery already knows these paths don't trigger coverage, so the meta-audit should follow suit.

  **Edit target**: `/devshop/.claude/skills/ak-check-docs-and-tests/SKILL.md § Step 1` (add the short-circuit clause near "If the resolved feature dir doesn't exist").

  **Cleanup**: existing orphan dirs (`specs/roadmap-supabase-port-registry/`, `specs/plan-synthesis/`) — both deleted at the `/ak-merge-devshop` boundary for plan-synthesis (this session).

  **Severity**: low (the stubs are untracked and harmless, never reach `main`) — but the noise compounds (one orphan per doc-only `/ak-merge-devshop` run), the pattern is invisible to anyone who doesn't check `git status` post-merge, and the short-circuit is a few lines.

  [low, skill-improvement, ak-check-docs-and-tests, surfaced-by ak-merge-devshop-doc-only-runs-2026-05-15, 2026-05-15]

- [ ] **`/ak-pre-ship` + Phase 5.9 visual-evidence deferrals get rubber-stamped with hand-wave rationales instead of verified causes.** Surfaced 2026-05-15 on home-os PR #19 (`triage-route-handler`): Gate 4 (responsive + theme) and Gate 13 (hero shots) deferred capture of the new `/cards/[id]` screen citing "Node 20 + `@supabase/realtime-js` ws() interop blocks programmatic seed". The rationale was **factually wrong** — the actual blocker was the firewall rebound-port mismatch (a known, separately-tracked issue at `kit/ROADMAP.md:1014`). Worse, the same workspace's E2E spec for the same feature successfully seeds users + cards via `adminClient()` (the rationale claimed it couldn't), so a 30-second cross-check would have falsified the claim. Phase 5.9 then read the deferral as settled and recorded a no-op without re-verifying. Phase 6 evidence-on-disk sweep doesn't trigger when there are no `[x]` checkboxes pointing at missing files — it has no signal for "new screens shipped without any visual evidence." Net: home-os shipped three consecutive PRs (capture-flow #15, landing-redirect #18, triage-route-handler #19) where the same constraint was hand-waved away rather than fixed or flagged.

  **Pattern this exposes**: pre-ship subagents are too willing to accept a deferral when the rationale sounds plausible-and-technical. The orchestrator (`/ak-build`) doesn't push back because the audit comment surfaces it as "findings (1) deferred" rather than "this PR shipped without evidence of a load-bearing claim." Three places to fix in tandem:

  **Fix 1 — `/ak-pre-ship` Gate 4 / Gate 13 deferral must verify the rationale.** When the gate decides to defer screenshot capture, the recorded rationale must include either (a) a successful capture attempt that hit a specific error message (paste it into review.md), OR (b) a documented infrastructure blocker that's referenced by tracker entry (e.g. `kit/ROADMAP.md:<line>`). Hand-wave rationales like "Node 20 + X interop" without a stack trace, repro command, or tracker citation fail the gate as `findings_pending`, not `deferred`. The Layer-2 adversarial reviewer should treat "ws() interop", "harness blocked", "auth-gated screen" as red flags requiring evidence.

  **Fix 2 — Phase 5.9 should detect "new public screens, zero hero shots" as a halt signal.** Current idempotence guard skips when `specs/<feature>/hero/` is unchanged at HEAD — but if it's empty AND the diff added new public screens (regex: `^apps/[^/]+/app/\(.+\)/[^/]+/page\.tsx$` not under `_components/`), that's not idempotent, that's deferred-and-forgotten. Phase 5.9 should re-attempt capture (re-spawning the subagent without the deferral excuse) when this pattern fires, OR halt with a loud "no visual evidence on a UI-bearing PR — operator must explicitly acknowledge in review.md" message.

  **Fix 3 — Phase 6 audit comment should surface "shipped without visuals" as a top-line concern, not buried under Gate 4.** The current Evidence section says "Hero shots deferred" if `specs/<feature>/hero/` is empty. For PRs that added new public screens, this should escalate to a dedicated `### ⚠ No visual evidence for new screens` section above Evidence, listing the screens that lack captures so reviewers see it before scrolling.

  **Edit targets**:
  - `/devshop/.claude/skills/ak-pre-ship/SKILL.md` § Gate 4 + Gate 13 (deferral-rationale validation rules)
  - `/devshop/.claude/skills/ak-build/SKILL.md` § Phase 5.9 (new-screen-without-evidence detection + halt path) + § Phase 6 (top-level Evidence escalation)
  - `/devshop/kit/docs/guide/adversarial-review.md` if it has a list of "rationale categories that get extra scrutiny" — add "screenshot/E2E deferrals" to the list

  **Severity**: medium — silent visual-evidence drift across 3 home-os PRs already; if not fixed, the pattern continues every UI-bearing PR while the home-os firewall fix is pending. Reviewer trust degrades when "I read the PR, no screenshots, must've been hard to capture" becomes the default mental model.

  [medium, skill-improvement, ak-pre-ship + ak-build, surfaced-by home-os-pr-19-2026-05-15, 2026-05-15]

- [ ] **PR-body composition adds "Run `supabase db push`" as a manual out-of-band item even when `deploy-migrations.yml` exists.** Surfaced 2026-05-15 on home-os PR #19. `/ak-build` Phase 4.1 pre-composes the PR title + Summary, and the SKILL's § "Out-of-band deploy items" section unconditionally adds a `supabase db push` reminder whenever the diff touches `supabase/migrations/**`. Home-os has `.github/workflows/deploy-migrations.yml` which auto-applies migrations on push to main — making the manual step unnecessary AND misleading (a reviewer sees the checkbox, runs `supabase db push` manually after merge, and either no-ops because the workflow already ran or fights the workflow's lock). The same SKILL also has a fall-through for `supabase/functions/**` (also auto-deployed via `deploy-functions.yml`) and `terraform/**`, `k8s/**`. All of these need a "check whether a workflow already handles this" gate before adding the manual reminder.

  **Fix shape**: in `/ak-build` Phase 4.1's "Out-of-band deploy items" detection block, before adding a `supabase db push` reminder, grep `.github/workflows/*.yml` for a workflow whose `on:` trigger matches `push: [main]` AND whose body contains `supabase db push` or `supabase migration up`. If found, **skip** the manual reminder entirely and instead add a positive note: `Migration auto-deploys via .github/workflows/<workflow>.yml on merge to main`. Apply the same logic for the other auto-deployable paths (`functions/**` → check for `supabase functions deploy`; `terraform/**` → check for `terraform apply`; `k8s/**` → check for `kubectl apply`).

  **Edit targets**:
  - `/devshop/.claude/skills/ak-build/SKILL.md` § "PR body conventions" § "Out-of-band deploy items" — add the auto-deploy detection logic before the manual-reminder generation
  - `/devshop/.claude/skills/ship/SKILL.md` (or its checklist template) — same logic if /ship composes a body without going through /ak-build

  **Concrete repro from this session**: home-os PR #19's pre-composed PR body listed `Run supabase db push to apply migration 20260515181530_007_triage_route_handler.sql against production` as `[ ]` under "Out-of-band deploy items (post-merge)". The repo has `.github/workflows/deploy-migrations.yml` triggering on `push: [main]` with a body that includes `supabase db push`. The detection would have flipped the item to "auto-deployed; no manual step needed."

  **Severity**: low-medium — misleading PR copy that wastes reviewer attention. Doesn't break anything functionally because the workflow runs regardless, but trains the operator to verify auto-deploy claims, eroding the audit-trail's signal value.

  [low-medium, skill-improvement, ak-build + ship, surfaced-by home-os-pr-19-2026-05-15, 2026-05-15]

- [ ] **`/ak-go-live` Step 1.7 (Auth-config deploy reminder) doesn't fire on first-prod-deploy of an auth-touching feature.** Surfaced 2026-05-15 on home-os PR #19. The SKILL's Step 1.7 only triggers "if the spec or PR body references auth-config changes" — but on a fresh production deploy of a project where auth has been live for several PRs but **no one has actually signed in on prod yet**, the auth-config gaps (or auth-flow runtime bugs like PKCE-cookie loss in Safari Private Browsing) don't surface until the first real invitee tries to sign in. On home-os, that was 30min post-PR-19-deploy with a friend's failed sign-in — well after `/ak-go-live` completed and printed "Deployed to production." There was no pre-deploy beat where an actual end-to-end sign-in was exercised; the production-curl probe in Step 1.5 only checks anon `/` returns 2xx/3xx, which it does correctly (middleware bounces anon to `/login`). The bug shape was invisible from the public surface.

  **Pattern**: every project's first production deploy of an auth-touching feature has this same shape. The current `/ak-go-live` flow is great at "did the deploy land?" and "is canary healthy?" but doesn't have a "did a real user successfully complete the most-affected user flow?" gate. The implicit assumption is that the operator will manually invite/test someone post-deploy — which is what happened on home-os, except the failure cost an invite and surfaced anxiety that "the new deploy broke things" before the operator could diagnose (it actually was a pre-existing PKCE-flow issue that just hadn't been exercised on prod yet).

  **Fix shape**: extend `/ak-go-live` with a new step between Step 5 (reflection) and Step 6 (notify) — call it Step 5.5 (post-deploy smoke). The step asks the operator (via `AskUserQuestion`):

  > Has this deploy touched any user-facing flow that hasn't been exercised on prod yet (e.g. first auth flow, first payment, first invite)? If yes, complete an end-to-end test with a real user account NOW, before notifying. Options:
  >
  > - **Done — flow works** (proceed to notify)
  > - **Tested — found issue X** (pause; surface for triage)
  > - **Will test post-merge** (proceed; operator commits to following up)
  > - **Not applicable** (proceed)

  Detection of "first user-facing flow exercise" needs heuristics: check `BUILD-LOG.md` for prior auth/payment/invite mentions, check whether the PR touched `app/api/auth/` or `app/login/` or middleware auth predicates, check whether the PR's spec mentions "first" or "initial" or "v0" of a user-flow surface. Imperfect but better than the current zero-gate state. The operator can always answer "Not applicable" if the heuristic over-fires.

  Optionally: invent a `kit/scripts/post-deploy-smoke/` directory where projects can drop a `<feature>.sh` script that drives the actual end-to-end flow (e.g., a Playwright spec that signs up + signs in against the prod URL using a throwaway email). `/ak-go-live` Step 5.5 looks for `kit/scripts/post-deploy-smoke/auth.sh` matching the deploy's surface and runs it automatically. Cleaner but bigger lift.

  **Why this generalizes**: home-os, lalista, and every Next.js + Supabase project follow the same shape — auth lands in one of the first 3 PRs, then no one signs in on prod until the first real invitee. The gap is universal. Once Supabase Auth (or any auth provider) gets a first-prod-deploy smoke gate, every future project inherits it.

  **Edit targets**:
  - `/devshop/.claude/skills/ak-go-live/SKILL.md` — add Step 5.5 (post-deploy user-flow smoke) between Step 5 (reflection) and Step 6 (notify)
  - Optionally: `kit/scripts/post-deploy-smoke/` directory + project-side template entry in `kit/notes/projects/` showing the smoke-script convention

  **Severity**: medium — every auth project has been silently relying on operator manual testing here; when the operator forgets or delegates to a friend, failures surface late and look like deploy regressions. The home-os incident cost ~1hr of triage to confirm the failure was pre-existing not deploy-introduced.

  [medium, skill-improvement, ak-go-live, surfaced-by home-os-pr-19-2026-05-15, 2026-05-15]

- [ ] **Convention: any server-side auth-callback handler must `Sentry.captureException` on error.** Surfaced 2026-05-15: home-os `apps/web/app/auth/callback/route.ts:80` returned 303 to `/login?error=callback_failed` on `exchangeCodeForSession` failure with **no Sentry capture**. When the first prod invitee's sign-in failed (Safari Private Browsing + PKCE cookie isolation), Sentry had zero record — `@sentry/nextjs` was correctly wired everywhere else but this specific route's error path was silent. The bug shape ("auth callback silently swallows the exchange error") is a pattern, not a one-off: any project scaffolded against Supabase Auth (or any OAuth-style provider) ends up with a `/auth/callback`-shape handler that has an exception-swallowing else-branch, because the canonical pattern from the Supabase docs only redirects on error without logging.

  **Pattern**: every server-side auth-callback handler has this shape:

  ```
  const { error } = await supabase.auth.exchangeCodeForSession(code);
  if (error) {
    return redirect('/login?error=callback_failed');  // silent — bug
  }
  ```

  The correct shape:

  ```
  const { error } = await supabase.auth.exchangeCodeForSession(code);
  if (error) {
    Sentry.captureException(error, { tags: { route: 'GET /auth/callback', stage: 'exchange_code' } });
    return redirect('/login?error=callback_failed&reason=' + classify(error));
  }
  ```

  **Fix shape**: codify this in two places:
  1. **Convention doc** at `kit/docs/guide/conventions.md` (likely under § Error Observability or a new § Auth Boundaries section): "server-side OAuth/PKCE/magic-link callback handlers must `Sentry.captureException` before any error redirect; redirect URL must include a coarse `reason=<class>` query so the receiving page can render specific copy." Pair with an example.
  2. **Pre-ship gate** at `/devshop/.claude/skills/ak-pre-ship/SKILL.md`: a new pattern-check gate that greps for `auth.(exchangeCodeForSession|signInWithPassword|signInWithOtp|verifyOtp)` call sites and flags any that don't have `captureException` on their error branch within ±10 lines. Low false-positive, high catch rate. Integrates with the existing `/review` gate.
  3. **Template scaffold** in `template/apps/web/app/auth/callback/route.ts` (if it exists in the template; otherwise add it): the canonical example handler with the Sentry + reason-passthrough shape baked in so every project that scaffolds from the template inherits the right pattern from day one.

  **Edit targets**:
  - `kit/docs/guide/conventions.md` (new § or existing observability section)
  - `/devshop/.claude/skills/ak-pre-ship/SKILL.md` § Gate (pattern check)
  - `template/apps/web/app/auth/callback/route.ts` (if applicable)

  **Why this generalizes**: auth callbacks are universal across web apps; opaque error swallowing is the default pattern most folks copy from official docs; the cost of the gap is invisible in dev (everything works on localhost) and catastrophic in prod (first invitee fails, no telemetry, hours of triage to confirm it's a pre-existing app bug not a deploy regression).

  **Severity**: medium — same pattern will recur in every new auth-touching project until codified.

  [medium, convention + skill + template, surfaced-by home-os-pr-19-2026-05-15, 2026-05-15]

- [ ] **`/ak-merge-devshop` doesn't author BUILD-LOG entries or close PLAN rows — the Phase 4.0 bookkeeping discipline only fires inside `/ak-build`, so ad-hoc devshop feature branches land on `main` with missing audit-trail.** Surfaced 2026-05-18 while inspecting `git log` on main and noticing that the last 2 ship-commits (`fb18c8f` pipeline-correctness, `7262fac` migration-rollback-gate) had no BUILD-LOG entries, and `7262fac` additionally left its `PLAN.md ## Planned` row unchanged despite shipping sub-fix B of the three-deliverable feature. Root cause: `/ak-merge-devshop` is a transport layer — it squashes whatever's on the branch + ff-merges to main. The BUILD-LOG entry + PLAN row closure are owned by `/ak-build` Phase 4.0 (which composes them on the feature branch BEFORE `/ship` pushes, so they ride in the original CI cycle). When devshop feature work is authored ad-hoc (operator branches off main, edits + commits, invokes `/ak-merge-devshop` directly), `/ak-build` never runs and Phase 4.0 never fires — so the feature lands on main with no canonical record in BUILD-LOG and no PLAN closure. Backfill at `chore/backfill-bookkeeping-gap` patches the two missing entries + the `7262fac` PLAN row staleness, but the structural gap remains.

  **Why this is a TODO not a one-off:** every ad-hoc devshop feature branch goes through `/ak-merge-devshop` directly (the convention pre-this-PR was "`/ak-build` is for projects; `/ak-merge-devshop` is for devshop"). With 4+ recent devshop features shipping in the last week alone, the gap recurs on every single one. The `kit/ROADMAP.md § /ak-build devshop-mode` entry (paired with this TODO) is the strategic fix — once devshop work flows through `/ak-build` natively, Phase 4.0 fires by construction and this TODO closes automatically. Until then, the tactical fix below mitigates.

  **Tactical fix shape** (close before the ROADMAP entry ships if it'll take a while):
  1. **`/ak-merge-devshop` Phase 0.X — feature-shape detection.** Heuristics that flag a branch as "feature-like" (vs pure docs/TODO): (a) diffstat touches source surfaces (`.claude/skills/**/SKILL.md` content beyond a one-line edit, `kit/scripts/**.sh`, `template/**` excluding pointer fixes); (b) branch name matches `feat/*` or `fix/*` (not `docs/*` or `chore/*`); (c) `PLAN.md ## Active` or `## Planned` has a row whose slug matches the branch (case-insensitive, slug-strip the `feat/`/`fix/` prefix).

  2. **`/ak-merge-devshop` Phase 0.Y — bookkeeping prompt.** If feature-shape detected AND no `chore(build-log):` commit exists on the branch (`git log --grep '^chore(build-log)' origin/main..HEAD`), surface via `AskUserQuestion`:
     - **Compose the BUILD-LOG entry now** — agent drafts an entry from the branch's commit bodies + spec/review.md + diffstat; operator approves/edits; commit lands as a new commit on the branch before squash.
     - **Skip — this branch genuinely doesn't warrant a BUILD-LOG entry** — operator explains why; reason recorded as a `Bookkeeping-Skip-Reason:` trailer on the squash commit (adversarially reviewed via `adversarial-review.sh`, new check-type `bookkeepingSkipReason`).
     - **Abort the merge** — operator goes back, runs `/ak-build` properly, comes back.

  3. **PLAN row closure prompt.** Mirror the same pattern — if a Planned/Active row matches the branch slug AND the row's "deliverables" list is fully covered by the branch's diff (heuristic: every `(A)`/`(B)`/`(C)`-style sub-bullet in the Hook column is implemented by the diff), prompt to remove the row. If only SOME sub-bullets are covered (the `7262fac` shape: shipped B alone, A+C pending), prompt the operator to **reword** the row to reflect remaining scope rather than delete.

  4. **Edit targets**: `.claude/skills/devshop/merge-devshop/SKILL.md` § Phase 0 (add 0.X detection + 0.Y prompt + 0.Z PLAN-row closure prompt); `kit/scripts/adversarial-review.sh` (new `bookkeepingSkipReason` check-type, Sonnet-routed); new bats `kit/tests/util-ak-merge-devshop-bookkeeping.bats` pinning detection heuristics + prompt + skip-reason adversarial-review acceptance criteria.

  **Why this generalizes**: the gap exists for every devshop project that uses `/ak-merge-devshop` (today: just `/devshop` itself, but the skill is part of the kit and could be used by any future devshop-of-devshops scenario). Closing it ensures BUILD-LOG remains a canonical record of every shipped feature — which downstream consumers like `/ak-release-devshop`'s categorization, future CHANGELOG aggregators, and retrospectives all depend on.

  **Severity**: medium — backfill works for missed entries; the gap is recoverable but invisible-by-default; pairs with the strategic ROADMAP entry which fully closes it.

  [medium, skill-improvement, ak-merge-devshop + bookkeeping-discipline, paired-with-roadmap ak-build-devshop-mode, surfaced-by main-log-inspection 2026-05-18, 2026-05-18]
