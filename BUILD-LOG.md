# Build Log

Devshop build history. One entry per merged feature branch, most-recent first. Written by `/ak-build` Phase 4.0 on the feature branch before `/ship` pushes, so the entry ships in the original CI cycle. Phase 5.6 is a verify-only fallback for resume rungs where 4.0 didn't fire.

For forward-looking plan: `PLAN.md`. For deferred/long-term work: `kit/ROADMAP.md`.

### pushtomain-dispatch-arm (2026-06-02)

- **Branch**: `fix/pushtomain-dispatch-arm`
- **Headline**: Infrastructure update — no user-visible change in this PR.
- **Summary**: Restores the feature-branch→main push path in the devshop, which was 100% broken. `adversarial-review.sh` was missing the `pushToMainApproved)` dispatch arm: the check-type was referenced by `kit/hooks/pre-push.sh`, `get_model_for_check_type()`, the header docs, and the rule-13 prompt block, but had no `case` arm to assemble its `$CONTEXT` — so every invocation fell through to the `*)` default and returned `FAIL: unknown check type: pushToMainApproved`. No reason string could pass it, so `/ak-merge-devshop`'s `--source-worktree` path and any direct `git push origin <branch>:main` were dead. The dominant merge path (checkout main → ff-merge → push FROM main) structurally never calls the check — the pre-push hook short-circuits at `[ "$BRANCH" = "main" ] && exit 0` — which is why a total dead path survived the PR-C "coverage reviews moved to audit-time" refactor invisibly. Fix: add the dispatch arm (assembles branch + HEAD + `origin/main..HEAD` range context; rule 13 does the ceremony judging unchanged), and add `pushToMainApproved` to the `*)`-default `Surviving check-types:` list so the diagnostic is accurate. Regression coverage: a new `surviving: pushToMainApproved reaches claude` case in `util-adversarial-review-narrowing.bats` asserts the real reviewer recognizes the check-type — the gap was that `util-pre-push.bats` _mocks_ `adversarial-review.sh`, so the hook tests passed while the real dispatch was broken.
- **Folded friction history** (FRICTION-LOG entry deleted on ship per close-on-ship convention): observed once — 2026-06-02, landing the gstack-volume-TODO closure, when a parallel session held `/devshop`'s main checkout and forced the ref-push path, surfacing `FAIL: unknown check type`. Worked around at the time by freeing main and using the default push path. Impact rated M (the broken escape hatch bites precisely during parallel-session windows, the one time the default path isn't available). Also an instance of the score-15 "grep-based test drift" family — no test pinned the dispatch arm's presence, so its removal shipped green.
- **Commits**: `fix(adversarial-review)` dispatch arm + surviving-types list + recognition bats test; `docs` FRICTION-LOG delete + BUILD-LOG fold — landed via `/ak-merge-devshop`.
- **Quality gates**: full kit bats suite green; `util-adversarial-review-narrowing.bats` (new pushToMainApproved recognition case) + all 61 `util-pre-push.bats` cases pass.

### init-devshop-mtime-bump (2026-06-01)

- **Branch**: `fix/init-devshop-mtime-bump`
- **Spec**: `specs/init-devshop-mtime-bump/spec.md`
- **Headline**: Infrastructure update — no user-visible change in this PR.
- **Summary**: `init-devshop.sh` now refreshes its root-owned `[locked]` files content-aware: it rewrites a file only when the template source actually differs (`cmp -s`), instead of unconditionally `install`-ing every file on every container start. The `install` is the script's only mtime-bumping write, so gating it stops VS Code's "Configuration file(s) changed — Rebuild?" prompt from re-arming on every boot after a clean rebuild — behavior that had been training operators to reflexively dismiss a rebuild signal that matters for real changes. The five chown/chmod lock steps are likewise made idempotent (skip when the `stat -c '%U:%G %a'` tuple already matches `root:root <mode>`), eliminating redundant per-boot metadata churn while preserving the security re-lock that recovers from git-op ownership erosion (including on the content-match path). Closes the `kit/TODOS.md` "mtime-bumps `[locked]` files" entry; the source TODO pointed at `template/.devcontainer/init-devshop.sh`, but the locking logic had since moved to `kit/scripts/init-devshop.sh` (template is now a forwarder) — the fix retargeted accordingly.
- **Commits**: 10 (Phase 0 skeleton + Phase 1 spec; `fix(init-devshop)` cmp -s content guard [T1]; `fix(init-devshop)` stat-tuple idempotent locks [T2]; `test(init-devshop)` pin both guards [T3]; tasks.md; fresh-eyes verification log; Gate 5 audit; `fix(init-devshop)` content-match re-lock pin + manifest/architecture legend sync [Phase 3 Gate 5 medium]; Phase 3 review.md + gate sinks) — squashed to 1 on main via `/ak-merge-devshop`.
- **Quality gates**: devshop gate set — Gates 1/4/6/11 pass; Gate 2d full bats green (1628 passed, 0 failed, incl. 3 new `manifest-lifecycle.bats` regression tests: cmp -s guard, stat-tuple idempotence, content-match re-lock pin); Gate 5 docs+tests audit (Audit 1) high=0 medium=3 low=2 — 2 mediums fixed in-branch (manifest.txt+architecture.md legend still said "refreshed every container start"; content-match re-lock not independently pinned), remainder advisory (static-grep tests are revert-detectors by design per D3). 9 non-LLM carve-outs n/a; 4 LLM-mediated structural carve-outs (cso/design-review/qa/benchmark — no auth/UI/perf surface). Phase 2.5 fresh-eyes: 0 findings — independently re-verified the cmp -s branch behavior (missing/identical/differ), mtime-unchanged-on-noop, security re-lock on drift, `set -e` safety, and test-fails-on-revert. Gate 5 audit stamp (2b0e60b) is one commit behind HEAD (the medium-finding fix); `/ak-merge-devshop` Phase 1.1 re-audits the delta by construction.
- **Worktree**: built in `.worktrees/init-devshop-mtime-bump` (base `origin/main`); /devshop stayed on `main` throughout. `verification.log` required `git add -f` (caught by the global `*.log` gitignore).

### ak-check-docs-orphan-stubs (2026-05-31)

- **Branch**: `feat/ak-check-docs-orphan-stubs`
- **Spec**: `specs/ak-check-docs-orphan-stubs/spec.md`
- **Headline**: Infrastructure update — no user-visible change in this PR.
- **Summary**: Doc-only / tracker-only devshop merges no longer leave orphan `specs/<feature>/review.md` stubs behind. `/ak-check-docs-and-tests` Step 1 now runs a new classifier — `kit/scripts/preship/audit-tracker-only.sh` — over the audit range BEFORE scaffolding the stub: if every changed path is a pure tracker (`PLAN`/`TODOS`/`ROADMAP`/`BUILD-LOG`/`PRODUCT-ROADMAP`/`DEPS-WATCH`/`kit/notes/`/`kit/version`/`kit/docs/CHANGELOG.md`/`kit/FRICTION-LOG.md`), it prints `✓ audit short-circuited: diff is tracker-only` and exits without scaffolding, invoking sub-skills, or appending a section. `kit/docs/guide/**` and `kit/tests/**` are deliberately NOT trackers — they remain auditable. The helper exits 1 (audit) on an unresolvable range so a rewritten-history SHA can never false-short-circuit a real audit. File trackers are exact-anchored (not prefix) so a future `kit/versioning.md` / `kit/ROADMAPER` is not falsely swept. Closes the `kit/TODOS.md` orphan-stub entry.
- **Commits**: Phase 0 skeleton + Phase 1 spec; `feat(preship)` helper + 12-case bats [T1]; `feat(audit)` SKILL.md Step-1 short-circuit + grep test [T2]; `docs(audit)` TODO closure + `docs(friction-log)` [T3]; `fix(preship)` exit-1-on-unresolvable-range [Phase 2.5 fresh-eyes]; `fix(preship)` track 644 (script lock); `fix(preship)` exact-anchor file trackers [Phase 3 finding]; Phase 3 review.md + gate sinks — squashed to 1 on main via `/ak-merge-devshop`.
- **Quality gates**: devshop gate set — Gates 1/4/11 pass; Gate 2d full bats green (1623 passed, 0 failed, incl. the new 12-case `util-audit-tracker-only.bats`); Gate 5 docs+tests audit (Audit 1) high=0 medium=0 low=1 (tracker prefix over-match — fixed); Gate 6 `/review` 1 finding fixed (same prefix over-match, cross-confirmed). 9 non-LLM carve-outs n/a; 4 LLM-mediated structural carve-outs (cso/design-review/qa/benchmark — no auth/UI/perf surface). Phase 2.5 fresh-eyes caught + fixed a real `set -e` swallow-of-`$(git diff)` bug that false-short-circuited on unresolvable ranges. Branch rebased onto `origin/main` mid-flight after a sibling feature (`skip-bats-docs-only`) landed.
- **Worktree footgun**: built in `.worktrees/ak-check-docs-orphan-stubs`; the implement subagent hit the worktree-blind `check-tests-coverage-devshop.sh` (hardcoded `TESTS_DIR=/devshop/kit/tests`) + a `DEVSHOP=`-override fixture-corruption trap, both recovered non-destructively and logged to FRICTION-LOG.

### skip-bats-docs-only (2026-05-31)

- **Branch**: `feat/skip-bats-docs-only`
- **Spec**: `specs/skip-bats-docs-only/spec.md`
- **Headline**: Docs-only commits to the devshop repo now finish instantly — the ~30s kit test suite is skipped when a commit touches only Markdown, with a clear "skipped (docs-only diff)" line so it's never silent.
- **Summary**: `.husky/pre-commit` gains a guard between the gitleaks scan and the `main`-branch full bats block: when every staged path ends in `.md`, it prints `✓ Kit tests: skipped (docs-only diff)` and bypasses the suite. The check is mechanical (no adversarial review) — a false-negative just runs bats unnecessarily, and the next non-docs commit re-covers. Only the redundant bats no-op is skipped; lint-staged, gitleaks, the branch guard, and the Layer-1 coverage hooks still run on every commit. Covered by `kit/tests/guard-bats-docs-only.bats` (predicate behavior + a parity test pinning the production block to the fixture); `kit/docs/guide/hooks.md` updated; the `kit/TODOS.md` entry rewritten to track only the remaining `path-classifier --mode=devshop` refactor.
- **Commits**: 7 (Phase 0 skeleton + Phase 1 spec; `perf(pre-commit)` hook predicate + bats test [T1+T2, test alongside code]; `kit/TODOS.md` first-pass closure [T3]; tasks.md; `hooks.md` doc-drift fix; Phase 2.5 + Phase 3 review) — squashed to 1 on main via `/ak-merge-devshop`.
- **Quality gates**: devshop gate set — Gates 1/4/6/11 pass; Gate 2d full bats green (1611 passed, 0 failed, incl. the 6 new `guard-bats-docs-only.bats` cases); Gate 5 docs+tests audit (Audit 1) high=0 medium=0 low=0 — 1 doc-drift finding (`hooks.md` 2f description stale) found + fixed in-branch during Phase 2.5. Gate 6 `/review`: 1 non-blocking observation (git-quoted-path conservative fall-through — by design, runs bats unnecessarily). 9 non-LLM carve-outs n/a; 4 LLM-mediated structural carve-outs (cso/design-review/qa/benchmark — no auth/UI/perf surface). Phase 2.5 fresh-eyes: 1 finding fixed, verified via an integration dogfood of the real hook decision block (docs-only → skip + no bats; code → bats runs). LLM-mediated dispatched gates ran orchestrator-inline (subagent transport dropped 3×); `/ak-merge-devshop` Phase 1.1 re-audits the delta independently at merge.
- **Worktree footgun**: built in `.worktrees/skip-bats-docs-only`; `core.worktree` checked after `submodule update` (not injected this run — /devshop tree stayed intact).

### virtiofs-rebase-auto-switch (2026-05-31)

