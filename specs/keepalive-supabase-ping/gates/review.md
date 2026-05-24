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
