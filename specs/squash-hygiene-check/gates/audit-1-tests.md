# Tests audit — `fix/squash-hygiene-check` (Audit 1)

Range: `origin/main..HEAD` (commits `6df305d`, `0f62960`, merge `d302d70`).

Scope:
- `kit/scripts/adversarial-review.sh` — new `surface=squash` branch in `prTextHygieneReason` case.
- `.claude/skills/devshop/merge-devshop/SKILL.md` — new Phase 0.4.5 + Phase 0.5 verdict-aware routing.
- `kit/tests/util-adversarial-review-narrowing.bats` (+4 tests for `surface=squash`).
- `kit/tests/util-ak-merge-devshop.bats` (+10 tests for Phase 0.4.5 / Phase 0.5).
- Docs touches (CLAUDE.md, hooks.md, conventions.md) — covered by `/ak-docs-review`, not audited here.

---

## Section A — Coverage of new behavior

**Source change → test pair**

| Diff hunk | Covering test(s) | Status |
|---|---|---|
| `adversarial-review.sh` — `if [ "$SURFACE" = "squash" ]` branch entry | `prTextHygieneReason squash-surface: reads from DEVSHOP_HYGIENE_MESSAGE_FILE + reaches claude` | covered |
| `adversarial-review.sh` — `head -1 "$MSG_FILE"` subject extraction | same test (asserts `feat(squash): make commit subjects describe the observable change` in prompt) | covered |
| `adversarial-review.sh` — `tail -n +2 "$MSG_FILE"` body extraction | same test (asserts `Adds:` in prompt) | covered |
| `adversarial-review.sh` — `[ -z "$MSG_FILE" ] \|\| [ ! -f "$MSG_FILE" ]` guard, missing-file branch | `prTextHygieneReason squash-surface: FAIL fast when MESSAGE_FILE missing (no LLM call)` | covered |
| `adversarial-review.sh` — same guard, empty-string branch | `prTextHygieneReason squash-surface: empty DEVSHOP_HYGIENE_MESSAGE_FILE also FAILs fast` | covered |
| `adversarial-review.sh` — default-surface regression (PR path unchanged when env var unset) | `prTextHygieneReason default surface (no env var) still goes through the PR path` | covered |
| `adversarial-review.sh` — squash NOTE: "SKIP rule (c)" prompt fragment | happy-path test asserts `SKIP rule (c) Body` + `bold-led-bullet` | covered |
| `adversarial-review.sh` — squash NOTE: rules (a) + (b) still apply | happy-path test asserts `Description accuracy` + `Title readability` | covered |
| SKILL.md Phase 0.4.5 — sub-phase header between 0.4 and 0.5 | `Phase 0.4.5 exists as a sub-phase header between 0.4 and 0.5` | covered |
| SKILL.md Phase 0.4.5 — invokes shared adversarial-review.sh engine | `Phase 0.4.5 invokes the SHARED adversarial-review.sh engine (no duplicated logic)` | covered |
| SKILL.md Phase 0.4.5 — `DEVSHOP_HYGIENE_SURFACE=squash` selector | `Phase 0.4.5 selects the squash surface via DEVSHOP_HYGIENE_SURFACE=squash env var` | covered |
| SKILL.md Phase 0.4.5 — `DEVSHOP_HYGIENE_MESSAGE_FILE` + `DEVSHOP_HYGIENE_BRANCH` wiring | `Phase 0.4.5 passes the tempfile + branch via DEVSHOP_HYGIENE_MESSAGE_FILE + DEVSHOP_HYGIENE_BRANCH` | covered |
| SKILL.md Phase 0.4.5 — `HYGIENE_VERDICT` + `HYGIENE_OUTPUT` capture | `Phase 0.4.5 captures verdict into HYGIENE_VERDICT (PASS/FAIL) for Phase 0.5` | covered |
| SKILL.md Phase 0.4.5 — WHY rationale (mechanism-led / jargon / 72-char / shared engine) | `Phase 0.4.5 explains WHY (one place, no duplication) — and names what it catches` | covered |
| SKILL.md Phase 0.5 — PASS vs FAIL verdict routing | `Phase 0.5 routes on HYGIENE_VERDICT (PASS vs FAIL framing)` | covered |
| SKILL.md Phase 0.5 FAIL branch — "Approve anyway" override option | `Phase 0.5 FAIL branch offers 'Approve anyway' as the explicit override` | covered |
| SKILL.md Phase 0.5 FAIL branch — `Hygiene-Override:` trailer in body | `Phase 0.5 'Approve anyway' lands a Hygiene-Override trailer in the commit body` | covered |
| SKILL.md Phase 0.5 Edit loop — re-runs Phase 0.4.5 after edit | `Phase 0.5 Edit loop re-runs Phase 0.4.5 after each edit (verdict can flip)` | covered |

Every new behavior in the diff has at least one covering test. Coverage rubric for devshop-side (`kit/scripts/**.sh` → matching `.bats`) is satisfied — `adversarial-review.sh` was already paired with `util-adversarial-review-narrowing.bats`, and the new surface branch is exercised by 4 added tests in that file.

No Section A findings.

---

