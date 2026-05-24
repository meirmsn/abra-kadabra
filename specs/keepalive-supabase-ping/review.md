<!-- audited-at: 324f0dbdd739252956af8fc380237465aa800c16 -->

## Gate 1: docs-check

**Scope**: Does the diff (template keepalive.yml + bats test) make any existing doc stale or require a new doc entry?

### Docs checked

| Doc | Keepalive-relevant content | Stale after this diff? |
| --- | --- | --- |
| `kit/docs/guide/ops.md` line 398 | Parenthetical: `PRODUCTION_URL` "(used by `keepalive.yml`)" — format divergence note | No — still accurate; the existing Vercel ping step still uses `vars.PRODUCTION_URL` |
| `kit/docs/guide/ops.md` lines 118-126 | GH Variables table — `SUPABASE_URL` = `http://127.0.0.1:54321`, `SUPABASE_ANON_KEY` = local-stack JWT | No — table correctly describes what the GH Variables hold. See implementation concern below. |
| `kit/docs/guide/security.md` line 91 | CI Credential Isolation — `SUPABASE_URL` GH Variable = local-stack | No — still accurate |
| `CLAUDE.md` | No keepalive-specific content | N/A |
| `kit/docs/guide/conventions.md` | No keepalive-specific content | N/A |
| `kit/docs/OVERVIEW.md` | No keepalive-specific content | N/A |

### Finding: implementation-level variable mismatch (not a docs defect)

The keepalive workflow's new Supabase ping step uses `vars.SUPABASE_URL` and `vars.SUPABASE_ANON_KEY`. Per the documented GH Variable layout (`ops.md` table, `security.md` line 91, `/ak-new-project` SKILL.md lines 562-564), these variables hold **local-stack** values (`http://127.0.0.1:54321` + default JWT) — not the prod Supabase URL. The keepalive workflow runs on a bare `ubuntu-latest` runner with no local Supabase stack, so the curl would hit `127.0.0.1:54321` (connection refused), emit a `::warning::`, and **not actually prevent Supabase auto-pause**.

The workflow should reference `vars.SUPABASE_PROD_URL` (which holds the prod URL per `/ak-new-project` SKILL.md line 573) or introduce a dedicated variable. This is an implementation concern to surface to the operator, not a docs staleness finding — the docs are correct about what the variables hold.

### New doc entry needed?

No. The keepalive workflow is a simple CI workflow whose behavior is self-documenting in the YAML file. No existing guide section describes keepalive behavior in prose that would need updating. The TODOS entry (`kit/TODOS.md` lines 10-19) captures rationale and will be closed in Phase 4.0.

### Verdict

**pass** — no existing docs are stale; no new doc entry required. The variable mismatch is an implementation concern (surfaced above for the operator) rather than a documentation gap.

## Dismissals

None

## Gate 2: metrics-check

- Result: n/a (devshop-self-mode: no METRICS.md in devshop)

## Dismissals

None

## Gate 2b: rls-coverage

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 2c: slow-job-lifecycle

- Result: n/a (devshop-self-mode: no slow-job CI)

## Dismissals

None

## Gate 2d: fast-job-local

- Result: pass (1325 bats tests green, including 9 new keepalive-yml-shape assertions)

## Dismissals

None

## Gate 2e: migration-rollback-roundtrip

- Result: n/a (devshop-self-mode: no migrations)

## Dismissals

None

## Gate 2f: changed-tests-local

- Result: n/a (devshop-self-mode: bats run in Gate 2d covers this)

## Dismissals

None

## Gate 2g: advisor-clean

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 3: responsive-theme

- Result: n/a (devshop-self-mode: no UI surface)

## Dismissals

None

## Gate 4: /simplify

**Outcome: pass**

Reviewed both files in the diff:

1. `template/.github/workflows/keepalive.yml` (21 lines) -- minimal workflow with one cron trigger, one job, two steps. No redundancy, no dead code, no unnecessary abstraction. The two curl patterns intentionally differ (exact 200 check for production vs 2xx range for Supabase PostgREST) -- semantically correct, not a DRY candidate.

2. `kit/tests/template-keepalive-yml-shape.bats` (53 lines, 9 tests) -- each test asserts a distinct structural contract. The sed-based block extraction in test 8 includes a defensive fallback for the "last step" case that is currently unreachable but guards against future step reordering. One-line guard, not worth removing.

