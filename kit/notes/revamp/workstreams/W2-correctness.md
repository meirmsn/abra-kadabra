# W2 — Correctness fixes

Small, independent bug fixes in today's system. Pick opportunistically; each
needs a regression test (V2) unless noted. Some may become obsolete by later
rework — if so, mark `[-] obsolete by <task>` instead of fixing.
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]`.

## W2.1 Pipeline / skill bugs — P1 · M1 · M

- [ ] **W2.1.1** Replace range-awk Headline/Detail extraction with one shared, tested extractor script used by build 4.0/4.1/5.3.5/6, go-live Step 6, build:2869 (F-PIPE-01)
- [ ] **W2.1.2** go-live: capture PR number/branch before checkout of main; use it in Steps 3/6 (F-PIPE-02) — V1 (skill text) + scenario when W3.3 exists
- [ ] **W2.1.3** build 3.0 preflight: environment-health `blocked` must survive (F-PIPE-03)
- [ ] **W2.1.4** build 0.2.6 Headline lint: no accumulation inside piped `while` (F-PIPE-04) — move into the extractor script from W2.1.1
- [ ] **W2.1.5** `check-llm-mediated-na.sh`: accept canonical bare gate names (F-PIPE-05)
- [ ] **W2.1.6** Symlink (or merge into callers) `devshop/preflight` and `devshop/design-conformance` so they're invocable; bats wiring test (F-PIPE-10)
- [ ] **W2.1.7** `/ak-record-friction-log`: resolve devshop root, not session repo (interim fix; W4.5 moves friction intake) (F-PIPE-17)

## W2.2 Infra script bugs — P1 · M1 · S

- [ ] **W2.2.1** `session-start.sh`: robust counting (`grep -c … || true`) for init tracker (F-INFRA-01)
- [ ] **W2.2.2** `release.sh`: `${DEVSHOP_GITHUB_TOKEN:-}`; push only the new tag (F-INFRA-02)
- [ ] **W2.2.3** `apply-port-offset.sh`: derive name from git remote like session-start, or fix docs (F-INFRA-03)
- [ ] **W2.2.4** `session-start.sh`: detect devshop-self correctly in its own container (F-INFRA-04)
- [ ] **W2.2.5** Low-priority: `virtiofs-rebase.sh` real-dirty detection; `reconcile-task-commits.sh` counts only impl commits; per-session notify PID file (F-INFRA-06) — fix or `[-] obsolete by W4/W9`
- [ ] **W2.2.6** `propagation-entry.sh`: accept backticked tags; drop `[auto]`; fix contradictory entries (F-VER-05)

## W2.3 Hook correctness — P1 · M1 · S

- [ ] **W2.3.1** `check-clean-tree.sh`: detect partially staged files; coverage/bats checks evaluate the index (`git stash --keep-index` or `git diff --cached` based) (F-HOOK-07) — V3

## W2.4 Template passes its own CI on a fresh project — P1 · M1 · M

Done when: a project freshly created from `template/` passes fast + slow CI jobs
(V4 on the fixture project from W3.3).

- [ ] **W2.4.1** Replace `next lint` with `eslint .` (F-TPL-01)
- [ ] **W2.4.2** E2E: ship only specs for routes that exist (or ship the routes); provide `supabase/config.toml` or generate in CI; add or remove `e2e/helpers/admin-client.ts` reference (F-TPL-02)
- [ ] **W2.4.3** Playwright projects use Chromium device profiles (or install WebKit) (F-TPL-03)
- [ ] **W2.4.4** Sentry client init via `instrumentation-client.ts`; remove replay knobs or add integration; remove PostHog claim or wire it (F-TPL-04)
- [ ] **W2.4.5** `packages/ui`: create minimal package or remove references (F-TPL-05)
