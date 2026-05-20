# Audit 1 — Tests review

Range: `origin/main..HEAD` (4 commits)
Feature: `db-hardening-template-lift`

## Findings

### [domain: tests] [section: A] [severity: medium]

**File**: `kit/scripts/adversarial-review.sh:413-449` (new `advisorBypassReason` check-type)
**What**: The new `advisorBypassReason` check-type added to `adversarial-review.sh` has no dedicated `.bats` spec, breaking the established pattern (`util-adversarial-review-coreUserStoryNaReason.bats`, `util-adversarial-review-localTestSkipReason.bats`, `util-adversarial-review-blocked-dismissal.bats`, `util-adversarial-review-narrowing.bats`). The check-type adds ~37 lines of new behavior: CONTEXT construction (branch + HEAD SHA + filtered migration diff harvest), Sonnet model routing (`get_model_for_check_type` extension), and convention-inlining wiring (`get_conventions_to_inline` extension to inline "Supabase Hardening Defaults").
**Why**: The only test path that hits `advisorBypassReason` is `preship-advisor-clean.bats § "bypass pass when DEVSHOP_SKIP_ADVERSARIAL=1"`, which intentionally **skips** the adversarial reviewer via the env-var bypass — so the new reviewer code is not exercised at all. A typo in the CONTEXT heredoc, a regression in `get_model_for_check_type` (defaulting to Haiku instead of Sonnet), or a stale convention name in `get_conventions_to_inline` would ship silently. The other check-types each have a `util-adversarial-review-*` spec proving they get the right model, the right convention inlining, and the right PASS/FAIL routing on representative reasons.
**Fix**: Add `kit/tests/util-adversarial-review-advisorBypassReason.bats` mirroring the shape of `util-adversarial-review-localTestSkipReason.bats`. Cover: (a) reason FAILs when generic ("extension-in-public is fine"); (b) reason PASSes when per-finding + TODOS pointer ("extension-in-public per pgcrypto migration risk; tracked at TODOS.md L42"); (c) `get_model_for_check_type advisorBypassReason` returns `sonnet`; (d) `get_conventions_to_inline advisorBypassReason` returns `Supabase Hardening Defaults`. Stub the Claude CLI invocation per the existing pattern.

### [domain: tests] [section: A] [severity: medium]

