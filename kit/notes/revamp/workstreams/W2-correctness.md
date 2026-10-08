# W2 — Correctness fixes _(filtered: live impact only)_

Small bug fixes in today's system. **Live-impact filter (REVIEW-1):** fix now only
if it hurts a live project before its replacement lands; tasks marked ⚠ name the
task that supersedes them — default to `[-] obsolete by <task>` unless a live project
is hurt. Fixes that matter to live projects are also cherry-picked to `v1` (W0.4).
Each fix needs a regression test (V2) unless noted.
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]`.

## W2.1 Pipeline / skill bugs hurting live projects — P1 · M1 · M

Done when: a product-tier run on a live-like fixture no longer hits these bugs (blurb extracted, preflight block honoured, non-UI PR doesn't halt).

- [ ] **W2.1.1** One shared, tested extractor for Headline/Detail (replaces range-awk at build 4.0/4.1/5.3.5/6, go-live Step 6, build:2869); also fixes the 0.2.6 lint subshell bug (F-PIPE-01, F-PIPE-04)
- [ ] **W2.1.2** go-live: capture PR number/branch before checking out main (F-PIPE-02) — V2 via extracted script
- [ ] **W2.1.3** build 3.0 preflight: environment-health `blocked` must survive (F-PIPE-03)
- [ ] **W2.1.8** **Minimal Rung-2 fix:** n/a-by-scope `blocked` gates (e.g. Gate 8 on non-UI PRs) don't force the override question (F-PIPE-06; full fix W6.4.2)
- [ ] **W2.1.5** ⚠ `check-llm-mediated-na.sh` accepts bare gate names (F-PIPE-05; 4/26 sinks affected) — superseded by W6.4.2
- [ ] **W2.1.6** ⚠ Make `devshop/preflight` and `devshop/design-conformance` invocable (F-PIPE-10) — superseded by W4.2 layout / W6.4.3
- [ ] **W2.1.7** `/ak-record-friction-log` resolves the devshop root, never creates `kit/` in a project (F-PIPE-17, F-NEW-04 — live: flips project hooks into devshop mode) — interim until W4.5.2
- [-] **W2.1.4** merged into W2.1.1

## W2.2 Infra script bugs — P1 · M1 · S

Done when: session start reports init progress correctly and a release run without a token degrades gracefully.

- [ ] **W2.2.1** `session-start.sh`: robust counting for the init tracker (F-INFRA-01)
- [ ] **W2.2.2** `release.sh`: `${DEVSHOP_GITHUB_TOKEN:-}`; push only the new tag (F-INFRA-02) — needed for M1's `v1` patch
- [ ] **W2.2.3** ⚠ `apply-port-offset.sh` name derivation (F-INFRA-03) — superseded by W4.5.1
- [ ] **W2.2.4** ⚠ `session-start.sh` devshop-self detection (F-INFRA-04) — superseded by W4.1.2/W4.2
- [ ] **W2.2.5** ⚠ `virtiofs-rebase.sh`, `reconcile-task-commits.sh`, shared notify PID (F-INFRA-06) — superseded by W9.1/W4.7
- [ ] **W2.2.6** `propagation-entry.sh`: accept backticked tags; drop `[auto]` (F-VER-05)

## W2.3 Hook correctness — P2 · M1 · S

- [ ] **W2.3.1** ⚠ `check-clean-tree.sh` detects partially staged files; checks evaluate the index (F-HOOK-07) — superseded by CI gating under D-14 B

## W2.4 Template passes its own CI on a fresh project — P1 · M1 · L

Done when: a project freshly created from `template/` (via `/ak-new-project` Phase A, which runs `supabase init`) passes fast + slow CI on the fixture.

- [ ] **W2.4.1** Replace `next lint` with `eslint .` (F-TPL-01)
- [ ] **W2.4.2** E2E: ship only specs for routes that exist, or ship the routes; drop the stale `admin-client.ts` comment (F-TPL-02, corrected)
- [ ] **W2.4.3** Playwright projects use Chromium device profiles (or install WebKit) (F-TPL-03)
- [ ] **W2.4.4** Sentry client init via `instrumentation-client.ts`; remove replay knobs or add integration; remove PostHog claim or wire it (F-TPL-04)
- [ ] **W2.4.5** `packages/ui`: create minimal package or remove references (F-TPL-05)