## Section B — Test quality

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/util-adversarial-review-narrowing.bats:161`
**What**: The happy-path test (`prTextHygieneReason squash-surface: reads from DEVSHOP_HYGIENE_MESSAGE_FILE + reaches claude`) verifies the squash NOTE, subject, body, and rules (a)+(b) are in the prompt, but does NOT assert the **constituent commits list** header (`Constituent commits being squashed (origin/main..$HYG_BRANCH):`) was emitted. The `COMMITS=$(git log --oneline ...)` interpolation could silently break (e.g., a future refactor that drops the `git log` call or mis-quotes the range) without a failing test.
**Why**: Rule (a) "accuracy" judging depends on the reviewer seeing the constituent commits; if the list header or body silently goes missing, the reviewer can no longer cross-check title/body claims against commits, but every existing assertion (subject, body, NOTE) still passes. The bug would surface as the reviewer issuing FAIL or generic verdicts in production rather than a failing test.
**Fix**: add a single grep to the happy-path test:
```bash
grep -q "Constituent commits being squashed" "$CAPTURED_PROMPT"
```
Optionally seed a real commit on `feat/squash-surface-test` before invoking and grep for its subject in the prompt, to prove the `git log` call actually ran against `origin/main..$HYG_BRANCH`.

### [domain: tests] [section: B] [severity: low]

**File**: `kit/scripts/adversarial-review.sh:319` / `kit/tests/util-adversarial-review-narrowing.bats`
**What**: The squash branch's `HYG_BRANCH="${DEVSHOP_HYGIENE_BRANCH:-$(git branch --show-current ...)}"` fallback is not directly exercised by any test. All four added tests set `DEVSHOP_HYGIENE_BRANCH` explicitly, so the fallback path is dead from a coverage standpoint — a regression that breaks the fallback (e.g., a future detached-HEAD invocation by a new caller) would not be caught.
**Why**: Phase 0.4.5 always sets `DEVSHOP_HYGIENE_BRANCH=$BRANCH` explicitly in the canonical caller, so the fallback is defensive against future callers. If a future caller (e.g., a new skill or operator-side script) invokes the squash surface without setting `DEVSHOP_HYGIENE_BRANCH` from a detached-HEAD state, `git branch --show-current` returns empty and the `git log --oneline "origin/main..$HYG_BRANCH"` expansion produces `origin/main..` which silently lists every commit on every branch — the reviewer's constituent-commits context becomes useless. No test catches this.
**Fix**: add one test that omits `DEVSHOP_HYGIENE_BRANCH`, sets `DEVSHOP_HYGIENE_MESSAGE_FILE`, runs from a checked-out feature branch, and asserts the prompt still names the current branch. Or document the fallback as caller-supplied-required and either remove the fallback or fail-fast on empty `HYG_BRANCH`.

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/util-adversarial-review-narrowing.bats` (new squash tests)
**What**: All four new tests observe the **PASS** path (mocked `claude` returns PASS). The script's behavior when the reviewer returns **FAIL** (non-zero exit) is exercised in Phase 0.4.5's caller — `HYGIENE_OUTPUT=$(... 2>&1)` captures FAIL output and `HYGIENE_VERDICT=FAIL` is set — but the squash-surface bats tests don't drive a FAIL-returning mock to verify (a) the FAIL line carries the reviewer's diagnostic, (b) the script preserves the non-zero exit, (c) stderr/stdout merge correctly for the caller's `2>&1` capture.
**Why**: A future refactor (e.g., adding a `set -e` guard or restructuring the exit path) could silently change how FAILs propagate. The Phase 0.5 FAIL framing depends on `HYGIENE_OUTPUT` containing the reviewer's verbatim message — if the script swallows stderr or normalizes the exit code to zero, the operator sees `FAIL` framing with empty diagnostic.
**Fix**: add one test using a `claude` stub that prints `FAIL: <reason>` to stdout and exits non-zero. Assert (1) the bats run captures `FAIL` text in `$output`, (2) `$status` is non-zero, and (3) the captured prompt is still written (i.e., the FAIL path didn't short-circuit before invoking claude). Test pattern:
```bash
cat > "$MOCK_BIN/claude" <<EOF
#!/bin/bash
cat > "$CAPTURED_PROMPT"
echo "FAIL: subject is mechanism-led (mentions 'Tier B')"
exit 1
EOF
```

### Other quality dimensions reviewed — no findings

- **Weak assertions**: All grep targets are concrete strings (`"Devshop squash commit"`, `"SKIP rule (c) Body"`, `"Hygiene-Override:"`) — none use `toBeTruthy`-equivalents like bare `[ -n "$output" ]`.
- **Skipped tests / `.only`**: None in the diff.
- **Implementation-detail coupling**: SKILL.md tests are content-validation grep tests; the file's own preamble documents this as the intentional design ("Behavior tests … are out of scope; this proves the prompt reflects the contract"). Acceptable.
- **Boundary conditions on the guard**: Missing-file AND empty-string both covered (test #2 + #3).
- **Mocking concerns**: Happy-path test stubs `gh` defensively even though the squash path shouldn't reach it; comment acknowledges this (`"gh must not be reached on the squash path; stub it anyway"`). Minor — no assertion verifies gh was un-called, but the regression-guard test covers the path-divergence directly.
- **Shape-only assertions / DOM pairing / WebKit hydration / `routeWebSocket` / Zod / Wrapper lifecycle**: N/A — devshop-side bats tests with no DOM, no Playwright, no API wrappers.
- **Test isolation**: Each test creates its own branch (`feat/squash-surface-test`, `feat/squash-surface-missing-file`, `feat/squash-surface-empty-env`, `feature/pr-surface-default`). Good.

---

## Section C — Bypass trailer audit

Harvest: `git log --format='%B' origin/main..HEAD | grep '^Tests-Coverage-Bypass:'` → no matches. (The `1 coverage trailers` hit in the conventions-doc edit is the docs prose mentioning the trailer name, not a real trailer.)

Zero rows. No findings.

---

## Summary

`high=0 medium=0 low=3`

All three findings are low-severity defensive-coverage gaps in a behaviorally well-covered diff. No blockers to merge.
