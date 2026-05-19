# Review — sandbox-qa-close-gap

## Audit 1: manual (2026-05-19)

<!-- audited-at: d31af1a0587c1e7ffa5620aa7ec73a1dad4e7f70 -->
<!-- range: origin/main..HEAD -->

findings: high=1 medium=1 low=1

### Docs findings

- [high] .claude/skills/devshop/pre-ship/SKILL.md:956 — SKILL.md claims `ffmpeg is installed for video: 'retain-on-failure' recording`, but ffmpeg was explicitly deferred per spec.md § "Scope explicitly NOT in this PR"; `grep -n ffmpeg template/Dockerfile` returns nothing. Cross-doc coherence violation — operators following this skill will diagnose missing ffmpeg as a workspace bug rather than intentional non-scope. Fix: either restore ffmpeg to scope (spec D2 pre-decided apt-add) or trim the ffmpeg clause from the SKILL.md update.
- [medium] kit/docs/guide/ops.md:271 — ops.md describes `init-firewall.sh`'s host.docker.internal allowance using hardcoded `54321 / :54322`, but the PR makes those ports env-var-driven (`SUPABASE_API_PORT` / `SUPABASE_DB_PORT`). No ops.md / architecture.md / security.md edit landed alongside the script change. Devshop rubric requires `kit/docs/guide/{architecture,security,ops}.md` for `template/.devcontainer/init-firewall.sh` changes. Fix: add a paragraph to `ops.md` describing the env-var resolution shape, `.devcontainer/.env` source, default fallback, and validation behavior.

### Tests findings

- [low] kit/tests/init-firewall-port-allowance.bats:42 — awk snippet-extraction anchors on the exact string `ENV_FILE="/workspace/.devcontainer/.env"`. A refactor that renames the variable or splits the assignment would silently produce an empty snippet; bash would succeed with no output and structural greps independently pass. Fix: add `[ -s "$SNIPPET" ] || fail "snippet extraction produced empty output"` sentinel in setup() — turns silent drift into a loud failure.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-19)

<!-- audited-at: 9dcdd4de425a3834cd0afa1fa5d7af267918fd32 -->
<!-- range: d31af1a..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none)

Clean. All three Audit 1 findings verified closed against the polish-range diff:

- HIGH (SKILL.md:956 ffmpeg over-claim) → 9dcdd4d trimmed the ffmpeg clause. Surrounding claims (Chromium via apt, fonts.googleapis.com allowlisted) verified against `template/.devcontainer/Dockerfile` line 44 + `template/.devcontainer/init-firewall.sh` line 115.
- MEDIUM (ops.md missing port-rebinding paragraph) → 4c6c37d added the paragraph at line 271. Names `SUPABASE_API_PORT`/`SUPABASE_DB_PORT`, `.devcontainer/.env` source, sudo-strips rationale, 1..65535 validation, default fallback (54321/54322), error behavior, env_file flow into compose. Substantive — claims verified against the worktree's `template/.devcontainer/init-firewall.sh` lines 248-269.
- Cross-doc coherence holds; no renames/deletes in range.

### Tests findings

- (none)

Only test-file change is the bats setup() sentinel — converted from `skip` to `fail` with action-oriented messages (closes Audit 1 LOW). Defensive tightening: snippet-extraction drift now surfaces as a red test instead of an invisible skip. No new source code in range → no Section A gap.

### Bypass trailer audit

- (none)