- **Branch**: `feat/virtiofs-rebase-auto-switch`
- **Spec**: `specs/virtiofs-rebase-auto-switch/spec.md`
- **Headline**: Infrastructure update — no user-visible change in this PR.
- **Summary**: Devshop merges stop stalling on the virtiofs phantom-rebase flake — `/ak-merge-devshop` Phase 1.0 now auto-detects the false-failure and walks the recovery ladder (reduced-stat retry → merge fallback) via `kit/scripts/virtiofs-rebase.sh`, without operator hand-driving, while genuine conflicts still surface for manual resolution. The helper discriminates phantom-vs-real-conflict by unmerged-path presence (not stderr-string match), so the rescheduled-pick variant is auto-covered. 18-case bats suite + structural-invariants registration; CLAUDE.md footgun + workflow.md row rewritten to point at the helper; `kit/TODOS.md` mechanize-entry deleted and the FRICTION-LOG rescheduled-pick variant deleted (delete-on-ship — no `## Resolved` archive).
- **Commits**: helper (T1) + 18-case bats (T2) + structural-invariants registration (T3) + merge-devshop Phase 1.0 wiring (T4) + docs closing-convention (T5) + Phase 3 review.md + Phase 4.0 bookkeeping — squashed to 1 on main via `/ak-merge-devshop`.
- **Quality gates**: devshop gate set — Gates 1/4/6/11 pass; Gate 2d full bats suite green (1594 passed, 0 failed, incl. the new 18-case `util-virtiofs-rebase.bats`); Gate 5 docs+tests audit (Audit 1) high=0 medium=1 low=1 (both test-robustness recommendations, not blockers — exit-11 real-repo companion + checkStat flag-position pin). Gate 6 `/review` surfaced 1 MEDIUM (rerere/exec/empty-stop edge case where a real rebase conflict leaves a clean index — out of scope for plain `rebase <anchor>`, noted) + 3 LOW. 9 non-LLM carve-outs n/a; 4 LLM-mediated structural carve-outs (cso/design-review/qa/benchmark — no UI/auth/perf surface). Phase 2.5 fresh-eyes: 1 finding fixed (helper tracked 755 → 644).

### propagation-skip-noop (2026-05-31)

- **Branch**: `feat/propagation-skip-noop`
- **Spec**: `specs/propagation-skip-noop/spec.md`
- **Headline**: Release propagation logs now list only the steps you actually need to take, instead of a wall of "nothing to do" entries.
- **Summary**: `propagation-entry.sh` now reads a `[auto]`/`[manual]`/`[conditional]` disposition tag at the head of each commit's `**Existing projects:**` block and emits only the actionable (`manual`/`conditional`) ones into `PROPAGATION.md` — `[auto]` blocks drop out (the audit trail stays in the commit), and a version whose changes all auto-propagate collapses to a single `(no manual steps)` line. The design flipped from auto-classify to an author tag because a Phase-0.2.5 empirical test over all 21 historical blocks proved no regex can separate no-op from actionable (the CSP "no migration forced [+conditional step]" and gitignore "no manual step" blocks are textually indistinguishable). The squash-surface hygiene gate (`adversarial-review.sh` NOTE-3) now FAILs a present-but-untagged block; `conventions.md`, `merge-devshop SKILL.md § 0.3`, `hooks.md`, and the `docs-review` example all document the tag; the v1.37.0 `PROPAGATION.md` section was backfilled from 11 no-op bullets to the one conditional CSP entry.
- **Commits**: 14 (Phase 0 skeleton + Phase 1 spec; generator tag parse/filter/render; all-[auto] collapse; hygiene-gate tag requirement; 7 bats; tag docs; v1.37.0 backfill; Gate-5 Audit 1; focused-fix FIX A multi-block-warn + multi-line-render, FIX B/C/D doc-contradiction repairs, FIX E n/a alignment; Phase 3 gate evidence) — squashed to 1 on main via `/ak-merge-devshop`.
- **Quality gates**: devshop gate set — Gates 1/4/6/11 pass (Gate 11: 1 low, squash-moot subject length); Gate 2d full bats green (1586 passed, 0 failed, incl. 7 new tag-filter/gate-precompute + the focused-fix multi-block/render cases); Gate 5 docs+tests audit high=0 medium=3 low=3. Gate 6 `/review` surfaced 4 findings (1 medium = multi-block silent-drop — the D2 dangerous-drop mode; 3 low) + Gate 5's 3 mediums (multi-block untested; `hooks.md`/`release-devshop SKILL.md` stale-contradiction with the feature) — ALL fixed in-branch via the focused fix, empirically verified against real behavior. 9 non-LLM carve-outs n/a; 4 LLM-mediated structural carve-outs. Phase 2.5 fresh-eyes: 0 findings. **Mid-build incident**: a sibling worktree's `git submodule update` injected `core.worktree` into the shared `/devshop/.git/config`, hijacking `/devshop`'s working-tree pointer (symptom: phantom git status + GitHub Desktop "can't find repo"); fixed in-place via `git config --local --unset core.worktree`, no restart — friction-log + CLAUDE.md footgun pending.

### merge-devshop-worktree-hooks (2026-05-30)

- **Branch**: `feat/merge-devshop-worktree-hooks`
- **Spec**: `specs/merge-devshop-worktree-hooks/spec.md`
- **Headline**: Parallel-work worktrees now run the same safety checks as the main repo, and the merge step double-checks for leaked secrets before any change lands.
- **Summary**: The worktree-add recipe now runs `pnpm install` so husky pre-commit hooks (gitleaks, doc/test coverage, branch guard, CLAUDE.md gates) fire in-worktree instead of silently no-opping — closing a silent gate-skip on the default parallel-work path. As a belt-and-suspenders net, `/ak-merge-devshop` now runs a gitleaks scan on **every** path that lands a branch on `main`: `gitleaks protect --staged` on the squash delta (Phase 2), and a `gitleaks git --log-opts "$ANCHOR..$BRANCH"` commit-range history scan on the rename-symlink ff-merge fallback (Phase 3) — so a secret can't reach `main` even from an off-convention worktree where the install step was skipped. Three stale false-safety-net doc claims were corrected to the install-dependent + merge-time-net posture (`CLAUDE.md § Parallel work`, `merge-devshop SKILL.md § Phase 2`, `kit/docs/guide/security.md` — the last of which load-bearingly justified worktree script-edit safety on the now-corrected "hooks fire identically" claim). Shipped fix options (b) + (d); option (c) (a `session-start.sh` empty-`.husky/_` warning) stays as an optional follow-up in `kit/FRICTION-LOG.md`.
- **Commits**: 12 (Phase 0 skeleton + Phase 1 spec expand; (b) recipe install step; (d) squash-delta gitleaks gate + bats; tracker correction + closure; Gate 5 Audit 1; Phase 3 ff-merge gitleaks gate + 3 bats; Phase 3 gate evidence; incidental prettier-stability repair on two gstack `CLAUDE.md` bullets) — squashed to 1 on main via `/ak-merge-devshop`.
- **Quality gates**: devshop gate set — Gates 1/4/6/11 pass; Gate 2d full bats suite green (1575 passed, 0 failed, incl. 5 new `util-ak-merge-devshop.bats § Section G` tests pinning the gitleaks gates + cwd-pin + ordering); Gate 5 docs+tests audit (Audit 1) high=0 medium=0 low=4. Gate 6 `/review` surfaced 1 MEDIUM (ff-merge fallback bypassed the gate — the off-convention-worktree secret-bypass the feature exists to close) + 2 LOW; the MEDIUM + 1 LOW were fixed in-branch (`a7058e4`, empirically verified), 2 LOWs noted-and-proceed. 9 non-LLM carve-outs n/a; 4 LLM-mediated structural carve-outs (cso/design-review/qa/benchmark — no UI/auth/perf surface). Phase 2.5 fresh-eyes: 1 incidental finding fixed (prettier-stability), 0 escalated; empirically confirmed the gitleaks gate's exit-1-on-finding contract with real gitleaks 8.30.1.

### triage-todos-to-friction-log (2026-05-29)

- **Branch**: `chore/triage-todos-to-friction-log`
- **Spec**: `specs/triage-todos-to-friction-log/spec.md`
- **Headline**: Infrastructure update — no user-visible change in this PR.
- **Summary**: First real population of `kit/FRICTION-LOG.md` — 7 premature/single-sighting TODOs demoted into the counted intake ledger (3 explicitly-investigation items: subagent-drift instrumentation, Mac host-resource hypothesis, Layer-B squash-boundary gap; 4 single-observation items: prTextHygiene false-reject, visual-evidence rubber-stamp, doc/test silent-drift, ls-remote garbled output), each with the full ledger schema and sorted by impact×count. The proven virtiofs phantom-rebase fallback graduated past friction to a scored `PLAN.md § Planned (v0)` row (`virtiofs-rebase-auto-switch`, Lev 8.0, sorts top) while keeping its `kit/TODOS.md` entry as the long-form Source. Every remaining untagged `kit/TODOS.md` open entry received a `[v0]`/`[v1]`/`[v+]` schedule tag per the triage buckets (sudo-scoping kept at `[v0]`; gstack-volume-wipe retagged `[v+]`→`[v0]`), so future sessions stop reading unscheduled debt as "still pending". The driver triage entry was deleted as its own resolution. No tooling/code touched — pure tracker hygiene.
- **Commits**: branch baseline (intake + gitignore) + spec skeleton/expansion, seed 7 friction-log entries, delete 7 moved + driver entries, promote virtiofs to PLAN, version-tag remaining entries, tasks.md, Phase 2.5 verification, Phase 3 review.md + Gate 5 Audit 1 + gate sinks, BUILD-LOG; squashed to 1 on main via /ak-merge-devshop.
- **Quality gates**: devshop gate set — Gates 1/4/6 pass; Gate 11 convention findings(1) LOW (two intermediate commit subjects >72 chars — squash-moot); Gate 2d full bats suite green (1568 passed, 0 failed); Gate 5 docs+tests audit (Audit 1) high=0 medium=0 low=0. 9 non-LLM carve-outs n/a; 4 LLM-mediated structural carve-outs (cso/design-review/qa/benchmark — no UI/auth/perf surface). Phase 2.5 fresh-eyes: 0 findings.

### merge-rebase-racy-git-remedy (2026-05-29)

