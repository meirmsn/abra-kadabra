## Gate 6: /review

Result: findings (1) fixed — the one P2 informational finding below (tracker prefix over-match) was cross-confirmed by Gate 5's tests-review and fixed by the orchestrator at commit `664602f` (exact-anchor file trackers `kit/TODOS.md|kit/ROADMAP.md|kit/version`; `kit/notes/*` stays a dir prefix). Boundary regression bats cases added (`kit/versioning.md`, `kit/ROADMAPER` → exit 1; `kit/notes/**` → exit 0). No remaining pending findings; no critical. Original gate disposition (PASS, 1 informational pending) retained below for the audit trail.

Scope check: CLEAN. Intent (commits + spec) = add a tracker-only range classifier (`audit-tracker-only.sh`) wired into the audit orchestrator's Step 1 to skip orphan `review.md` stubs on tracker-only ranges. Delivered = exactly that (helper + 9-case bats + SKILL.md Step-1 wiring + workflow.md note + kit/TODOS closure + FRICTION-LOG entry). No scope creep, no missing requirements. Diff is bash + markdown only — no SQL, no LLM trust boundary, no shell-injection surface, no auth/RLS, no migrations, no CI/CD publish changes.

### Findings by severity

**Critical (P0/P1):** none.

**Informational (P2):**

- [P2] (confidence: 7/10) `kit/scripts/preship/audit-tracker-only.sh:59` — Tracker prefix-globs `kit/TODOS*`, `kit/ROADMAP*`, `kit/version*` over-match. Empirically confirmed: a hypothetical non-tracker path `kit/versioning.md` (or `kit/TODOS-archive.md`, `kit/ROADMAPS/x.md`) classifies as tracker-only (exit 0) and would skip its audit. Risk is latent — no such file exists today, and `kit/version*` is a deliberate prefix because `kit/version` has no extension (documented at script line 22). `kit/notes/*` is correctly path-anchored (`/`), so only the three extension-less/prefix forms are loose.
  Recommended fix (operator decision; NOT auto-applied): tighten to `kit/TODOS.md|kit/ROADMAP.md|kit/version` exact-match where an extension exists, keeping the prefix only for the genuinely extension-less `kit/version`; OR add a negative boundary bats case asserting a prefix-adjacent non-tracker path resolves to exit 1; OR record the over-match as an accepted trade-off in the spec. Same edge the Gate 5 tests-review flagged as low.

### Verification performed (empirical, this gate)

- Exit-code contract: tracker-only/empty → 0; source/mixed/guide-doc/test-only → 1; usage (no arg) → 64; git-diff failure on unresolvable range → 1 (safe "audit" direction, message to stderr). All confirmed by probe in a scratch repo.
- Glob anchoring: `kit/docs/guide/ops.md` → exit 1 (guide docs ARE auditable, NOT short-circuited); `kit/docs/RANDOM.md` → exit 1; only `kit/docs/CHANGELOG.md` exact → tracker. Confirmed.
- `set -e` / git-diff-failure handling: `if ! CHANGED=$(git diff ...)` captures the failure in command position (verified: set -e does not swallow it into a false empty-diff exit-0). `bash -x` trace confirms the classify loop short-circuits to exit 1 on first source path.
- Whitespace-in-filename: `IFS= read -r path` over a heredoc handles a `kit/scripts/spaced file.sh` source path correctly (exit 1). No word-splitting bug.
- Deleted-tracker path: classified by path, not git status (exit 0). Correct.
- SKILL.md Step-1 preliminary-range parse (`audited-at` marker → `<SHA>..HEAD`, else `origin/main..HEAD`) is consistent with Step 2's documented parse contract.

## Dismissals

- **Empty `origin/main..HEAD` short-circuits (exit 0) on a fresh feature with no review.md.** Considered as a possible "skips scaffolding when it shouldn't" path. Dismissed: an empty diff genuinely has nothing to audit, so exit 0 / no-scaffold is correct. The dogfood run proved the non-empty source path scaffolds + audits normally.
- **`Enum & Value Completeness` cross-consumer trace.** N/A — the diff adds no enum/status/tier constant; the case-glob tracker set is self-contained and its consumers (SKILL Step 1, workflow.md) are all in-diff.
- **gstack onboarding / telemetry / learnings plumbing** in the skill preamble — not run; out of scope for a read-only audit gate inside a subagent.