No simplification opportunities found. No fixes applied.

**Test checkpoint:** 9/9 bats tests pass.

## Dismissals

None

## Gate 5: docs-and-tests-review

<!-- audited-at: be6cc95eaadc6da5ec79e3662e0a394b82f7808f -->

**Outcome: findings**

findings: high=0 medium=1 low=1

Commit range: `origin/main..HEAD` (5 commits). Audited 2026-05-24.

---

### Docs coverage

1. **[medium] `ops.md` GH Variables table missing `SUPABASE_PROD_ANON_KEY` row.** The canonical env-var lookup table at `kit/docs/guide/ops.md` lines 118-125 lists `SUPABASE_PROD_URL` but omits `SUPABASE_PROD_ANON_KEY`. The keepalive workflow now depends on this variable (`vars.SUPABASE_PROD_ANON_KEY` in the Ping Supabase step). The variable is already documented in `/ak-new-project` SKILL.md (line 694), but ops.md is the canonical "which GH Variables exist and what they mean per surface" index -- operators looking up variable requirements will miss it. Pre-existing gap widened by this diff (previously only deploy-adjacent; now also keepalive).

   **Fix**: Add a `SUPABASE_PROD_ANON_KEY` row to the ops.md table between `SUPABASE_PROD_URL` and `SENTRY_DSN`, with columns: `prod anon key (keepalive + deploy)` | `_(piped to NEXT_PUBLIC_SUPABASE_ANON_KEY at Step 13)_` | description matching the existing `SUPABASE_PROD_URL` row pattern.

2. **ops.md line 398 (`PRODUCTION_URL` used by `keepalive.yml`)** -- still accurate. The existing Vercel ping step retains `vars.PRODUCTION_URL`. No update needed.

3. **security.md line 91 ("deploy workflows consume `SUPABASE_PROD_URL`")** -- still technically accurate (scoped to "deploy workflows"). The keepalive workflow is not a deploy workflow; it consumes `SUPABASE_PROD_URL` + `SUPABASE_PROD_ANON_KEY` for a health-check ping, not for deployment. No update required, but the medium finding above (ops.md table) is the right place to close the documentation gap.

4. **No other guide docs reference keepalive behavior that would be stale from this diff.** `notifications.md` line 72 uses "keep alive" in a different context (Safari PWA). CLAUDE.md has no keepalive references.

### Tests coverage

5. **9 bats assertions adequately pin the new behavior.** Coverage map:
   - File existence (test 1)
   - Cron schedule value (test 2)
   - Both step names present (tests 3, 4)
   - Prod-specific variable names used (tests 5, 6)
   - Correct PostgREST endpoint path (test 7)
   - Warning emission scoped to Supabase step block (test 8)
   - Step ordering (test 9)

   All 9 pass. No missing structural assertions identified for the scope of changes.

### Test quality

6. **[low] Tests 5-6 verify positive case only despite promising negative.** Test names say `(not vars.SUPABASE_URL)` and `(not vars.SUPABASE_ANON_KEY)` but the assertions only `grep -q` for the correct variable name -- they do not assert the absence of the wrong name. A regression where someone adds BOTH variable names would pass. Unlikely in practice (the wrong name would be a second curl invocation pointing at localhost), and the positive assertion is the load-bearing one. Cosmetic gap.

7. **Test 8 correctly scopes `::warning::` grep to the Supabase step block** using sed range extraction, avoiding false-positive matching from the production step. Good technique.

8. **Test 9 (step order) uses line-number comparison** -- meaningful structural assertion, not just pattern matching.

9. **All tests are pure file-content checks** (no real GitHub Actions runner, no network). Matches the `template-ci-yml-shape.bats` reference pattern. Deterministic and fast.

---

## Dismissals

None

## Gate 6: /review

**Scope**: `origin/main..HEAD` (5 commits) — adds Supabase PostgREST ping step to template keepalive workflow, bumps cron to twice-weekly, adds bats structural tests.

**Files reviewed**:
- `template/.github/workflows/keepalive.yml` (modified)
- `kit/tests/template-keepalive-yml-shape.bats` (new)
- `specs/keepalive-supabase-ping/spec.md` (new)
- `kit/TODOS.md` (modified — new entry)
- `PLAN.md` (modified — new row in Planned table)

