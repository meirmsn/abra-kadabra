### [domain: tests] [section: A] [severity: high]

**File**: `kit/tests/template-compose-isolation.bats:180-183`
**What**: The diff narrows the `--dport ... -j ACCEPT` assertions from the env-var-quoted form (`--dport "$SUPABASE_API_PORT" -j ACCEPT` / `--dport "$SUPABASE_DB_PORT" -j ACCEPT`) to the literal-number form (`--dport 54321 -j ACCEPT` / `--dport 54322 -j ACCEPT`) and deletes the two paired `SUPABASE_API_PORT="?${SUPABASE_API_PORT:-54321}"?` / `SUPABASE_DB_PORT="?${SUPABASE_DB_PORT:-54322}"?` default-assertion checks entirely. The actual `template/.devcontainer/init-firewall.sh` shipped by this branch uses the env-var form at lines 268-269 (`iptables -A OUTPUT -d "$HOST_DOCKER_INTERNAL" -p tcp --dport "$SUPABASE_API_PORT" -j ACCEPT`), so the rewritten grep matches nothing and the test fails. Verified by running `./kit/tests/lib/bats-core/bin/bats kit/tests/template-compose-isolation.bats` — test #19 (`compose-isolation: init-firewall.sh has the host.docker.internal allow rule (getent ahostsv4)`) reports `not ok` with `status: 1` against the rewritten `grep -E -- '--dport 54321 -j ACCEPT'` line.
**Why**: Per `.husky/pre-commit:10-12`, bats runs on every devshop commit and blocks the push when any test fails. A broken bats spec landing on `feat/template-baseline` means either the pre-commit guard was bypassed (no `Tests-Coverage-Bypass:` trailer in the range; bypass flag would still need adversarial review) or the test was edited in a state where it accidentally passed. Either way, `/ak-merge-devshop` Phase 1 will run bats and fail — the merge will not advance to main. Downstream: the regression guard that proves the Supabase data-plane ports are allow-listed at the firewall has lost its assertion entirely; a future refactor that drops the iptables rules would not be caught by this spec.
**Fix**: Restore the env-var-form assertions to match the actual file shape, and restore the two default-fallback assertions that were deleted. Concretely:

```bash
run grep -E -- '--dport "\$SUPABASE_API_PORT" -j ACCEPT' "$f"
assert_success
run grep -E -- '--dport "\$SUPABASE_DB_PORT" -j ACCEPT' "$f"
assert_success
run grep -E 'SUPABASE_API_PORT="?\$\{SUPABASE_API_PORT:-54321\}"?' "$f"
assert_success
run grep -E 'SUPABASE_DB_PORT="?\$\{SUPABASE_DB_PORT:-54322\}"?' "$f"
assert_success
```

If the intent was to revert init-firewall.sh to literal ports (de-scoping the 94de8d7 env-aware-ports work), then init-firewall.sh itself must change in the same commit so the test matches the file — and the deleted env-var default assertions must remain deleted intentionally. Either direction must arrive as one self-consistent commit; the current shape is half-rewritten and breaks the suite.

### [domain: tests] [section: B] [severity: medium]

**File**: `kit/tests/structural-invariants.bats:608-625`
**What**: The diff removes the worktree-aware repo-root resolution (`repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "$DEVSHOP")`) plus the preceding 8-line comment explaining its rationale, and reverts the `ls-files` query to `git -C "$DEVSHOP" ls-files ...`. The retained comment block (which still exists upstream of the diff) explicitly documents that the worktree-aware form was load-bearing: "feature branches in a linked worktree can't validate their own chmod fixes (the test would always reflect /devshop main's state, making it impossible to land a fix on a feature branch and have bats confirm the fix before /ak-merge-devshop runs)."
**Why**: The test still passes on `feat/template-baseline` because the chmod state of `kit/scripts/**/*.sh` is unchanged in this branch, so the regression is silent. The cost shows up the next time a feature branch ships a chmod fix in a linked worktree — the bats spec on that branch will report `ok` against `/devshop` main's stale state instead of the worktree's actual `ls-files -s` output, and a fix that depends on the worktree's chmod will get a false-green from bats before `/ak-merge-devshop` runs the squash-and-FF. The class of bug this test was hardened against (chmod drift between worktree and main) no longer has coverage.
**Fix**: Restore the worktree-aware `repo_root` resolution that the diff removed. The original shape:

```bash
local repo_root
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "$DEVSHOP")
# ...
done < <(git -C "$repo_root" ls-files -s 'kit/scripts/**/*.sh' 'kit/scripts/*.sh')
```

The fallback to `$DEVSHOP` preserves the prior behavior when `git rev-parse` fails (which is rare — bats runs from within a checkout), and the `2>/dev/null` keeps the test silent in project-repo runs where `kit/scripts/` isn't tracked. If there was a concrete reason to revert (e.g. a flaky run in a specific CI shape), capture it in the commit message and gate the revert on the actual symptom — the current diff offers no rationale.

### [domain: tests] [section: A] [severity: low]

**File**: `template/apps/web/e2e/sign-up.spec.ts:31` + `template/apps/web/e2e/forgot-password.spec.ts:29,40,50,57`
**What**: Both new E2E spec skeletons `page.goto('/sign-up')` / `page.goto('/sign-in')` / `page.goto('/forgot-password')` / project-side reset-password page, but the scaffold's `template/apps/web/app/` ships only `layout.tsx` + `page.tsx` + `globals.css` — none of those auth routes exist. Running `pnpm test:e2e` on a fresh `/ak-new-project` scaffold immediately after Step 12 will fail at the first `page.goto` with a 404 from `pnpm dev`. The spec headers and the third commit's body acknowledge this is intentional ("worked example", "Project-specific: replace with..."), and `package.json` ships `--passWithNoTests` on `test`/`test:unit` to keep the unit-test inner loop green — but `test:e2e` has no such guard.
**Why**: The convention is fine when the scaffold ships docs naming the contract ("E2E skeletons assume `/sign-up` + `/sign-in` + `/forgot-password` routes exist; delete or rewrite when scaffolding"), but the scaffold's `template/apps/web/README.md` doesn't carry that note and the `playwright.config.ts` doesn't mark the suite as expected-to-fail. A new project running `/ak-pre-ship` Gate 9 (or any operator running `pnpm test:e2e` to verify the scaffold) will get a failing E2E suite with no signal that this is intentional — a false-fail that erodes trust in the gate.
**Fix**: Either (a) add a `template/apps/web/README.md` § "E2E baseline" subsection naming the contract ("these specs target `/sign-up`, `/sign-in`, `/forgot-password`, and a project-defined reset-password page; delete the specs that don't match your routes before running `pnpm test:e2e`"), or (b) gate the specs with `test.skip(!process.env.E2E_AUTH_ROUTES_READY, 'auth routes not scaffolded yet; set E2E_AUTH_ROUTES_READY=1 to enable')` so fresh-scaffold runs report `skipped` rather than `failed`. Option (a) is the lighter touch and consistent with the template's "worked example" framing.

### Section C — Bypass trailer audit

No `Tests-Coverage-Bypass:` trailers harvested in the range. Section is a no-op.
