# W1 — Security hardening

Close verified holes inside today's architecture, cheaply, each with an attack
scenario that proves it's closed. Minimum verification for every task: **V3**
(scripted scenario incl. the attack) unless stated higher.
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]` — see [PROCESS.md](../PROCESS.md).

## W1.1 Git hooks actually block — P0 · M1 · M

Findings: F-HOOK-01..06, F-HOOK-10, F-SEC-05, F-SEC-06, F-SEC-07, F-REV-05.
Done when: the attack suite (W3.3.3) shows every listed bypass blocked, in devshop
and project mode, and hooks are safe for public contributors.

- [ ] **W1.1.1** `.husky/pre-commit`: re-exec with errexit (`exec bash -e "$0" "$@"` or `set -euo pipefail` after re-exec); scenario: failing lint/typecheck/gitleaks aborts commit (F-HOOK-01)
- [ ] **W1.1.2** Template hooks public-safe + guarded: every `/devshop`-dependent line ends in a true status (`if …; then …; fi`); add the `CLAUDECODE` main-branch guard to template pre-commit; scenario: commit in a clone with no `/devshop` succeeds; Claude commit on main blocked (F-HOOK-02, F-HOOK-03)
- [ ] **W1.1.3** Router invocation can't be silently skipped: fail closed when the router is missing/non-executable in a devshop-managed repo (decide marker, e.g. `.devshop/` present); lock/cover `kit/hooks/` like `kit/scripts/` (F-SEC-06)
- [ ] **W1.1.4** Enforce "human-only" switches where they're consumed, not by command-text matching: hooks/scripts ignore `DEVSHOP`, `DEVSHOP_FORCE_MODE`, test-only vars (`IDENTITY_GUARD_REAL_ROOTS`, `DEVSHOP_ADVERSARIAL_MODEL_OVERRIDE`) unless running under bats (explicit test flag), and refuse when `CLAUDECODE=1`; mode detection not fooled by `mkdir kit`; reduce `check-hook-bypass.sh` to a best-effort hint (F-SEC-05, F-HOOK-04, F-HOOK-10)
- [ ] **W1.1.5** Push gates: check every pushed ref (incl. `HEAD:main`, detached HEAD) against main/master; devshop-mode on-main push no longer exits 0 unconditionally (pending D-03 — under PR flow, block direct main pushes outright); remove agent-supplied `pushToMainApproved` "proof" and the nonexistent `check-not-force-push.sh` reference (F-SEC-07, F-REV-05)
- [ ] **W1.1.6** Hook output + fail-closed: block messages to stderr (or JSON `permissionDecision: deny`); PreToolUse guards fail closed when `jq` missing; document that `dcg` missing is fail-open and add a SessionStart/CI check that it's installed (F-HOOK-05, F-HOOK-06) — V2

## W1.2 Reviewer fail-closed, locked-down, not self-approvable — P0 · M1 · M

Findings: F-REV-01..04, F-REV-07, F-SEC-09. Opportunity: O-01.
Done when: reviewer requires an explicit PASS in structured output, runs with no
tools and no repo config, and the agent cannot make it pass by configuration.

- [ ] **W1.2.1** Verdict parsing: require structured `{"verdict":"PASS"|"FAIL","reasons":[…]}` (via `--json-schema`) and treat anything else as FAIL; scenarios: empty output, `**FAIL**`, garbage, CLI error → all FAIL (F-REV-01) — V2
- [ ] **W1.2.2** Invocation: `claude -p --bare --tools "" --max-turns 1 --no-session-persistence --model <alias> --json-schema …`; judged text passed as clearly delimited data; always use the canonical (not worktree) reviewer copy (F-REV-02, F-REV-07) — V3
- [ ] **W1.2.3** `devshop.humanReviewed` / `DEVSHOP_SKIP_ADVERSARIAL` refused when `CLAUDECODE=1` (checked inside `adversarial-review.sh`); scenario: agent sets either → still reviewed (F-REV-03)
- [ ] **W1.2.4** Fix wiring: add or remove `fastJobSkipReason`; `advisor-clean.sh` / `fast-job-local.sh` / `changed-tests-local.sh` invoke the reviewer via `bash <path>` and treat "reviewer unavailable" as **fail**, not pass (F-REV-04, F-SEC-09) — V2

## W1.3 Container privilege & secrets — P0 · M1 · M (scope per D-02)

Findings: F-SEC-01..03, F-SEC-10..12, F-SEC-14..16.
Done when: no path from the node user to root via devshop scripts; no secrets in
the agent's process environment; scenarios demonstrate each.

- [ ] **W1.3.1** `init-devshop.sh`: validate manifest paths (no `..`, no absolute, must resolve under `$WS`), refuse symlinked destinations; stop running workspace scripts as root (`derive-ports-from-config.sh` as node or inline + validated) (F-SEC-01, F-SEC-14)
- [ ] **W1.3.2** Secrets out of the agent env: stop `env_file: .env` for the workspace service (pass only non-secret keys explicitly); separate root password from node's (or no node sudo password at all); `.env` and `/etc/devshop-env` mode 600 root (F-SEC-02, F-SEC-03, F-SEC-15)
- [ ] **W1.3.3** Lock `notify/*` and any non-`.sh` hook executables (F-SEC-12) — V2
- [ ] **W1.3.4** Create-and-lock `.claude/settings.local.json` (empty) so it can't be introduced; or move to managed settings in W4.4 (F-SEC-10)
- [ ] **W1.3.5** Firewall: drop blanket TCP/22 + unrestricted DNS (resolver only); document CDN-IP limitation (F-SEC-11) — only if D-02 keeps local first-class
- [ ] **W1.3.6** `derive-ports-from-config.sh`: reject non-numeric ports (F-SEC-14) — V2
- [ ] **W1.3.7** Decide (with D-02) what happens to devshop-self locking (F-SEC-16) and the sticky-bit model (F-SEC-13): fix, or retire in W4.4 and document

## W1.4 Permission rules correct; security docs truthful — P0 · M1 · S

Findings: F-SEC-04, F-DOC-04.

- [ ] **W1.4.1** Rewrite absolute-path rules with `//` (e.g. `Edit(//devshop/kit/scripts/**)`); add a bats check that no permission rule starts with a single `/` meant as absolute; scenario in a Claude session: denied edit is denied (F-SEC-04) — V3
- [ ] **W1.4.2** Rewrite `kit/docs/guide/security.md` + `kit/notes/security/*` to state what is enforced, by what, and the known limits (per D-04); remove retired checks and false claims (F-DOC-04) — V1

## W1.5 GitHub-side controls + supply-chain pins (template) — P0 · M1 · M

Findings: F-SEC-08, F-SEC-18, F-SEC-20, F-INFRA-05.

- [ ] **W1.5.1** `/ak-new-project` branch protection: ≥1 required approval, CODEOWNERS (owner) on `.github/`, `.devshop/`, `.claude/`, migrations; required status checks (F-SEC-08) — V3 on a test repo
- [ ] **W1.5.2** Deploy workflows: `environment: production` with required reviewer; run only after CI succeeds on main (`workflow_run` or needs) (F-SEC-08) — V3 on a test repo
- [ ] **W1.5.3** Pin versions: Claude Code, pnpm, Node (single version everywhere), Supabase CLI, Actions by SHA, gitleaks with checksum (F-SEC-18, F-INFRA-05) — V1 + bats shape test
- [ ] **W1.5.4** Verify gitleaks config loads default rules (add `[extend] useDefault = true` if needed); scenario: committing a fake AWS key is blocked (F-SEC-20) — V3