### 1. Correctness

**Does the curl command work on a bare GitHub Actions runner?** Yes. `curl` ships on all `ubuntu-latest` images; the existing Vercel ping step already uses the identical `curl -s -o /dev/null -w "%{http_code}"` pattern, proving it runs. The `-H "apikey: ..."` header is standard PostgREST auth and requires no extra tooling.

**Does `/rest/v1/` register as Supabase API activity?** Yes. PostgREST's root endpoint returns the OpenAPI schema listing. Any authenticated request to `*.supabase.co/rest/v1/*` counts as API activity for Supabase's inactivity tracker. The anon key in the `apikey` header is sufficient.

**Cron expression `0 9 * * 1,4`**: correct for Monday + Thursday at 09:00 UTC. Comment matches.

### 2. Security

- `vars.SUPABASE_PROD_URL` and `vars.SUPABASE_PROD_ANON_KEY` are GitHub Variables (not Secrets). The anon key is public-tier — it is embedded in every client-side bundle and is not secret material. Using Variables (not Secrets) is intentional and correct: values are visible in workflow logs for debugging, and there is no security benefit to masking a public key.
- Prod-specific variable names (`SUPABASE_PROD_*`) correctly avoid collision with CI's `SUPABASE_URL` (which points to `127.0.0.1:54321` for test isolation per `CLAUDE.md § CI Credential Isolation`).
- No secrets are referenced or leaked. No service-role key involved.

### 3. Edge cases: empty/unset variables

If `SUPABASE_PROD_URL` or `SUPABASE_PROD_ANON_KEY` is not configured as a GitHub Variable, `${{ vars.X }}` expands to empty string. The curl command becomes `curl -s -o /dev/null -w "%{http_code}" "/rest/v1/" -H "apikey: "`, which returns `000` (connection error). The `-lt 200` comparison with `STATUS="000"` evaluates to true, so the `::warning::Supabase returned 000` annotation fires. This is correct — the step warns but does not fail the workflow.

Edge case: if `STATUS` is literally empty string (theoretically impossible since curl `-w "%{http_code}"` always outputs something, but defensively), `[ "" -lt 200 ]` produces a bash integer comparison error. However, inside an `if` condition, this error does NOT trigger `bash -e` abort — the error is caught by the `if` shell grammar. The `||` short-circuits through `[ "" -ge 300 ]` (also errors), and the overall condition evaluates to true. The warning fires and the step completes. Verified via `bash -e -o pipefail` simulation (GitHub Actions' exact shell flags).

### 4. Range check (`-lt 200 || -ge 300`) vs exact match (`!= 200`)

The Supabase ping uses `[ "$STATUS" -lt 200 ] || [ "$STATUS" -ge 300 ]` (2xx range check) while the Vercel ping uses `[ "$STATUS" != "200" ]` (exact 200 match).

The range check is the better choice for PostgREST:
- PostgREST can return `200 OK` (schema listing at root) but other endpoints may return `201 Created`, `204 No Content`, etc. While `/rest/v1/` specifically returns 200, the range check is more robust if the endpoint's behavior changes or if the URL is customized.
- The range check correctly treats `000` (curl connection failure) as non-2xx, same as the exact match treats it as non-200.
- No functional regression vs the Vercel step: `200 != 200` is false, `200 -lt 200` is false AND `200 -ge 300` is false — both correctly produce no warning on success.

Minor observation: the Vercel ping could also benefit from a range check (e.g., Vercel occasionally returns `308` redirects or `503` maintenance responses), but that is out of scope for this change.

### 5. Test quality

9 bats tests — all pure structural assertions (grep/sed on file content, no runner needed). Tests verify:
- File existence, cron expression, both step names, prod-specific variable names, endpoint path, warning emission, step ordering.
- The `::warning::` test correctly extracts the Supabase block (sed range between "Ping Supabase" and next `- name:` or EOF) to avoid false-positive matching on the Vercel step's `::warning::`.

No gaps found in test coverage for the scope of this change.

### 6. Spec and documentation

- Spec cleanly documents the three decisions (endpoint choice, cron frequency, credential storage) with rationale.
- TODOS entry is thorough — includes the root cause (Supabase measures its own API activity, not downstream frontends), the fix recipe, and the existing-project edit targets.
- PLAN.md row has the correct Lev score (16.0 = high-impact/low-cost) and source pointer.

### Verdict

**pass** — no findings. Implementation is correct, secure, handles edge cases properly, and tests are comprehensive for the scope.

## Dismissals

None

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself)