- **Branch**: `fix/merge-rebase-racy-git-remedy`
- **Spec**: `specs/merge-rebase-racy-git-remedy/spec.md`
- **Headline**: Infrastructure update — no user-visible change in this PR.
- **Summary**: `/ak-merge-devshop § Phase 1.0` now retries a flaky rebase with `git -c core.checkStat=minimal -c core.trustctime=false rebase "$ANCHOR"` before dropping to the merge fallback. On virtiofs/overlay devcontainers (macOS / linuxkit) `git rebase` intermittently false-aborts with `Your local changes to the following files would be overwritten by merge` on a verifiably clean tree — a stat-cache race, not a real diff. The checkStat-minimal retry sidesteps it while **preserving the rebase** (no transient merge commit for Phase 2's soft-reset to discard), so the merge fallback is demoted to the second rung. The same inline `-c` form is added to the adjacent cherry-pick/`am` recipe, and a one-line `CLAUDE.md § Known Footguns` entry points operators at the remedy. Inline `-c` only (per-command scope) — never repo-global config.
- **Commits**: spec skeleton + expansion, skill reorder + cherry-pick recipe + bats guard, CLAUDE.md footgun, tasks.md, Phase 3 review.md + gate sinks, BUILD-LOG/PLAN + tracker closure; squashed to 1 on main via /ak-merge-devshop.
- **Quality gates**: devshop gate set — Gates 1/4/5/6/11 pass; Gate 2d full bats suite green (1568 passed, 0 failed, incl. the new checkStat-ordering assertion in `util-ak-merge-devshop.bats § Section F2`); Gate 5 docs+tests audit (Audit 1) high=0 medium=0 low=0. 9 non-LLM carve-outs n/a; 4 LLM-mediated structural carve-outs (cso/design-review/qa/benchmark — no UI/auth/perf surface). Phase 2.5 fresh-eyes: 0 findings.

### merge-devshop-phase25-tree-pin (2026-05-29)

- **Branch**: `fix/merge-devshop-phase25-tree-pin`
- **Spec**: `specs/merge-devshop-phase25-tree-pin/spec.md`
- **Headline**: Infrastructure update — no user-visible change in this PR.
- **Summary**: Hardens `/ak-merge-devshop`'s pre-merge bats gate (Phase 2.5) so a parallel merge running at the same time can't trick it into reading a green result from the wrong checkout and fast-forwarding a red test suite onto `main`. The gate now resolves `$BATS_CWD` to an absolute path, pins `EXPECTED_SHA` to the squash commit (`$BRANCH` tip), and asserts the tested `HEAD` equals it both before and after the suite — halting if a sibling session moved the checkout mid-flow. Mirrors the existing Phase 3 checkout-verification guard. Closes the `kit/TODOS.md` HEAD-race entry (worked incident `1d343bf`, 2026-05-28) and adds 5 content-validation bats tests in `util-ak-merge-devshop.bats § Section G2`; workflow.md's `/ak-merge-devshop` row now documents the new guard.
- **Commits**: squashed to 1 on main via /ak-merge-devshop (spec skeleton + expansion, guard + tests + TODO closure, Phase 2.5 verification, Phase 3 review.md + workflow.md doc note; two `origin/main` merge commits collapsed by the squash).
- **Quality gates**: devshop gate set — Gates 1/4/6/11 pass; Gate 2d full bats suite green (1567 passed, 0 failed); Gate 5 docs+tests audit high=0 medium=1 (workflow.md Phase 2.5 doc-coverage — fixed in-branch) low=0. 9 non-LLM carve-outs n/a; 4 LLM-mediated structural carve-outs (cso/design-review/qa/benchmark — no UI/auth/perf surface). Phase 2.5 fresh-eyes: 0 findings (dry-ran the guard against a scratch repo — confirmed it catches a mid-flow HEAD flip). Side-effect: surfaced + fixed a pre-existing red (`reconcile-task-commits.sh` unwired since `ca4bc76`) on a separate `fix/` branch landed first (`bb3e13c`).

### claude-md-regrowth-prune (2026-05-29)

- **Branch**: `feat/claude-md-regrowth-prune`
- **Spec**: `specs/claude-md-regrowth-prune/spec.md`
- **Headline**: Infrastructure update — no user-visible change in this PR.
- **Summary**: Completes the devshop `CLAUDE.md` regrowth prune the 2026-05-27 hygiene build under-delivered. Trims four sections (Session Start hook internals, two-repos shipping procedure, locked-file mechanics, the now-loud-caught commit-to-main footgun) to pointers at the guide docs that already own the detail — conservatively keeping every project-bridging convention and silent-failure trap, since the SessionStart hook delivers devshop `CLAUDE.md` to project sessions and guides aren't auto-loaded there (CLAUDE.md 30008 → 28432 chars). Closes the stale `claude-md-hygiene` ROADMAP/PLAN trackers (both deliverables shipped 2026-05-27, squash `f875263`) and files a Layer-B classification-gate squash-boundary coverage gap to `kit/TODOS.md`.
- **Commits**: 9 atomic commits (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: devshop gate set — Gates 1/4/6/11 pass; Gate 2d bats full suite green; Gate 5 docs+tests audit high=0 medium=0 low=2 (advisory). 9 non-LLM carve-outs n/a; 4 LLM-mediated structural carve-outs (cso/design-review/qa/benchmark — no UI/auth/perf surface). Phase 2.5 fresh-eyes: 0 prune findings. (Phase 2.5 also surfaced a pre-existing red bats test 729 — `reconcile-task-commits.sh` unwired since `ca4bc76`; a parallel branch fixed it independently on `main` via `bb3e13c` before this merge, so the redundant in-branch fix nets out at rebase.)

### ak-build-commit-spec-expansion (2026-05-29)

- **Branch**: `feat/ak-build-commit-spec-expansion`
- **Spec**: `specs/ak-build-commit-spec-expansion/spec.md`
- **Headline**: Infrastructure update — no user-visible change in this PR.
- **Summary**: `/ak-build` now commits the expanded `spec.md` at the end of Phase 1 (a guarded, idempotent `docs(<feature>): expand spec (Phase 1)` commit), so a crash between Phase 1 and the next sweeping commit can't silently lose the spec expansion or trigger an unnecessary re-spec on resume. The Phase-exit artifact registry row for Phase 1 and Step 0's resume rungs 4/5 (plus the preamble + discriminator note) are tightened to read committed state (`git show HEAD:$FEATURE_DIR/spec.md`), so the durable signal a resume reads is the committed spec, not the working tree — closing the loop against a torn-down worktree, clean-tree guard, or stray stash. Single production file (`.claude/skills/devshop/build/SKILL.md`); covered by four new structural assertions (Section G) in `kit/tests/util-ak-build-skill.bats`.
- **Commits**: 8 atomic commits (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: devshop gate set — Gates 1/4/6 pass, Gate 11 convention surfaced + fixed 1 finding (the source kit/TODOS.md entry was still open; closed with the PLAN row in `c64de2c`), Gate 2d bats targeted 46/46 + full sweep green (the one pre-existing `structural-invariants.bats` reconcile-task-commits wiring failure was fixed upstream in `bb3e13c` and merged in at merge time; the branch's stale TODOS-routing entry was dropped accordingly). Gate 5 audit high=0 medium=0 low=1 (preamble committed-state clause, fixed at `26233da`). 9 non-LLM carve-outs n/a; 4 LLM-mediated structural carve-outs (cso/design-review/qa/benchmark — no UI/auth/perf surface). Phase 2.5 fresh-eyes: 0 findings across 6 checks.

### implement-resume-reconcile (2026-05-29)

- **Branch**: `feat/implement-resume-reconcile`
- **Spec**: `specs/implement-resume-reconcile/spec.md`
- **Headline**: A build interrupted mid-implementation now re-checks its own progress against git on resume instead of trusting a checklist — so an unfinished step can't silently slip through as "done".
- **Summary**: `/ak-build` Phase 2 resume reconciles the `done` markers in `tasks.md` against actual git state (a clean working tree plus at least as many implementation commits as `done` tasks) before skipping the implement phase. A dropped `/ak-implement` subagent that marked tasks done-before-commit no longer causes the orchestrator to advance to pre-ship with uncommitted or never-started work. A new bats-covered `kit/scripts/reconcile-task-commits.sh` does the check (rebase- and amend-robust — it counts commits and inspects the tree rather than pinning SHAs); the `done`-means-`committed` contract is reaffirmed in `/ak-implement`.
- **Commits**: 13 atomic commits (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: devshop gate set — Gates 1/4/6/11 pass (Gate 6 surfaced 1 low CRLF finding, fixed at `a793b1b` + regression case 9), Gate 2d bats 1546/1546, Gate 5 audit high=0 medium=0 low=1 (informational; tests exceed spec). 9 non-LLM carve-outs n/a; 4 LLM-mediated structural carve-outs (cso/design-review/qa/benchmark — no UI/auth/perf surface). Phase 2.5 fresh-eyes: 1 fixed (restored a workflow.md sentence a doc-sweep dropped).

### hygiene-threedot-polish (2026-05-28)

- **Branch**: `feat/hygiene-threedot-polish`
- **Spec**: `specs/hygiene-threedot-polish/spec.md`
- **Headline**: Infrastructure update — no user-visible change.
- **Summary**: Hardens the shipped dimension-(d) three-dot phantom-surface fix (`b174a11`) by closing the two non-blocking lows its Audit 1 flagged: (1) a cross-ref clause in `workflow.md` (and a complementary NOTE 3 description in `hooks.md § Dual-surface check-types`) so a reader doesn't infer the `/ak-merge-devshop` Phase 1.0 rebase alone is the remedy for all base-divergence phantoms — the Phase 0.4.5 dimension-(d) precompute fires BEFORE the rebase and got its own three-dot fix; (2) a positive bats assertion in `util-adversarial-review-narrowing.bats` test 18 that the rendered propagation-surface list is empty, so a differently-broken three-dot producing a _different_ phantom path can't slip past the existing one-filename absence check. The suggested `grep "If the list is EMPTY"` assertion was rejected (empirically verified static NOTE 3 boilerplate — zero discriminating power); the region-empty awk check replaced it. No script/behavior change — `adversarial-review.sh` untouched.
- **Commits**: 3 substantive (workflow.md cross-ref, hooks.md NOTE 3, bats test 18) + Phase 2.5 NOTE-count fix; squashed to 1 on merge.
- **Quality gates**: all passed (6 dispatched + 13 carve-outs; full bats suite green). Pre-existing unrelated failure (stale Phase 6 test 14 from `1d343bf`) fixed first on a separate `fix/` branch and landed to main before this feature's gates ran.

### template-csp-img-src (2026-05-28)

- **Branch**: `feat/template-csp-img-src`
- **Spec**: `specs/template-csp-img-src/spec.md`
- **Headline**: Storage photos (avatars, card images, any signed-URL image) now render correctly in local development and browser QA out of the box — no more silently-blank image boxes the first time a project shows a Supabase Storage image.
- **Summary**: The Pattern 2 CSP boilerplate now derives the `img-src` Supabase origin from `$NEXT_PUBLIC_SUPABASE_URL` (the same way `connect-src` already does), so the local stack's `http://host.docker.internal:<port>` Storage origin — which no `https:` token covers — is permitted in dev/QA, and the prod origin is covered too when the base omits a broad `https:` token. Folded `img-src` into the Pattern 2 inline IIFE (one trimmed origin reused for both directives, with a load-bearing don't-delete comment); added a new `### CSP` sub-section to `conventions.md`; touched up the template `next.config.ts` header pointer; repointed the Pattern 2 anchor refs (in-file TOC + routing index) after the heading rename.
- **Commits**: 11 atomic commits (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: devshop gate set — Gates 1/4/6/11 pass, Gate 2d bats 1525/1526 (the 1 failure is pre-existing test 14 from `1d343bf`, filed in `kit/TODOS.md`, unrelated to this diff), Gate 5 audit high=0 medium=1 low=0 (the medium is the `template/**` `**Existing projects:**` block, deferred to the squash body per D4). 9 non-LLM carve-outs n/a; 4 LLM-mediated structural carve-outs (cso/design-review/qa/benchmark — no UI/auth/perf surface). Phase 2.5 fresh-eyes: 1 fixed (conventions TOC), 1 escalated→filed.

### ak-build-phase6-pr-surface (2026-05-28)

- **Branch**: `feat/ak-build-phase6-pr-surface`
- **Spec**: `specs/ak-build-phase6-pr-surface/spec.md`
- **Headline**: `/ak-build` no longer drops a gate-status comment on your PRs, and it now reviews the PR description itself instead of pausing to ask you to confirm it.
- **Summary**: Phase 6 stops posting the audit-trail comment — gate results stay in the committed `review.md`. Part D's Gate A now reviews the Product-update blurbs against the diff autonomously (mirroring Parts A/B/C), escalating to the operator only when a real claim-vs-diff mismatch needs a product-judgment call the diff can't settle. Completes a partial cleanup: the PR body + Phase 7 comment were stripped in a prior PR but Phase 6 was missed. The consistency sweep extended across 9 files (build/SKILL.md + 6 sibling skills + workflow.md/FAQ.md/conventions.md) so no doc still frames Phase 6 as posting a comment or Gate A as always asking.
- **Commits**: 11 atomic commits (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: 1527 bats pass (3 new/rewritten Phase 6 assertions in `util-product-update-blurb.bats`: Gate A autonomous, escalation-only prompt, Phase 6 posts no audit comment). Phase 2.5 fresh-eyes verification caught + fixed 12 dangling cross-references across 8 files (the comment-removal half). Gate 1 docs-check: 3 more residual Gate-A-autonomy refs fixed (conventions.md, spec/SKILL.md, build/SKILL.md). Gate 5 audit: high=0 medium=0 low=1 (fixed: stale Phase-7-comment surface ref). Gate 6 /review: low=1 (tracker-closure timing note — closed here). Gates 2d/4/11 clean; 7/8/9/10 structural carve-outs (devshop self-mode); 9 non-LLM carve-outs n/a.

### ak-build-no-silent-scope-down (2026-05-28)

- **Branch**: `feat/ak-build-no-silent-scope-down`
- **Spec**: `specs/ak-build-no-silent-scope-down/spec.md`
- **Headline**: `/ak-build` now always runs its complete pipeline — spec, implement, quality gates, bookkeeping, and audit trail — for every task no matter how small. If a lighter flow ever genuinely seems warranted, it stops and asks you first instead of silently improvising one.
- **Summary**: Adds a prominent prohibition block at the top of `build/SKILL.md` (Step 0 / Phase 0) that removes the agent's discretion to hand-roll a reduced flow; the only escape is an explicit `AskUserQuestion` with full-pipeline as the recommended default. Backed by a one-line restatement at the Phase 0 decision beat and a bats regression guard. No script changes, no behavior change to any phase's mechanics. Closes the home-os PR #40/#41 failure class (2026-05-28) where `/ak-build` silently hand-rolled a direct implementation — dropping `specs/<feature>/`, BUILD-LOG, PLAN tracking, and the audit comment with no operator signal.
- **Commits**: 8 (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: 1525 bats pass (6 new Section E tests in `util-ak-build-skill.bats`, incl. the load-bearing anti-bias absence-assertions). Phase 2.5 fresh-eyes verification clean (0 findings, 120 tests across 3 suites). Gate 5 audit: high=0, medium=0, low=1 (prose-grep coverage ceiling — acceptable). Gate 6 /review: low=1 (test-precision nit — fixed: anchored the AskUserQuestion grep to the block region). Gates 1/2d/4/11 clean; 7/8/9/10 structural carve-outs (devshop self-mode); 9 non-LLM carve-outs n/a.

### ak-merge-rebase-before-audit (2026-05-28)

- **Branch**: `fix/ak-merge-rebase-before-audit`
- **Spec**: `specs/ak-merge-rebase-before-audit/spec.md`
- **Headline**: Merging a devshop branch whose base has fallen behind `main` no longer produces bogus "this reverts X" findings in the pre-merge audit — the merge runs clean instead of stalling on a phantom blocker.
- **Summary**: `/ak-merge-devshop` now rebases the feature branch onto its merge target (the same `$ANCHOR` the squash lands on) **before** the Phase 1 `/ak-check-docs-and-tests` audit, and audits the precise `$ANCHOR..HEAD` delta. Previously the audit ran on the un-rebased branch against the default `origin/main..HEAD` two-dot range; when the branch was created off an older `main` (common for a worktree that has sat through a few merges), `origin/main` was not an ancestor of the branch tip, so everything that landed on `main` since the branch point surfaced as phantom deletions/reverts — wasting an audit cycle and risking a spurious abort of a valid merge. New Phase 1.0 carries the rebase (with anchor detection + virtiofs phantom-error → merge fallback); Phase 1.1 is the audit; Phase 2 keeps only soft-reset + commit. Codified from the 2026-05-28 `go-live-prod-url-extraction` merge.
- **Commits**: 8 (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: 1503 bats pass (96 in `util-ak-merge-devshop.bats`, incl. 5 new Section F2 assertions + a Phase 2 no-rebase regression guard). Phase 2.5 fresh-eyes verification caught + fixed 1 cross-doc gap (devshop-mode.md double-audit no-op claim). Gate 5 audit: high=0, medium=1 (TODOS/PLAN closure — done here), low=1 (Phase 0.2 display reword — fixed). Gates 4, 6 clean; 7/8/9/10 structural carve-outs (devshop self-mode).

### local-env-pillar (2026-05-27)

- **Branch**: `feat/local-env-pillar`
- **Spec**: `specs/local-env-pillar/spec.md`
- **Headline**: Local environment health checks now run automatically before every browse, QA, and screenshot operation — broken environments halt the pipeline instead of silently skipping gates.
- **Summary**: Three coordinated fixes: (A) `local-env-health.sh` preflight script verifying dev server, Supabase, memory, and zombie processes with auto-recovery; (B) `roster-check.sh` + `check-llm-mediated-na.sh` deterministic scripts replacing prose-level gate enforcement in Phase 3; (C) migration rollback FK convention documented in `kit/docs/guide/migrations.md`. Closes the home-os PR #36 failure class where OOM + zombie processes caused silent gate skips and 5 CI fix cycles.
- **Commits**: 16 (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: 1456 bats pass (35 new across 3 test files). Gate 4 found 2 simplifications (fixed). Gate 6 found 1 correctness bug in `recover` — was killing all port occupants, fixed to kill only zombies. Gates 1, 5, 11 clean.

### claude-md-hygiene (2026-05-27)

- **Branch**: `feat/claude-md-hygiene`
- **Spec**: `specs/claude-md-hygiene/spec.md`
- **Headline**: Changes to the project instructions file now go through an automated routing check — traps stay, everything else moves to its canonical home.
- **Summary**: New pre-commit gate fires on any CLAUDE.md edit that adds or modifies content. Requires per-entry classification (trap / reference / convention) via adversarial-reviewed bypass trailer. Reference and convention content must be relocated before the commit lands. Includes audit sweep of devshop CLAUDE.md to relocate ~9k of regrowth since the May cleanup, and convention doc update documenting the new mechanical gate.
- **Commits**: 11 (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: 1431 bats pass (10 new). Gate 4 found 2 cosmetic issues (fixed). Gates 5, 6 found doc inconsistencies (fixed). All 6 dispatched gates clean.

### lint-staged-rename-symlink (2026-05-27)

- **Branch**: `fix/lint-staged-rename-symlink`
- **Spec**: `specs/lint-staged-rename-symlink/spec.md`
- **Headline**: Pre-commit hooks no longer fail on rename-plus-symlink diffs — lint-staged's stash backup is disabled, unblocking squash-merge on these combos.
- **Summary**: Add `--no-stash` flag to `pnpm exec lint-staged` in both devshop and template pre-commit hooks. This disables lint-staged's `git stash` backup (the source of the `error: 'OLD/file' is beyond a symbolic link` failure on rename+new-symlink diffs). Side effect: also disables `hidePartiallyStaged` (acceptable — partial staging is uncommon). Bats convention test guards the flag against hook regeneration. 7 stale doc references updated (hooks.md, CLAUDE.md, architecture.md).
- **Commits**: 8 (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: 1406 bats pass (4 new convention tests). Gate 1 caught 7 stale doc references to lint-staged stash behavior (fixed). Gates 4, 5, 6, 11 clean.

### rollback-prose-lint (2026-05-27)

- **Branch**: `feat/rollback-prose-lint`
- **Spec**: `specs/rollback-prose-lint/spec.md`
- **Headline**: Migration rollback blocks are now validated at commit time, not just in CI.
- **Summary**: New pre-commit lint (`check-rollback-prose.sh`) scans `-- ROLLBACK:` blocks in staged migration files for prose lines that would break `ci-rollback-explain.sh`'s prefix-stripping logic with SQL syntax errors. Catches the home-os PR #35 failure pattern locally instead of after an 8-minute CI round-trip.
- **Commits**: 9 (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: 14 bats tests in `guard-rollback-prose.bats`. All 1397 bats pass. Gate 2d caught 2 issues (router test stubs + file permissions — fixed). Gate 4 caught 1 simplification (dead code branch — fixed). Gate 5 noted 2 medium test coverage gaps (non-blocking).

### fix-branch-guard-on-main (2026-05-26)

- **Branch**: `fix/fix-branch-guard-on-main`
- **Spec**: `specs/fix-branch-guard-on-main/spec.md`
- **Headline**: Prevent Claude from accidentally committing to main when parallel sessions switch branches.
- **Summary**: Close the TOCTOU race between the PreToolUse `check-branch-not-main.sh` hook and actual `git commit` by adding a Claude-specific (`$CLAUDECODE=1`) branch guard in `.husky/pre-commit`. The PreToolUse hook stays as fast feedback; the husky guard is the backstop that runs at actual commit time with no race window. Bats tests cover both layers.
- **Commits**: 9 (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: 1393 bats pass. Gate 1 caught missing docs in hooks.md + OVERVIEW.md (fixed). Gate 6 caught incorrect project-repo step count (fixed). 10 new tests across 2 files.

### merge-devshop-rename-detect (2026-05-26)

- **Branch**: `feat/merge-devshop-rename-detect`
- **Spec**: `specs/merge-devshop-rename-detect/spec.md`
- **Headline**: The devshop merge skill now auto-detects rename-plus-symlink combos that would crash lint-staged, and offers a clean ff-merge fallback instead of failing mid-squash.
- **Summary**: `/ak-merge-devshop` Phase 2 gains a pre-commit detection step: after `git reset --soft` stages the squash delta, scan `git diff --cached --name-status` for `R<sim> OLD → NEW` + `A OLD` collisions. On hit, unstage (`git reset`), surface the issue, and offer `git merge --ff-only` as the fallback — same file-system end state, N separate commits instead of 1 squash. Known limitations section updated from "manual recovery" to "auto-detected".
- **Commits**: 9 (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: 9 new bats tests (section L) in `util-ak-merge-devshop.bats`. All 1392 bats pass. Gate 6 caught missing detection guard on merge-fallback path (fixed: added prose comment referencing primary detection block).

### keepalive-supabase-ping (2026-05-24)

- **Branch**: `feat/keepalive-supabase-ping`
- **Spec**: `specs/keepalive-supabase-ping/spec.md`
- **Headline**: Keepalive workflow now pings Supabase directly and runs twice weekly, preventing auto-pause on quiet projects.
- **Summary**: Template `keepalive.yml` gains a second step that hits the Supabase PostgREST health endpoint (`/rest/v1/`) with the anon key, registering as API activity. Cron bumped from weekly to twice-weekly (Mon + Thu) for margin against Supabase's 7-day inactivity window. Existing Vercel ping retained. Uses prod-specific variable names (`SUPABASE_PROD_URL`, `SUPABASE_PROD_ANON_KEY`) to avoid collision with CI's localhost-scoped variables.
- **Commits**: 7 (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: 9 new bats tests in `template-keepalive-yml-shape.bats`. All 1325 bats pass. Gate 1 caught CI credential collision (fixed: prod-specific variable names). Gate 5 caught missing ops.md GH Variables entry (fixed).
- **Existing projects**: `keepalive.yml` is `[sync]` — `from-devshop.sh` delivers the file change automatically on next container rebuild or manual sync run. Operator must also add two GitHub Variables manually: `SUPABASE_PROD_URL` (project's Supabase URL, e.g. `https://xyz.supabase.co`) and `SUPABASE_PROD_ANON_KEY` (project's anon key — public/anon-tier, not secret). Currently affects: home-os, lalista.

### ak-build-devshop-mode (2026-05-24)

- **Branch**: `feat/ak-build-devshop-mode`
- **Spec**: `specs/ak-build-devshop-mode/spec.md`
- **Headline**: Infrastructure update — /ak-build now auto-detects devshop mode.
- **Summary**: /ak-build detects GIT_ROOT=/devshop and adapts: reduced gate set (6/19), /ak-merge-devshop transport, no Phase 5-7. Phase 4.0 BUILD-LOG + PLAN closure fires by construction, closing the ad-hoc bookkeeping gap. Implemented as a sub-file (devshop-mode.md) referenced from SKILL.md.
- **Commits**: 5 (squashed to 1 on main via /ak-merge-devshop)
- **Quality gates**: Audit 1 (manual): high=0 medium=6 low=1 — all 6 medium findings fixed in-branch (3 docs fixes + 27 bats tests added)

### sync-show-first-confirm (2026-05-24)

- **Branch**: `feat/sync-show-first-confirm` (squashed to main via `/ak-merge-devshop`)
- **Spec**: `specs/sync-show-first-confirm/spec.md`
- **Headline**: Sync scripts now show a preview of proposed changes and ask for confirmation before modifying any files — no more silent overwrites.
- **Summary**: `from-devshop.sh` and `to-devshop.sh` gain a two-pass dry-run-then-apply flow: stage proposed changes to `/tmp/sync-preview-$$/`, display a unified diff with file-count summary, then prompt `y/N/diff` via `/dev/tty`. `--yes`/`-y` flag bypasses the prompt for CI. Architecture doc rewritten from "apply-first-show-after" to "show-first-confirm-then-apply". Smoke-test finding: rsync `-a` skips same-size files with matching mtime — added `-c` (checksum) flag; also fixed false "deleted" entries in preview for excluded files.
- **Commits**: 5 atomic commits per `/ak-build`
- **Quality gates**: 17 new bats tests in `sync-preview-confirm.bats`. All 1283 bats pass.

### template-plan-md-schema-uplift (2026-05-24)

- **Branch**: `feat/template-plan-md-schema-uplift`
- **Spec**: `specs/template-plan-md-schema-uplift/spec.md`
- **Headline**: New projects get the full priority-scored planning table out of the box — leverage formula, dependency tracking, and source pointers included.
- **Summary**: Rewrite `template/PLAN.md` from the old 3-column simple schema (`# / Feature / Notes`) to the devshop's rich 8-column Lev-scored schema (`Feature / Hook / Impact / Risk / Cost / Lev / Deps / Source`). Adds `## How to add entries` prose block with column definitions, rating scale table, Deps glyphs, lifecycle rules. Adapts Source pointers to project-side files (`PRODUCT-ROADMAP.md` / `TODOS.md`). Drops `## Bundling cheatsheet` (overkill for project-side planning). Fixes `session-start.sh` project-session parser to handle the new backtick-slug schema (old parser expected numbered rows). Both devshop and project Planned-row parsers now stop at HTML comments to avoid matching example rows inside `<!-- -->` blocks. `/ak-spec § Step 4` verified compatible — Active table stays 3-column; rich Planned columns dropped on transition.
- **Commits**: 3 (spec skeleton + template rewrite with tracker cleanup + session-start.sh parser fix).
- **Quality gates**: 1266/1266 bats pass. Pre-commit guards pass on all commits.

### existing-projects-commit-convention (2026-05-24)

- **Branch**: `feat/existing-projects-commit-convention` (squashed to 1 commit on `main` via `/ak-merge-devshop`)
- **Spec**: none — small devshop convention codification, ad-hoc.
- **Headline**: Devshop commits that affect existing projects now require an explicit migration-impact block in the commit body.
- **Summary**: Codifies the `**Existing projects:**` commit-body block as a required convention for any devshop change with a per-project migration step. New `## Existing-Project Migration Block` section in `conventions.md` with trigger table (by manifest lifecycle tag), two shape variants (no-migration-needed vs per-project recipe), and three worked precedent commits. Audit-time enforcement via `/ak-docs-review` Section A (medium coverage finding). `/ak-merge-devshop` § 0.3 lead-in labels updated with the new label. Closes PLAN row `existing-projects-commit-convention` and Part 2 of `kit/TODOS.md § Per-project catch-up workflow`.
- **Commits**: 1 atomic commit on `feat/existing-projects-commit-convention`.
- **Quality gates**: 6 structural invariant assertions pinning convention doc structure and cross-references. All 1272 bats pass.

### kit-scripts-deny-rule-investigation (2026-05-23)

- **Branch**: `fix/kit-scripts-deny-rule-investigation` (squashed to `c74d2db` on main via `/ak-merge-devshop`)
- **Spec**: none — small devshop security fix, ad-hoc.
- **Summary**: Closes the `kit/scripts/**` deny rule investigation by removing the two relative deny patterns (`Edit(kit/scripts/**)` + `Write(kit/scripts/**)`) and keeping only the absolute-path variants. **Root cause**: worktree paths (`/devshop/.worktrees/<topic>/kit/scripts/...`) escaped both the relative and absolute deny patterns; the relative pattern matched unpredictably (allowed when Edit received a relative path, denied when it received an absolute worktree path), causing mid-session enforcement flips where edits to the same file alternated between allowed and denied (worked incident: `feat/phase3-blocked-halt`, 2026-05-20). After the fix, enforcement is deterministic: canonical `/devshop/kit/scripts/**` denied (Layer 1 + Layer 2 filesystem lock), worktree `.worktrees/<topic>/kit/scripts/**` allowed (development copies). `security.md` (deny-pattern code block, Guard Script Editing, Authoring locked files) rewritten to canonical-tree-only language. `CLAUDE.md § Known Footguns` denied-paths enumeration updated with worktree caveat. ROADMAP entry + PLAN.md row both deleted on ship per close-on-ship convention.
- **Commits**: 1 atomic commit on `fix/kit-scripts-deny-rule-investigation`, collapsed to 1 squash on `main` per `/ak-merge-devshop`. Final squash SHA: `c74d2db`.
- **Quality gates**: new structural-invariant test asserts `settings.json` has the absolute deny patterns and does NOT have the relative ones (prevents silent re-introduction). All existing bats pass.

### conventions-md-lift-vs-cross-ref (2026-05-23)

- **Branch**: `chore/conventions-md-lift-vs-cross-ref` (squashed to `1d6c017` on main via `/ak-merge-devshop`)
- **Spec**: none — small devshop convention rewrite, ad-hoc.
- **Summary**: Closes the conventions.md audit ROADMAP entry — when a `conventions.md` section has a single consuming skill that replicates its content, the skill's `SKILL.md` is canonical and `conventions.md` keeps a one-line stub pointer. Deploy Boundaries content lifted into `.claude/skills/devshop/go-live/SKILL.md` (surface table, schema-mutation safety, rollback, CI credential separation); Testing Lifecycle table lifted into `.claude/skills/devshop/implement/SKILL.md` (7-stage per-task → pre-ship pipeline). 4 already-replicated sections stubbed in `conventions.md`: DESIGN.md as Contract, Screenshot Routing, Test Assertion Depth, Backlog Routing Guide. Cross-refs in 5 skill `SKILL.md` files updated to point at canonical homes; 6 cross-refs in guide docs (`ops.md`, `migrations.md`, `OVERVIEW.md`, `README.md`) updated to point directly at canonical skill homes. `conventions.md` preamble replaced with convention placement rule (tier table + canonical-home decision rule). `conventions.md` ToC annotated with stub destinations. `CLAUDE.md` trailing reference updated (backlog routing now covered by `§ TODO Protocol`). Closes the "paper rule" gap where Tier 3 conventions never entered agent context. ROADMAP audit entry (72 lines) deleted on ship per close-on-ship convention.
- **Commits**: 1 atomic commit on `chore/conventions-md-lift-vs-cross-ref`, collapsed to 1 squash on `main` per `/ak-merge-devshop`. Final squash SHA: `1d6c017`.
- **Quality gates**: structural-invariants tests verify the stub destinations point at existing skill section anchors. All existing bats pass.

### supabase-port-series-and-sync-safety (2026-05-23)

- **Branch**: `fix/pnpm-modules-purge-ci-bypass` (squashed to `17c1969` on main via `/ak-merge-devshop`)
- **Spec**: none — ad-hoc devshop fix bundle that grew into a three-feature port series.
- **Summary**: Closes the full Supabase port-collision class across concurrent projects via three feature deliverables shipped as one squash. **(1) `supabase/config.toml` as single source of truth** — `derive-ports-from-config.sh` reads all 5 port sections and upserts `SUPABASE_*_PORT` keys into `.devcontainer/.env` on every container start; chained in `devcontainer.json`'s `initializeCommand` + backstop in `init-devshop.sh`. **(2) Five-port parameterization** across `template/.devcontainer/compose.yml`, `init-firewall.sh`, 3 preship scripts (`supabase-bootstrap.sh`, `advisor-clean.sh`, `migration-rollback-roundtrip.sh`), 3 template scripts (`advisor-probe.mjs`, `ci-rollback-explain.sh`, `inbucket.ts`) — extends API+DB-only env-driven shape to all 5 rebound ports (api/db/studio/mailpit/analytics); init-firewall.sh uses `${VAR:?required}` for fail-loud on missing keys. **(3) `/ak-new-project` Phase A auto-assigns** next-free 100-block from `kit/notes/projects/*.md` frontmatter (via `next-port-offset.sh`), runs `supabase init` + 5-port sed + `additional_redirect_urls` fix (`http://127.0.0.1:3000/**` + `http://localhost:3000/**`, closes magic-link `/auth/callback` PKCE-exchange bug from home-os PR #15), derives `.env`, and registers offset in the project's notes frontmatter. `apply-port-offset.sh` recovers after `supabase init` resets; `check-port-offset-unique.sh` pre-commit guard wired into devshop + devshop-self modes. Bundles sync safety fixes: `from-devshop.sh`/`to-devshop.sh` `PROJECT_ROOT` math corrected (3 levels up, not 2); both sync scripts now exclude `[locked]` + `[scaffold-once]` + `!path` leaves under `[sync]` directories to prevent `.env` deletion and template-owned file clobber. Plus the original pnpm modules-purge `CI=true` bypass that named the branch — fixes the interactive prompt hang inside `su node -c` (pnpm 10.16.0+ requires real raw-mode keypress; no controlling terminal under `su` means hang). Closes home-os Mailpit firewall-REJECT + Gate 9 false-`degraded` bites; closes PLAN.md rows `supabase-config-toml-source`, `supabase-five-port-extend`, `ak-new-project-port-registry`. ROADMAP umbrella entry + 3 SHIPPED-tagged sub-entries cleaned up in follow-on commit per close-on-ship convention.
- **Commits**: 18 atomic commits collapsed to 1 squash on `main` per `/ak-merge-devshop` (per-commit SHAs recoverable via `git reflog` for ~90 days). Final squash SHA: `17c1969`.
- **Quality gates**: 1265/1265 bats pass (12 new port-registry + 14 derive-ports + 17 init-firewall + 28 compose-isolation structural-invariants updated). `.env.example` template added as `[scaffold-once]`. `specs/*/screenshots/` added to template `.gitignore` (was missing; caused sync clobber). `sync-show-first-confirm` PLAN.md row added at Lev 3.6 as preview-before-apply follow-up.

### ci-rollback-explain-marker-loud (2026-05-19)

- **Branch**: `feat/ci-rollback-explain-marker-loud` (squashed to main via `/ak-merge-devshop`)
- **Spec**: none — small devshop fix, ad-hoc.
- **Summary**: Closes sub-fix A of the original `ak-pre-ship-migration-rollback-gate` ROADMAP entry — `template/scripts/ci-rollback-explain.sh` no longer silently SKIPs migrations that lack a `-- ROLLBACK:` marker. The script now scans every migration up front, collects markerless / empty-block offenders, and FAILs loudly with a recipe pointing the operator at the marker mandate + the noop escape hatch. Migrations with nothing to undo can carry a single body line `-- noop: forward is idempotent`; the script detects `noop:` (case-insensitive, post-`-- ` strip), skips the rollback apply step, and still re-applies forward — which is what closes the cascade-loss hole (upstream `drop table` rollbacks no longer leave markerless downstream columns permanently gone for the rest of CI). Background: home-os PR #28's 6-attempt CI fix-loop burned ~2.5 hours chasing PostgREST 204 when the root cause was a markerless migration. With the convention already codified (conventions.md § ci-rollback-explain.sh, 2026-05-18) and Gate 2e shipped locally (2026-05-17), the only remaining piece was the CI script itself — which this branch ships. **Parity follow-up** (second commit, same branch): the local Gate 2e (`kit/scripts/preship/migration-rollback-roundtrip.sh`) was tightened to the same loud-fail contract — markerless migrations surface as findings instead of silent-skipping, the noop escape hatch is recognized identically, and the legacy `n/a (rollback convention not adopted)` outcome was dropped (convention is mandatory devshop-wide). Without this, locally-green PRs could surprise the operator at CI's slow-job; with it, pre-ship parity is restored. The conventions.md § ci-rollback-explain.sh entry was rewritten to swap "the script SKIPs markerless migrations" for the new FAIL-loud contract + noop escape hatch; the pre-ship SKILL.md (Gate 2e § Scope + § Loop + § Outcomes) was updated to match. Closes `PLAN.md` row `ci-rollback-explain-marker-loud` + the residual `kit/ROADMAP.md § /ak-pre-ship migration-rollback gate` entry (A + parity shipped here; B at `7262fac`; C functionally covered by conventions.md § ci-rollback-explain.sh).
- **Commits**: 2 atomic commits on the feature branch (`0d8f8a1` template script + conventions + PLAN/ROADMAP close, then parity commit for local Gate 2e + bats + SKILL.md); collapsed to 1 squash on `main` per `/ak-merge-devshop`; per-commit SHAs recoverable via `git reflog` for ~90 days.
- **Quality gates**: 4 new bats invariants added to `kit/tests/preship-migration-rollback-roundtrip.bats` (markerless single → findings, markerless in mixed set → finding without flagging others, noop hatch → pass, empty block → finding). 2 existing tests rewritten (markerless n/a/pass → findings) per parity contract. Total **16 bats pass** (was 13 pre-parity). CI template script exercised in CI's slow-job; no new bats added there.

### ak-pre-ship-migration-rollback-gate (2026-05-17, sub-fix B only)

- **Branch**: `feat/ak-pre-ship-migration-rollback-gate` (squashed to `7262fac` on main via `/ak-merge-devshop`)
- **Spec**: `specs/ak-pre-ship-migration-rollback-gate/review.md` (audit-only; no spec.md — ad-hoc devshop feature)
- **Summary**: Ships **sub-fix B** of the three-deliverable `ak-pre-ship-migration-rollback-gate` PLAN row — a new `/ak-pre-ship` Gate 2e that round-trips every migration's `-- ROLLBACK:` block against the local Postgres in ~30s, catching rollback bugs that `db:reset` / forward-apply don't exercise (the class home-os PR #26 + #27 both hit and only discovered at CI's slow-job ~10 min in). New `kit/scripts/preship/migration-rollback-roundtrip.sh` is diff-scoped to `supabase/migrations/**`, probes both candidate DB URLs (`host.docker.internal:54322` compose-shape + `localhost:54322` docker-bind legacy), per-migration applies the rollback SQL then re-applies the forward migration, collects every failure with psql ERROR line + fix-recipe pointing at `IF EXISTS` / enum-narrowing-safe casts. Gate 2e slots between `fast-job-local` (2d) and renumbered `changed-tests-local` (2f) so a broken rollback can't poison the local DB mid-test-walk. **Not shipped here**: sub-fix A (fix `ci-rollback-explain.sh` contract — require `-- ROLLBACK:` markers, fail loudly on marker-less migrations per home-os PR #28's 6-attempt CI fix-loop arc) and sub-fix C (`kit/docs/guide/migrations.md` + `kit/docs/guide/debugging-pgrst-cache.md` codifying the PGRST204 disambiguation recipe). The `kit/ROADMAP.md` entry was rewritten + the `PLAN.md` row reworded post-7262fac to reflect that A and C are still pending — row stays in `## Planned`.
- **Commits**: collapsed to 1 squash on `main` per `/ak-merge-devshop`; per-commit SHAs recoverable via `git reflog` for ~90 days. Final squash SHA: `7262fac`.
- **Quality gates**: 13 new bats invariants pin `n/a` (no migrations / empty dir / no rollback blocks / diff doesn't touch migrations), `blocked` (DB unreachable), `pass` (clean + multi-migration + mixed-with-no-rollback), `findings` (rollback parse error, forward re-apply failure, multi-finding count), `LOCAL_TESTS_BASE_REF` scope behavior. No `devshop.*SkipReason` wired — gate failures mean editing the migration's `-- ROLLBACK:` block, not skipping the gate.

### pipeline-correctness (2026-05-17)

- **Branch**: `feat/pipeline-correctness` (squashed to `fb18c8f` on main via `/ak-merge-devshop`)
- **Spec**: `specs/pipeline-correctness/review.md` (audit-only; no spec.md — ad-hoc devshop feature)
- **Summary**: Two bundled PLAN rows sharing the `/ak-build` + `/ak-check-docs-and-tests` + `/ak-go-live` SKILL surface, shipped in one merge for internal consistency. **(1) `/ak-check-docs-and-tests` Step 5** — orchestrator stages + commits the appended `## Audit N` section atomically per audit; refuses on dirty tree containing anything beyond the audit file, surfaces `UNCOMMITTED:` for the caller to route; never `git stash` / `git restore` (both destroy operator work silently). Closes the orchestrator-side gap home-os PR #10 (2026-05-13) tripped. **(2) `/ak-build` Phase 4.0** — composes + commits the BUILD-LOG entry + removes the `PLAN.md` Active row on the feature branch BEFORE `/ship` pushes, so bookkeeping rides in the original CI cycle. Phase 5.6 rewritten as verification-only (greps for `chore(build-log)` commit; common path no-ops, resume rungs run full procedure + re-watch CI). **Phase 5.7 deleted** — its "watch every push" guarantee folds into 5.3's preamble; Phase 5.8.1's polish-loop CI sanity check is the enforcement point. **Why bundle:** eliminates the ~5-min fixed-cost docs-only push the historic Phase 5.6 triggered (25–50 min/week saved on a small-PR cadence). New BUILD-LOG entry shape omits the explicit `**PR**:` row (PR# rides via squash-merge subject on main). 22 new bats invariants pin Step 5's commit shape, Phase 4.0 presence, Phase 5.6 verify-only rewrite, Phase 5.7 deletion, and 5.3's watch-every-push guarantee; test files switched from hardcoded `/devshop/...` paths to `TESTS_DIR`-relative so they actually validate worktree edits. Doc updates propagated to `workflow.md` diagram + prose + `/ak-go-live` cross-refs, `conventions.md` pointer, `CLAUDE.md` Non-Negotiable, plus a stale-pointer sweep across 5 sibling reference docs (`BUILD-LOG.md` intro, `template/BUILD-LOG.md` intro, `CLAUDE.md § Known Footguns` line citing the deleted Phase 5.7, `spec/SKILL.md` Step 4, `migrate-project/SKILL.md` lines 80 + 108) surfaced by `/ak-docs-review` Audit 1 inside `/ak-merge-devshop` Phase 1 and closed in the same branch. Closes `kit/TODOS.md` entries (orchestrator audit-commit gap, fold Phase 5.6 bookkeeping into `/ship`, `gh pr merge --delete-branch` silent local-cleanup swallow) + `PLAN.md` rows `ak-build-pipeline-correctness` + `fold-build-log-into-ship-push`.
- **Commits**: 3 constituent commits (`fe192d2` feat-shape, `e4c5800` audit-driven stale-pointer sweep, `bd79f17` Audit 1 record) collapsed to 1 squash on `main` per `/ak-merge-devshop`; SHAs recoverable via `git reflog` for ~90 days.
- **Quality gates**: Audit 1 clean (0/0/0) at `bd79f17` — recorded one `Docs-Coverage-Bypass:` trailer (Layer 1 over-fire on `template/**` for the single-line `template/BUILD-LOG.md` intro pointer-correction; verified). 893/893 BATS green at commit time (873 existing + 22 new pinning Phase 4.0/5.6/5.7 + Step 5 commit shape). Workflow note: this session surfaced the out-of-band-branch-switch failure mode (filed as `kit/TODOS.md § /ak-merge-devshop is not worktree-aware` and merged separately on `598bf48`).

### pr-body-img-merge-sha-survival (2026-05-11)

- **Branch**: `feat/pr-body-img-merge-sha-survival` (merging via #34)
- **PR**: [#34](https://github.com/meirmsn/abra-kadabra/pull/34)
- **Spec**: `specs/pr-body-img-merge-sha-survival/spec.md`
- **Summary**: Two-track fix for the broken-image-on-closed-PR bug. **Track A** — new `## Step 2.5: Rewrite PR-body image URLs to merge SHA` in `/ak-go-live` between `/land-and-deploy` (Step 2) and branch cleanup (Step 2b). Rewrites `/raw/${headRefName}/` URL slices in the PR body to `/raw/${mergeCommit.oid}/` so embedded hero / qa-walk / design evidence survives `--delete-branch`. Branch-name regex-escaped (slashes-in-branch handled). Skip-with-warning on null `mergeCommit.oid`; silent no-op on zero matches. Bumps `/ak-go-live` `version: 1.3.0 → 1.4.0`. **Track B** — new one-shot `kit/scripts/backfill-pr-image-urls.sh` for retroactive cleanup of historic closed PRs. `--dry-run` default; `--accept-history-rewrite` required for live mutation. Per-run JSONL audit log. Both call sites share one source of truth via extracted helper at `kit/scripts/lib/rewrite-pr-body-urls.sh`. Two post-Phase-3 polish iterations from the lalista backfill: (1) flipped the post-merge-edit conservatism to opt-in via `--skip-edited` (default-on caused PRs #60 / #61 to be mis-suppressed because `/ak-build` Phase 5.3 routinely edits PR bodies post-merge to mark CI checkboxes — those auto-edits trip the 5min heuristic without ever touching image URLs); (2) extended the script to ALSO rewrite issue comments authored by the gh-cli authenticated user, with `--bodies-only` opt-out (Phase 6 audit-trail comments routinely embed hero shots in `### Evidence` that go stale on `--delete-branch` exactly the same way as the body's; comments by other users are skipped via `not-our-comment` audit reason — gh API only allows self-edits). Audit log JSONL gains a `target` field discriminating `body` vs `comment:<id>`. Cumulative lalista backfill: 9 PR bodies + 8 PR comments = 17 surfaces, 73 URLs total. Idempotent re-run confirms no stale URLs remain. Closes `kit/ROADMAP.md § PR-body image URLs survive branch deletion` (deleted entirely — both tracks shipped).
- **Commits**: 11 atomic commits on the feature branch (will collapse to 1 squash on `main` per `/ak-merge-devshop`); per-commit SHAs preserved as compressed bullets in the squash message body, recoverable via `git reflog` for ~90 days. Final pre-merge SHA: `a3a77cd` (BUILD-LOG fix at `<this commit>` follows for Audit 2 cleanliness).
- **Quality gates**: all passed — 6 pass + 0 findings_pending + 9 n/a + 0 blocked. Audit 1 clean at `da0c21d`. Audit 2 (post-polish, this audit) — 1 medium finding (this entry's pre-polish staleness, fixed in same range). 785/785 BATS green (745 existing + 40 new tests across SKILL.md content + helper behavior + backfill body-and-comments behavior).

### context-aware-guideline-routing (2026-05-11)

- **Branch**: `feature/context-aware-guideline-routing` (merging via #33)
- **PR**: [#33](https://github.com/meirmsn/abra-kadabra/pull/33)
- **Spec**: `specs/context-aware-guideline-routing/spec.md`
- **Summary**: Promotes `kit/docs/guide/README.md` from flat ToC to a Hybrid routing index — logical groups (Data / Auth + security / Frontend + UI / Ops + deploy / Dev + meta) in the index, flat filesystem on disk. Splits `conventions.md` (943→750 lines) into 3 new topic guides (`migrations.md`, `database-queries.md`, `wrapper-boundaries.md`) per audit-gated D3 proportionality; left-behind pointers preserve external links. Per-file ToCs added to every guide (Layer 2). Layer 3 sub-ToCs adaptively on `conventions.md § Slow-Job Lifecycle` + `§ Non-Negotiables` (the two long-section + independently-routable cases the audit surfaced). Patches `/ak-spec` (new Step 1.5: spec-time routing-index consultation) + `/ak-implement` (Step 1 swaps to routing lookup with `conventions.md` fallback for pre-adoption projects). 3 new BATS invariants (link-resolution, completeness, real-world-grounding-against-lalista-specs; cross-boundary skip-with-reason). 12 routing rows shipped on the audit's proposed initial set + 10 expansion. Closes `kit/ROADMAP.md § Context-aware guideline routing for /ak-spec and /ak-implement`; files PR-B follow-on entry for lalista CLAUDE.md gotcha audit + lift into the new routing system.
- **Commits**: 18 atomic commits (Phase 0 spec skeleton + Phase 1 spec expand + 2 user-gate steps + 3 split commits + 9 implementation commits + Phase 2 tasks.md ledger + Phase 3 pre-ship review.md). Final SHA: `90d6baa`.
- **Quality gates**: all passed — 5 pass + 0 findings_pending + 10 n/a + 0 blocked. Audit 1 clean at HEAD. 745 BATS green (732 existing + 13 new routing tests).

### ak-go-live-arm-a-preflight (2026-05-10)

- **Branch**: `feat/ak-go-live-arm-a-preflight`
- **PR**: TBD
- **Spec**: `specs/ak-go-live-arm-a-preflight/spec.md`
- **Summary**: Adds `/ak-go-live` Step 1.8 — pending-tasks pre-flight surface. Reads the merging PR's body + latest `## Pre-ship audit trail` and `## Ready for review` comments via `gh pr view`, parses every `[ ]` checkbox grouped by section, annotates each `[manual]` (operator-action needed) / `[deferred]` (PR-review concern, post-merge) / `[!]` (CI checkbox `/ak-build` Phase 5.3's auto-marker should have flipped — bookkeeping skipped), and prints a "Pending tasks before live" view. Blocks the merge via `AskUserQuestion` only when `## Out-of-band deploy items` has unchecked items (deploy prereqs by definition); other surfaces are non-blocking reminders. Closes Arm A of `kit/ROADMAP.md § /ak-go-live post-merge prod-config sync` — the entry now narrows to "(Arm B — automation core)" and remains scoped (Management API integration + `SUPABASE_ACCESS_TOKEN` credential surface, deferred).
- **Commits**: 3 atomic commits (Phase 0 spec skeleton + Arm A bundle + pre-ship review.md + this bookkeeping commit)
- **Quality gates**: all passed — 4 pass + 0 findings_pending + 10 n/a + 0 blocked.

### qa-na-tightening (2026-05-10)

- **Branch**: `feature/qa-na-tightening`
- **PR**: TBD
- **Spec**: `specs/qa-na-tightening/spec.md`
- **Summary**: Tightens the residual self-attestation rung in Gate 9. When a spec declares `## Core user story: N/A — <reason>`, the rationale is now routed through `adversarial-review.sh` via a new `coreUserStoryNaReason` check-type (Sonnet 4.6, inlines `kit/docs/guide/workflow.md § Core user story requirement` + Rule #11 with verbatim ACCEPT/REJECT vocabulary from `kit/ROADMAP.md` lines 1973-1974). `kit/scripts/preship/verify-story.sh`'s `is_na_core_story` branch invokes the new check before emitting "skipped" — interpretive prose ("no visible UI change", "cosmetic only") fails; verifiable file/path claims ("diff is `supabase/migrations/**` only", "no `.tsx` files modified") pass. Closes the gap that previously let Gate 9's artifact-assertion bypass through on operator prose alone.
- **Commits**: 6 atomic commits (Phase 0 spec skeleton + Phase 1 spec expand + 3 implementation commits + pre-ship review.md + this bookkeeping commit)
- **Quality gates**: all passed — 6 pass + 0 findings_pending + 10 n/a + 0 blocked. Eat-your-own-dogfood live signal: this spec's own `## Core user story: N/A — devshop pipeline tightening; touches kit/scripts/adversarial-review.sh, kit/scripts/preship/verify-story.sh, kit/tests/, kit/docs/guide/hooks.md, .claude/skills/devshop/pre-ship/SKILL.md only; no apps/** or packages/** files in diff.` PASSed adversarial review (AC #6).

### slow-job-skip-on-docs-only (2026-05-08)

- **Branch**: `feature/slow-job-skip-on-docs-only` (merging via #29)
- **PR**: [#29](https://github.com/meirmsn/abra-kadabra/pull/29)
- **Spec**: `specs/slow-job-skip-on-docs-only/spec.md`
- **Summary**: Adds a commented `changes:` setup-job + per-job `if:` gate to `template/.github/workflows/ci.yml`'s slow-job stub so docs-only diffs (`**/*.md`, `specs/**`, `PLAN.md`, `BUILD-LOG.md`, `TODOS.md`, `.gstack/**`, `.devshop/**`) skip the 8–10 min slow-job cycle once a project uncomments. ROADMAP's proposed `slow: paths-ignore:` is invalid at job level (verified empirically — actionlint v1.7.7 rejects it); the chosen shape uses an inline-bash classify step + `case`-glob match (no third-party action) and keeps the single-workflow-file structure. `slow-job-lifecycle-check.sh` extended with Check 6 to assert the filter is wired once the slow-job is uncommented; pass-fixtures updated so they don't regress under Check 6.
- **Commits**: 7 atomic commits (Phase 0 spec skeleton + Tasks 1–5 + pre-ship review.md + this bookkeeping commit)
- **Quality gates**: all passed — 8 pass + 0 findings_pending + 6 n/a + 0 blocked. Audit 1 clean.

### postgrest-null-and-tier-a2-retry-docs (2026-05-08)

- **Branch**: `feat/postgrest-null-and-tier-a2-retry-docs`
- **PR**: TBD
- **Spec**: prose-only, drafted from `kit/TODOS.md` entries (now deleted per closure protocol)
- **Summary**: Two prose-only conventions surfaced by lalista PR #49. (1) `kit/docs/guide/conventions.md § Database queries` + `template/CLAUDE.md` gotcha — PostgREST returns `data: null` + populated `error` on a non-existent column; downstream null-deref masks the typo. Convention requires `error`-first checks at every `.select()` call site (lalista PR #49 hit this twice: `items.name` typo + `purchase_history.list_entry_id` unmapped FK). (2) New `kit/docs/guide/testing.md` (Pattern 1) — Tier A2 retry-budget E2E tests use `page.clock.fastForward()` (Playwright 1.45+) instead of bumping `test.setTimeout()` past the backoff window; cites lalista's `add-item-banner.spec.ts` as the don't-do-this prior art. Closure deletes the two `[v0]` TODOS entries (no strikethrough, no shipped footnote) per the post-cleanup convention.
- **Commits**: 2 atomic commits (uncommitted-TODOs annotation + the two-doc ship + closure)
- **Quality gates**: `/ak-pre-ship` (prose-only docs, no test gates apply)

### cheap-test-gates-local (2026-05-06)

- **Branch**: `feature/cheap-test-gates-local` (merging via #27)
- **PR**: [#27](https://github.com/meirmsn/abra-kadabra/pull/27)
- **Spec**: `specs/cheap-test-gates-local/spec.md`
- **Summary**: Shift cheap test gates from CI-only to local pre-push. New devshop gate `changed-tests-local (ak)` at #2d (parse-check + changed-spec execution + convention-based smoke set). Sub-fix 3 promotes degraded local Supabase to `blocked` on stack-needing diffs. New `localTestSkipReason` adversarial-review check-type.
- **Commits**: 10 atomic commits (Phase 0 skeleton, Phase 1 spec, 4 implementation commits, 3 pre-ship fix commits, 1 doc-sync commit from /document-release)
- **Quality gates**: all passed — 3 pass + 3 findings_fixed + 9 n/a + 0 pending + 0 blocked. Audit 1 (pre-polish) clean.

<!--
  Historical backfill (2026-05-11): the 12 entries below were written
  retroactively to cover the v1.22.0 → v1.25.0 window. Pre-v1.25.0 ships
  did not go through `/ak-build` Phase 5.6 (the convention that authors
  BUILD-LOG entries on the feature branch), so these entries are
  reconstructed from commit messages + PR diffs and use a minimal shape
  (PR, Summary, Commits, Note) — `Spec` and `Quality gates` rows are
  omitted because there is no `specs/<feature>/review.md` to cite. Forward-
  going discipline is healthy; this is a one-shot history-fix.
-->

### ak-check-docs-and-tests + ak-build phase 5.8/5.9 (2026-05-06)

- **PR**: no GitHub PR — squash-merged to main locally via `/ak-merge-devshop` over four feature branches (PR-A, PR-B, PR-C, post-polish), bundling `/ak-build` Phase 5.8/5.9 wiring with the underlying audit-time skill split.
- **Summary**: Moves adversarial Layer 2 docs/tests coverage review from per-commit hooks to **audit moments** (`/ak-pre-ship` Gate 5 + `/ak-build` Phase 5.8). New orchestrator `/ak-check-docs-and-tests` computes commit range from the latest `## Audit N` section's `<!-- audited-at: <SHA> -->` in `specs/<feature>/review.md`, invokes `/ak-docs-review` + `/ak-tests-review` in sequence, appends a new `## Audit N` section with structured findings — idempotent on unchanged HEAD. `/ak-tests-review` renamed from `/ak-test-review`; gains Section A (coverage of new behavior) and Section C (bypass trailer audit) on top of the 11 existing quality sub-sections. `/ak-docs-review` is brand-new — coverage + adequacy + cross-doc coherence + bypass-trailer audit, repo-aware (devshop self-mode vs project mode). Layer 1 surface symmetry rename: `check-test-coverage-project.sh → check-tests-coverage-project.sh`, `check-test-coverage.sh → check-tests-coverage-devshop.sh`, `check-docs-freshness-project.sh → check-docs-coverage-project.sh`; new `check-docs-coverage-devshop.sh`. Per-commit Layer 2 reviews (`docsReviewed`, `testCoverage`, `testCoverageProject`, `docsFreshnessProject`) are removed from the loop; coverage judgment lives exclusively in the audit-time orchestrator. New `prepare-commit-msg` hook emits `Docs-Coverage-Bypass:` / `Tests-Coverage-Bypass:` Git trailers when `git -c devshop.{docs,tests}CoverageReason="<why>"` accepts a bypass — trailers travel with the commit (rebase/push/clone-stable) and audit-time reviews harvest them as `[bypass-revisit]` findings. `/ak-build` SKILL.md bumped 1.5.0 → 1.7.0 (Phase 5.8 + 5.9 + resume rungs 1a/1b + Phase 6 audit-comment shape). `/ak-pre-ship` Gate 5 emits `<!-- audited-at: <SHA> -->` as the first line of `review.md` — the contract 5.8.2 reads to derive the audit range.
- **Commits**: `afad4fe` (5.8/5.9 wiring) + `b02d531` (PR-A audit-time skills) + `a0f1705` (PR-B Phase 5.8 wiring + two-file collapse) + `a2e1f34` (PR-C per-commit Layer 2 removal + bypass trailers) + `37c1074` (post-pr-c deferred-low fixes) + `7f18084` (Audit 1 record). Recorded under `specs/ak-check-docs-and-tests/`.
- **Note:** Historical backfill — pre-dates the convention that authors BUILD-LOG entries during `/ak-build` Phase 5.6.

### adversarial-review doc inlining + addition-drift sweep (2026-05-01)

- **PR**: no GitHub PR — squash-merged locally via `/ak-merge-devshop`.
- **Summary**: `adversarial-review.sh` gains a `GUIDES_TO_INCLUDE` map parallel to `CONVENTIONS_TO_INCLUDE` — when a staged diff touches a code area whose reference doc is a guide, the chapter body inlines with the headers (not just `## ` TOC entries). Routes: `kit/scripts/commit-hooks/`, `kit/hooks/`, `kit/scripts/preship/`, `template/.husky/`, `.claude/settings.json` → `hooks.md` FULL; `template/`, `kit/manifest.txt`, `init-devshop.sh`, `kit/scripts/sync/` → file-lifecycle sections of the right guide. Closes the structural blind spot where the reviewer could see "section called Husky pre-commit" but not the bypass table inside, so a missing row went unnoticed. Two drift cases backfilled the same turn: `check-test-coverage-project.sh`, `check-docs-freshness-project.sh`, and `check-security-files-freshness.sh` all shipped without rows in `hooks.md § 2`'s bypass table — added.
- **Commits**: `953e9a1`.
- **Note:** Historical backfill.

### docsReviewed unification across both repos (2026-05-01)

- **PR**: no GitHub PR — squash-merged locally via `/ak-merge-devshop`.
- **Summary**: Drops the parallel `docsFreshnessProject` check-type. One `docsReviewed` reviewer now serves both surfaces, branching internally on `REPO_MODE` (devshop = real `kit/` dir, project = otherwise). Same prompt rules apply to both; only the inlined doc catalog differs. Devshop branch reads `CLAUDE.md`/`OVERVIEW.md`/`README.md` FULL + `guide/*` + `FAQ.md` headers; project branch reads `CLAUDE.md`/`METRICS.md`/`OVERVIEW.md`/`ARCHITECTURE.md`/per-package READMEs FULL. Bypass-key rename `devshop.docsFreshnessReviewed → devshop.docsReviewed` propagates through `check-docs-freshness-project.sh`, `hooks.md § 2` bypass table, recipes, and conventions docs. Head-N truncations dropped (`CLAUDE.md` head-100, etc. → all FULL) — `§ Gotchas` (load-bearing, lives past line 100) is now visible to the reviewer. `MODEL.md` inline dropped (file folded into `OVERVIEW.md` upstream).
- **Commits**: `9b18f46` + `889c883`.
- **Note:** Historical backfill.

### project docs deeper hierarchy — OVERVIEW + ARCHITECTURE + per-package READMEs (#25, 2026-05-01)

- **Branch**: `feat/project-docs-deeper-hierarchy` (merged via #25)
- **PR**: [#25](https://github.com/meirmsn/abra-kadabra/pull/25)
- **Summary**: Adds Tier 2 (`OVERVIEW.md` product overview + `ARCHITECTURE.md` system overview, both opt-in via file existence) and Tier 3 (per-package READMEs at `apps/<x>/`, `packages/<x>/`, `supabase/functions/`, opt-in per package). Builds on the prior "Hierarchical docs scaffold in template" work. Trigger map extended in `check-docs-freshness-project.sh`; reviewer context inlines `OVERVIEW.md` head 150, `ARCHITECTURE.md` head 150, every per-package README at HEAD up to 80 lines. Templates added with `[scaffold-once]` manifest tracking. Robustness fixes to `adversarial-review.sh`: `COMMIT_TIMEOUT` 90 → 180s (PR #25's inlined guide-doc bodies made sonnet calls hit the prior limit on docsReviewed); backtick escape fix.
- **Commits**: `5c937a9`. 13 new BATS cases; full kit suite 495/495 pass.
- **Note:** Historical backfill.

### DEPS-WATCH.md session-start banner (#24, 2026-04-30)

- **Branch**: `feat/deps-watch` (merged via #24)
- **PR**: [#24](https://github.com/meirmsn/abra-kadabra/pull/24)
- **Summary**: `session-start.sh` now reads `$ROOT/DEPS-WATCH.md` (markdown table) and surfaces any row whose `recheck-on` date is past as a 🚨 banner in the user-visible session briefing. Silent if file is absent or no rows overdue. Adds `template/DEPS-WATCH.md` (empty stub) registered in `kit/manifest.txt` as `[scaffold-once]` so `/ak-new-project` delivers the file but bidirectional sync skips it (project owns its rows after creation). Use case: dependabot major-version PRs that can't merge until upstream ecosystem catches up (e.g. `eslint 10` needs `eslint-config-next` bump first) — operator runs `@dependabot ignore this major version` + adds a row to `DEPS-WATCH.md`; banner re-prompts on the chosen date. `guide/hooks.md` updated to list DEPS-WATCH alerts among session-start briefing components.
- **Commits**: `f38f3b7`.
- **Note:** Historical backfill.

### pre-push wrapper+symlink refactor (#22, 2026-04-30)

- **Branch**: `refactor/pre-push-wrapper-symlink` (merged via #22)
- **PR**: [#22](https://github.com/meirmsn/abra-kadabra/pull/22)
- **Summary**: Mirrors the existing `.hooks/pre-commit` wrapper+symlink pattern for `pre-push`. Single policy source at `kit/hooks/pre-push.sh`; `.husky/pre-push` wrappers (template + devshop) become ~10-line husky-shim bridges that exec the `.hooks/pre-push` symlink. Repo mode (project vs devshop) detected at runtime by probing whether `kit/` is a real directory at the repo root — same probe `kit/hooks/pre-commit.sh` uses. Closes the template-propagation wart: every prior devshop-side `template/.husky/pre-push` edit cost a per-project follow-up (PR G's content propagated into lalista as an unstaged change after container rebuild — second occurrence of the per-project alignment-PR pattern). Behavior is byte-for-byte unchanged: same checks, same bypass flags (`devshop.prDescStaleReason`, `devshop.dirtyPushReason`), same short-circuits, same hard-block-on-main-push.
- **Commits**: `b7de9df`. 18 pre-push bats cases pass (5 new).
- **Note:** Historical backfill.

### adversarial review of project exempt-file additions (#20, 2026-04-30)

- **Branch**: `feat/exempt-file-adversarial-review` (merged via #20)
- **PR**: [#20](https://github.com/meirmsn/abra-kadabra/pull/20)
- **Summary**: `check-exempt-additions.sh` runs in the project pre-commit chain BEFORE `check-test-coverage-project.sh` + `check-docs-freshness-project.sh`. Reviews additions to the two coverage-gate exempt files (`.devshop-test-coverage-exempt`, `.devshop-docs-freshness-exempt`): pre-flight (deterministic hard block — no adversarial bypass) parses each added line as `path  # reason` and rejects path-like tokens in the reason field (`*.ts`, `*.tsx`, `*.spec.ts`, `*.test.ts`); vague-reason scoring then routes the addition through adversarial review. Closes the gap identified in the original hook audit and deferred from PR #10's scope: operators (and Claude) can no longer silently exempt a path by citing covering specs/tests that don't actually exist.
- **Commits**: `c750698`.
- **Note:** Historical backfill.

### manifest-driven file lifecycle — annotation + init-devshop + sync (#12 + #14 + #15, 2026-04-30)

- **Branches**: `feat/manifest-lifecycle-foundation` (#12), `feat/manifest-driven-init-devshop` (#14), `feat/manifest-driven-sync-scripts` (#15)
- **PRs**: [#12](https://github.com/meirmsn/abra-kadabra/pull/12) + [#14](https://github.com/meirmsn/abra-kadabra/pull/14) + [#15](https://github.com/meirmsn/abra-kadabra/pull/15)
- **Summary**: Three-PR series that consolidates file-lifecycle classification into `kit/manifest.txt` as the single source of truth. (1) #12 — annotates each declared workspace path with an inline `[tag]` (`[sync]`, `[locked]`, `[locked-dir]`, `[symlink]`, `[scaffold-once]`) + ships shared parser at `kit/scripts/sync/lib/parse-manifest.sh`. Foundation only, no behavior change. (2) #14 — replaces `init-devshop.sh`'s hardcoded LOCKED file loop with a manifest-driven loop; `install -D -m 644 -o root -g root <template-source> <workspace-dest>` atomically refreshes content + chowns + chmods per `[locked]` entry. This is the line of code that actually fixes the `.husky/pre-push` propagation bug PR #8 surfaced (PR #8 added `template/.husky/pre-push` but no existing project picked it up — init-devshop's hardcoded list didn't include it). (3) #15 — `sync/from-devshop.sh` pulls only `[sync]` entries (skips `[locked]`, `[symlink]`, `[scaffold-once]`); `sync/to-devshop.sh` pushes only `[sync]` entries; `commit-hooks/check-security-files-freshness.sh` now verifies every manifest `[locked]` file against its template source (was: just `settings.json` + `.dcg.toml`) — catches Layer-2 erosion of any workspace-side locked file.
- **Commits**: `283590d` (#12) + `6c4f4b3` (#14) + `0cb378b` (#15).
- **Note:** Historical backfill. The three PRs ship sequentially but represent one logical consolidation effort — combined into a single entry per the grouping rule (one coherent feature = one BUILD-LOG entry).

### macOS host setup guide + /ak-new-project Step 0 gate (#13, 2026-04-30)

- **Branch**: `feat/new-project-macos-host-setup` (merged via #13)
- **PR**: [#13](https://github.com/meirmsn/abra-kadabra/pull/13)
- **Summary**: Lifts the four host-side prereqs that the Option 3 compose-isolation threat model assumes (Docker Desktop File Sharing restriction, Docker Engine JSON hardening, `/etc/hosts` loopback, Docker Desktop hygiene) out of per-project launch checklists into a canonical, per-Mac, one-time guide. (1) New `kit/docs/guide/macos-host-setup.md` — apply once before your first devshop project on a machine; every subsequent project inherits. (2) New Step 0 in `/ak-new-project` — single `AskUserQuestion` gate. "Yes" skips with optional `docker-info` sanity check; "no" reads the guide and walks through one numbered step at a time. Skill stays slim — guide loaded on demand only. (3) Step 2b's option-(b) end-of-Phase-B handoff: Step 4 creates `apps/web/.env.local` with `NEXT_PUBLIC_SUPABASE_URL` + anon JWT pulled from `pnpm db:status` — folds the old per-project item into normal scaffolding. Cross-link from `local-supabase-compose-isolation.md § Host-side prereqs` to the new guide.
- **Commits**: `a171b81`.
- **Note:** Historical backfill.

### /ak-handoff command + template gitignore (2026-04-29)

- **Branch**: (direct push to main, no GitHub PR)
- **Summary**: New project-scoped slash command `/ak-handoff` that writes a handoff doc to `.handoff/<name>.md` so a fresh-context Claude session can pick up where the current one left off. Detects the active session's slug, AI title, and permission mode by reading the JSONL transcript; auto-picks a handoff name (arg → existing `/rename` title → slugified AI title → fallback slug); emits a single copy-paste `claude -n <name>__continuation_<n>` bootstrap command for the next session plus a `/rename <name>` line for the current one. Gracefully reports — does not attempt to programmatically rename or enter plan mode. Template gitignore picks up `.handoff/` so future projects bootstrapped via `/ak-new-project` keep these transient docs out of git by default. Docs updated: `kit/docs/guide/workflow.md` standalone-skills list + skills table.
- **Commits**: `a799f91`.
- **Note:** Historical backfill.

### docsReviewed reviewer detects rename/move/delete drift (#11, 2026-04-29)

- **Branch**: `feat/docs-reviewed-rename-drift-prompt` (merged via #11)
- **PR**: [#11](https://github.com/meirmsn/abra-kadabra/pull/11)
- **Summary**: Replaces the closed PR #9 (deterministic `kit/scripts`-only linter) with an extension to the existing `docsReviewed` adversarial reviewer prompt. Same drift class — script renames, doc-section heading renames, CI job renames, skill renames, gate renames, roadmap renames — all surface the same way: an old name lingers in active docs after a rename or deletion. `adversarial-review.sh`'s context-gathering for `docsReviewed` adds a "Renamed/moved/deleted in this commit" section, populated via `git diff --cached --name-status --diff-filter=DR -M`. When empty, the section reads `(none — no files renamed, moved, or deleted in this commit)` so the reviewer knows the rule is trivially satisfied. Better trade-off than maintaining a per-class deterministic linter — one prompt rule covers the entire drift class.
- **Commits**: `3d3dfa2`.
- **Note:** Historical backfill.

### project-repo gates triplet — test-presence + docs-freshness + scaffold (2026-04-28)

- **Branch**: (direct push to main, no GitHub PR — pre-dates the project pre-push convention from PR #8)
- **Summary**: Three coupled additions that ship together so one project-side adoption flushes false-positive exempt lists for all three at once. (1) `kit/scripts/commit-hooks/check-test-coverage-project.sh` — Layer-1 deterministic test-presence hook for project repos. New file under `apps/*/{src,app,components,lib,hooks}/` or `packages/*/src/` without paired `.test.ts` → BLOCK. Source delete with paired test still present → BLOCK as orphan. Modify without staged test → WARN only. Per-project override at `.devshop-test-coverage-exempt`. (2) `kit/scripts/commit-hooks/check-docs-freshness-project.sh` — Layer-1 docs-freshness hook. New `apps/*/app/**/page.tsx`/`layout.tsx`/`route.ts`/`middleware.ts` and `packages/*/src/api/*.ts` → `CLAUDE.md` must be staged. New `posthog.capture(...)` / `Sentry.captureException(...)` call sites → `METRICS.md` staged. Source delete while doc still references the path → BLOCK on stale ref. Per-project override `.devshop-docs-freshness-exempt`. (3) `template/CLAUDE.md`, `template/TODOS.md`, `template/METRICS.md` — scaffold-once orientation skeletons completing the six-file hierarchy delivered by `/ak-new-project`.
- **Commits**: `e4e6abf`.
- **Note:** Historical backfill — pre-dates `/ak-build` Phase 5.6 and the project pre-push convention. The test-coverage script was later renamed to `check-tests-coverage-project.sh` (Layer 1 symmetry, see the `ak-check-docs-and-tests` entry above); the docs-freshness script was renamed to `check-docs-coverage-project.sh`.
