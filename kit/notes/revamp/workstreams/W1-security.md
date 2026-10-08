# W1 — Security hardening _(provisional — re-plan after D-14)_

Per D-04, the real boundary is GitHub + credentials (W0.5–W0.7). This workstream
covers **in-VM hygiene** and **live root-escalation paths in local containers**.

**Live-risk filter (REVIEW-1):** a task marked ⚠ is done only if (a) it's exploitable
before its replacement lands, and (b) local containers keep being used (D-02).
Otherwise mark `[-] obsolete by <task>`.

**Verification:** security tasks need a scenario (V3). Scenarios are of two kinds
(W3.3.3): **in-VM** (must be blocked by hooks/scripts) and **outside-VM** (things the
VM can't prevent — `-n`, `--no-verify`, direct pushes — must be rejected by GitHub on
the fixture repo). Every W1 PR also gets a `/security-review` pass.
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]` — see [PROCESS.md](../PROCESS.md).

## W1.1 Git hooks: in-VM hygiene — P0 · M1 · M

Findings: F-HOOK-01..03, F-HOOK-05, F-HOOK-06, F-HOOK-10, F-SEC-05, F-SEC-06, F-REV-05, F-NEW-03, F-NEW-04.
Done when: in-VM attack scenarios blocked in devshop and project mode; hooks safe for public contributors.

- [ ] **W1.1.1** `.husky/pre-commit`: re-exec with errexit (`exec bash -e "$0" "$@"`); scenario: failing lint/typecheck/gitleaks aborts commit (F-HOOK-01) — V3
- [ ] **W1.1.2** Template hooks public-safe + guarded: `/devshop`-dependent lines end in a true status; add the `CLAUDECODE` main-branch guard to template pre-commit; scenario: commit with no `/devshop` succeeds; Claude commit on main blocked (F-HOOK-02, F-HOOK-03) — V3
- [ ] **W1.1.3** ⚠ Router can't be silently skipped (fail closed when missing/non-executable in a managed repo); cover `kit/hooks/` (F-SEC-06) — obsolete if D-14 B replaces the router with CI
- [ ] **W1.1.4** ⚠ Ignore `DEVSHOP`, `DEVSHOP_FORCE_MODE`, test-only vars outside bats; mode detection not fooled by a `kit/` dir (F-SEC-05, F-HOOK-10, F-NEW-04). `check-hook-bypass.sh` stays a best-effort hint: F-HOOK-04 is **won't fix in-VM — mitigated by W0.6** — V3
- [ ] **W1.1.5** ⚠ Pre-push: check every pushed ref incl. `HEAD:main`; remove the agent-supplied `pushToMainApproved` "proof" and the nonexistent `check-not-force-push.sh` reference; install devshop pre-push in devshop-only containers (F-REV-05, F-NEW-03). Real fix for F-SEC-07 is W0.6 — V3
- [ ] **W1.1.6** Hook output + fail-closed: block messages to stderr (or JSON `permissionDecision: deny`); explicit `timeout` on every hook; PreToolUse guards fail closed without `jq`; CI check that every hook path resolves and `dcg` is installed (F-HOOK-05, F-HOOK-06) — V3

## W1.2 Reviewer: fail-closed + locked-down _(or delete under D-14 B)_ — P0 · M1 · M

Findings: F-REV-01..04, F-REV-07, F-SEC-09, F-NEW-10. Opportunity: O-01 (corrected).
Done when: reviewer passes only on an explicit structured PASS, runs with no tools and
no repo config, and the agent can't make it pass by configuration.

- [ ] **W1.2.1** Verdict: `--json-schema` + `--output-format json`; PASS only if `is_error == false` **and** `structured_output.verdict == "PASS"`; never trust `subtype` or `result` text; scenarios: empty output, `**FAIL**`, garbage, auth error (`is_error:true` with `subtype:"success"`) → all FAIL (F-REV-01) — V3
- [ ] **W1.2.2** Invocation (tested by REVIEW-1 R4; `--bare` can't use a subscription login): `claude -p --setting-sources "" --strict-mcp-config --tools "" --system-prompt <reviewer> --no-session-persistence --model <alias> --json-schema <schema> --output-format json`, run from an empty temp dir; judged text passed as delimited data; canonical reviewer copy only (F-REV-02, F-REV-07) — V3
- [ ] **W1.2.3** ⚠ `devshop.humanReviewed` / `DEVSHOP_SKIP_ADVERSARIAL` refused when `CLAUDECODE=1`, incl. persistent `git config` (F-REV-03) — V3
- [ ] **W1.2.4** ⚠ Wiring: remove or define `fastJobSkipReason`; callers run the reviewer via `bash <path>`; "reviewer unavailable" = **fail** (F-REV-04, F-SEC-09) — V3

## W1.3 Container root-escalation + secrets out of env — P0 · M1 · L (while local is used, D-02)

Findings: F-SEC-01..03, F-SEC-10..16, F-NEW-02, F-NEW-06.
Done when: no node→root path via devshop scripts (scenarios for each listed path); no secrets in the agent's process env.

- [ ] **W1.3.1** `init-devshop.sh`: validate manifest paths (no `..`, no absolute, resolve under `$WS`), refuse symlinked destinations; don't run workspace scripts as root; validate numeric ports in `derive-ports-from-config.sh` (F-SEC-01, F-SEC-14) — V3 local `[owner machine]`
- [ ] **W1.3.2** Secrets out of the agent env: no `env_file: .env` for the workspace service; separate (or no) node sudo password; `.env` and `/etc/devshop-env` mode 600 root (F-SEC-02, F-SEC-03, F-SEC-15) — V3 local
- [ ] **W1.3.3** Root-owned **directories** for locked paths (`kit/scripts`, `kit/hooks`, `notify/`, `[locked-dir]`s) — `chown root` the dir, not just the leaves; lock non-`.sh` executables incl. `notify/claude-cancel` (F-SEC-12, F-SEC-13, F-NEW-02, F-NEW-06) — V3 local
- [ ] **W1.3.4** ⚠ Prevent introduction of `.claude/settings.local.json` / user settings hooks (F-SEC-10) — or via managed settings in W4.4
- [ ] **W1.3.5** ⚠ Firewall: drop blanket TCP/22 + DNS-anywhere (F-SEC-11) — only if D-02 keeps local first-class
- [ ] **W1.3.7** Record (with D-02) the fate of devshop-self locking (F-SEC-16) and the sticky-bit model — decision entry, no code
- [-] **W1.3.6** merged into W1.3.1 (REVIEW-1 R3 M8)

## W1.4 Permission rules correct; security docs truthful — P0 · M1 · S

Findings: F-SEC-04, F-SEC-19, F-DOC-04, F-NEW-01.

- [ ] **W1.4.1** Rewrite absolute-path rules with `//`; bats check against single-`/` absolute paths; narrow the allow-list (`npx *`, `pnpm *`, `find *`, `git push*`, `chmod *` grant unprompted arbitrary execution — F-NEW-01) (F-SEC-04) — V3 in a Claude session
- [ ] **W1.4.2** Rewrite `kit/docs/guide/security.md` + `kit/notes/security/*` to state what is enforced, by what, and known limits (per D-04) (F-DOC-04) — V1

## W1.5 Template: GitHub-side controls, CI secret hygiene, pins — P0 · M1 · M

Findings: F-SEC-08, F-SEC-18, F-INFRA-05, F-NEW-12. (Real repos: W0.6.)
Done when: a project created from the template gets the W0.6 protections by default.

- [ ] **W1.5.1** `/ak-new-project`: no-bypass ruleset (PR + required checks + no force-push), auto-merge off; CODEOWNERS/required review only with D-13 A (F-SEC-08) — V3 on a test repo
- [ ] **W1.5.2** Template workflows: `permissions: contents: read` default; no repo-level secrets on `pull_request`; deploys in `environment: production` (main only, required reviewer, prevent self-review), after CI on main (F-SEC-08, F-NEW-12) — V3 on a test repo
- [ ] **W1.5.3** Pin versions: Claude Code, pnpm, Node (one version), Supabase CLI, Actions by SHA, gitleaks with checksum (F-SEC-18, F-INFRA-05) — V2 shape test
- [-] **W1.5.4** moved to W0.7 (F-SEC-20 reproduced; critical)