## Dismissals

None

## Gate 8: /design-review

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface)

## Dismissals

None

## Gate 8b: design-conformance

- Result: n/a (devshop-self-mode: no DESIGN.md)

## Dismissals

None

## Gate 9: /qa

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface; bats invariants are the test surface and run in Gate 2d)

## Dismissals

None

## Gate 10: /benchmark

- Result: blocked (n/a per scope: devshop-self-mode — no perf surface)

## Dismissals

None

## Gate 10b: preflight-final

- Result: n/a (devshop-self-mode: bats recheck in Gate 2d covers this)

## Dismissals

None

## Gate 11: convention

**Outcome: pass**

Checked 2026-05-24. Devshop-mode convention check for `keepalive-supabase-ping`.

### Checks performed

1. **Bats test file exists and passes** -- `kit/tests/template-keepalive-yml-shape.bats` present with 9 assertions, all pass (verified via vendored bats runner).
2. **Bats test follows repo patterns** -- shebang `#!/usr/bin/env bats`, `load helpers/setup`, `DEVSHOP="$(git rev-parse --show-toplevel)"` setup, pure file-content checks (no runner needed). Matches `template-ci-yml-shape.bats` reference.
3. **Conventional commits** -- all 5 commits on branch use conventional-commit format (`feat`, `fix`, `chore` prefixes with scopes). All subjects <= 72 chars. All carry `Co-Authored-By:` trailer.
4. **Spec structure** -- `specs/keepalive-supabase-ping/spec.md` has all required sections: `## Product update` (Headline + Detail), `## Decisions`, `## In scope`, `## Out of scope`, `## Tests`, `## Gotchas`, `## Task order`.
5. **TODOS entry updated** -- `kit/TODOS.md` entry for "Keepalive workflow pings Vercel but not Supabase" updated with correct `SUPABASE_PROD_URL` + `SUPABASE_PROD_ANON_KEY` variable names.
6. **Existing projects block** -- present in the feat commit body (`46689b9`), names `home-os` and `lalista` as affected scaffold-once projects. Notes stale variable names (`SUPABASE_URL`/`SUPABASE_ANON_KEY` instead of the corrected `SUPABASE_PROD_*`) in the intermediate commit, but this is a squash-merge branch -- the squash body will be composed fresh by `/ak-merge-devshop` Phase 0.3 with the corrected names.
7. **PLAN.md entry** -- `keepalive-supabase-ping` in Planned table with Lev scoring (16.0), Source pointer to `kit/TODOS.md`, all columns filled.
8. **No `.ts`/`.tsx` files** -- 3-line header convention not applicable (YAML + bats only).
9. **No metrics needed** -- CI workflow template change, not a user-facing feature.

## Dismissals

None

## Phase 3 → 4 advance log

### 2026-05-24T16:07:22Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-24T16:07:22Z -->

### 2026-05-24T16:07:22Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-24T16:07:22Z -->

### 2026-05-24T16:07:22Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants are the test surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-24T16:07:22Z -->

### 2026-05-24T16:07:22Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-24T16:07:22Z -->

## Audit 1: manual (2026-05-24)

<!-- audited-at: 186f4ad289ae751ebdf96c31a3cfc121ffa6db56 -->
<!-- range: be6cc95..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none)

All 3 commits in range are non-code: `324f0db` adds `SUPABASE_PROD_ANON_KEY` row to ops.md GH Variables table (closing the Gate 5 medium finding), `83b718a` adds Phase 3 gate sink files (review artifacts), `186f4ad` closes BUILD-LOG/PLAN/TODOS entries for shipped feature. No new documentation gaps introduced. The ops.md table update is complete and accurate. TODOS/PLAN closure follows the "close tracker entries when fix ships" convention.

### Tests findings

- (none)

No commits in range add or modify code, templates, or testable behavior. All changes are documentation updates, review artifacts, and build bookkeeping. The existing 9 bats tests (verified passing in Gate 2d) cover the template changes from earlier commits.

### Bypass trailer audit

- (none)