**File**: `kit/tests/template-advisor-probe.bats` + `template/scripts/advisor-probe.mjs:71-323`
**What**: The 9 `pg_catalog` SQL queries that are the entire load-bearing logic of `advisor-probe.mjs` are never exercised against any Postgres instance. The bats spec only verifies file existence, lint-name string presence, ADVISOR-EXEMPT regex existence, and error-message string presence — all source-grep tests with zero behavioural coverage of the SQL. The test file's own header acknowledges the gap ("Live Postgres-connected tests are covered indirectly by the advisor-clean gate against a real local Supabase stack"), but `preship-advisor-clean.bats` doesn't connect to real Postgres either — it stubs `psql` and stubs `pnpm`. Neither test ever runs an actual lint query.
**Why**: A typo in any lint's WHERE clause (e.g. `c.relrowsecurity = false` typed as `c.relrowsecurity = 'f'` — Postgres tolerates the cast but the semantics shift on a future column-type change; or `pg_policies.qual` typed as `pg_policy.qual` — silently zero rows on every project) ships invisibly. The manual smoke captured in the session is one-time evidence, not regression coverage. Of the 9 lints, only the `auth_rls_initplan` regex was empirically tuned during this session; the other 8 have only the developer's read-through as confidence.
**Fix**: Either (a) add an integration spec under `kit/tests/` that boots a throwaway Postgres (e.g. via `pg-mem` or a one-shot docker postgres) and seeds known-buggy schemas to assert each lint flags the expected object; or (b) add a `[blocked-by: live-stack-required]` entry to `kit/TODOS.md` naming this gap with a recipe ("when CI gets a Postgres service, port the per-lint fixtures from spec.md § Verification"). The current state — header comment acknowledging the gap with no tracker pointer — is exactly the pattern that grows invisible coverage debt.

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/template-advisor-probe.bats:21-25`
**What**: `@test "probe defines all 9 advisor lints"` asserts only `grep -c 'async function lint'` equals `"9"` — a count of function declarations.
**Why**: A regression where someone adds a `lintFoo` declaration but forgets to add it to the `lints` array in `main()` (`advisor-probe.mjs:340-350`) passes this test cleanly. The lint is defined but never invoked; the gate still reports 9 lints "ok" because `results` only contains 8 invocations. The lint-ID-string test (`probe names match documented lint IDs`) catches a missing string literal but not a missing array entry — the lint name appears in the `return { lint: "...", ... }` line regardless of whether the function is in the driver's `lints` array.
**Fix**: Add an assertion that the `lints` array in `main()` contains all 9 function references. Cheap: `grep -A 12 'const lints = \[' "$PROBE" | grep -c 'lint[A-Z]'` should equal `"9"`. Or pivot the test from source-grep to behaviour: spawn the probe with a stubbed `pg` mock and assert all 9 lint names appear in stdout.

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/template-advisor-probe.bats:43-49`
**What**: `@test "probe parses ADVISOR-EXEMPT markers from migrations"` asserts the regex literal `ADVISOR-EXEMPT\(` and the substring `exemptions.has(` appear in source — both are source-greps, not behaviour checks.
**Why**: The exemption mechanism is the only way to whitelist a flagged finding without triggering the adversarial bypass review. A regression where `loadExemptions()` returns an empty Set unconditionally (e.g. the `readdirSync` loop is broken by a typo, or the regex match is silently case-sensitive on a case-insensitive lint name) would pass this test cleanly. Operators would see findings on a lint they had annotated as `-- ADVISOR-EXEMPT(rls_disabled_in_public): <reason>` and have no test signal that the exemption mechanism stopped working.
**Fix**: Add a behaviour test: write a fake migration file containing `-- ADVISOR-EXEMPT(function_search_path_mutable): test`, invoke a minimal driver-stub that calls `loadExemptions()` and asserts the returned Set contains `function_search_path_mutable`. Or, if extracting the helper is too invasive, write a node one-liner test: `node -e "import('./advisor-probe.mjs').then(...)"` — though the script's top-level `main()` invocation makes this awkward. The cheap version: factor `loadExemptions` into an exported helper and unit-test it directly.

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/preship-advisor-clean.bats:207-218` (exit-2 routing test)
**What**: `@test "live: probe exit 2 → gate emits 'blocked (advisor-probe failed)'"` asserts only the `blocked (advisor-probe failed)` prefix string. The gate's actual stdout is `blocked (advisor-probe failed): <probe-output-first-3-lines-joined-with-spaces>` (`advisor-clean.sh:139`).
**Why**: The probe-error-excerpt formatting (`echo "$probe_out" | head -3 | tr '\n' ' '`) is part of the operator-facing contract — operators rely on the excerpt to diagnose `pg-not-installed` vs `query-syntax-error` vs other probe failures. A regression that drops the excerpt (e.g. `head -3` typoed to `head -0`, or the `tr` removed leaving the heredoc-style newlines that break log formatting in the calling gate's `## Findings` capture) would pass this test. The fix recipe in the exit-1 test does pin specific lines (`kit/docs/guide/security.md`, `ADVISOR-EXEMPT`); the exit-2 test should follow the same shape.
**Fix**: Extend the assertion to `assert_output --partial "blocked: 'pg' is not installed"` — the stubbed pnpm already echoes that string on line 211, so the excerpt should propagate through the gate's `echo "$probe_out" | head -3 | tr '\n' ' '` and appear in the final stdout. This makes the test sensitive to a real regression in the excerpt formatting.

## Section C — Bypass trailers

Zero `Tests-Coverage-Bypass:` trailers in `origin/main..HEAD`. The bypass trailer mechanic activates in PR-C; this section legitimately harvests zero rows.

## Summary

high=0 medium=2 low=3
