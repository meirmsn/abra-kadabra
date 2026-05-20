<!-- generated-by: manual (devshop change, no /ak-build pipeline) -->
<!-- feature: fault-injected-qa-gate -->
<!-- date: 2026-05-20 -->

# Spec: fault-injected-qa-gate (devshop)

**Sources:**

- `kit/TODOS.md § /ak-pre-ship Gate 9 (/qa) doesn't run fault-injected scenarios` — problem statement, lalista PR #49 incident, shape proposal, edit targets
- `PLAN.md` row #76 (`fault-injected-qa-gate`) — sizing (~2 hr), Lev 4.5
- `kit/docs/guide/latency-feedback.md` (lines 380-402, 596) — Tier A2 marker (`useOptimisticMutation({ failureMode: 'banner' })`), `## Decisions § Surface mapping` table format, `apps/web/e2e/fault-injected/` enforcement point
- `.claude/skills/devshop/pre-ship/SKILL.md § Gate 9 /qa` (lines 753-865) — Gate 9 contract, Core-user-story sub-step pattern to mirror, outcome semantics
- `kit/scripts/preship/verify-story.sh` — closest-shape reference for a sub-step helper that detects-then-asserts and emits a parseable outcome line
- `kit/tests/preship-verify-story.bats` — bats pattern for sub-step helpers

Add a fault-injection sub-step to Gate 9: for every Tier A2 surface
declared in the spec's `## Surface mapping` table, force the targeted
network call to fail (`page.route().abort()`) and assert the failure
banner renders with clickable Retry + Undo affordances (no overlay
intercept, no z-index regression). Catches the class of bug shipped by
lalista PR #49 — `AddItemSheet` overlay intercepted the Undo button
under banner state, invisible to happy-path `/qa`.

---

## Decisions

### D1: Detection strategy — spec table primary, heuristic grep fallback

**Decision:** Two-tier detection. Primary: parse spec's `## Surface
mapping` table (per `latency-feedback.md` format) for rows where
`Tier == A2`. Fallback: grep diff (or src tree if no diff) for
`useOptimisticMutation` calls with `failureMode: 'banner'`. If primary
returns rows, fallback is suppressed (spec is authoritative).

**Rationale:** The framework guide already mandates the surface mapping
table in `## Decisions`. Specs that follow the convention get
deterministic detection. Specs that skip the mapping (legacy or
non-compliant) still get coverage via grep so the gate has a wide
safety net. Listed as acceptable v0 in the TODO row.

### D2: Harness convention — `apps/web/e2e/fault-injected/<slug>.spec.ts`

**Decision:** Each detected A2 surface expects a Playwright spec at
`apps/web/e2e/fault-injected/<slug>.spec.ts`. Slug is filesystem-safe
form of the surface name (first column of the spec mapping table; for
grep fallback, derived from the call-site file path + nearest exported
identifier).

**Rationale:** Single, predictable lookup path that keeps fault-injection
specs grouped (one directory to glance at — distinct from the flat
per-feature e2e files like `template/apps/web/e2e/sign-up.spec.ts` /
`forgot-password.spec.ts`, which are happy-path coverage and don't share
the abort-then-assert shape). Missing spec → `blocked` with explicit slug
list — recipe in SKILL.md amendment tells the author what to write.

### D3: Outcome contract — sub-step emits `pass | blocked | findings`

**Decision:** This is a Gate 9 **sub-step**, not Gate 9 itself. When
detection finds zero Tier A2 surfaces, it emits `pass (no Tier A2
surfaces in scope)` — a deterministic scope-exempt outcome that rolls
up cleanly to Gate 9. When A2 surfaces ARE detected, sub-step outcome
rolls up into Gate 9 as follows:

| Sub-step result                   | Gate 9 effect                                                        |
| --------------------------------- | -------------------------------------------------------------------- |
| `pass (no Tier A2 surfaces in scope)` | No effect — parent Gate 9 outcome stands                         |
| `blocked (missing harness: …)`    | Gate 9 escalates to `blocked` with the recipe                        |
| `pass`                            | Gate 9 outcome unchanged (still subject to happy-path walk + story)  |
| `findings (N)`                    | Gate 9 outcome at least `findings` (N added to any existing count)   |

**Rationale:** Mirrors the Core-user-story sub-step (`verify-story.sh`)
shape — additive contract to the parent gate, not a replacement. The
scope-exempt case emits `pass (no Tier A2 surfaces in scope)` rather
than `n/a` to align with the convention forbidding `n/a` on LLM-mediated
gates (`pre-ship/SKILL.md § n/a is not legal for LLM-mediated gates`).
The `pass` is honest here because detection is deterministic (spec-table
parse + grep) — not operator prose — so it doesn't have the failure mode
the convention was banning.

### D4: No bypass flag

**Decision:** No `devshop.faultInjectionSkipReason` or equivalent
bypass. If a Tier A2 surface is in the diff with no harness, the
sub-step emits `blocked` and Gate 9 escalates accordingly.

**Rationale:** Sibling bypass flags (`localTestSkipReason`,
`advisorBypassReason`) exist for gates with infrastructure-shaped
reasons to skip (Docker unavailable, advisor lint genuinely
intentional). Fault-injection doesn't have that shape — either the
harness exists (`pass` / `findings`) or it doesn't (`blocked`, write
it). A bypass for "we know the gap, shipping anyway" undercuts the
gate; the right channel for that case is a TODOS row + a fix PR, not
a per-commit flag. Symmetric with the no-bypass posture of other
deterministic-presence gates (no flag for "missing test file"
either).

### D5: Playwright invocation — `pnpm exec playwright test <glob>` per surface

**Decision:** For each detected surface, invoke `pnpm exec playwright
test apps/web/e2e/fault-injected/<slug>.spec.ts --reporter=json` and
parse the JSON for `status: passed | failed | timedOut`. Aggregate
across surfaces. Per-failure trace path lands in
`specs/<feature>/gates/fault-injected-<slug>.json`.

**Rationale:** Uses existing Playwright infra (no new test runner).
JSON reporter is structured enough to parse failure counts + per-test
failures without scraping stdout. Per-surface artifact file lets
`review.md § Gate 9` cite specific traces.

### D6: Reach — devshop kit script, not template; convention is template-side

**Decision:** Script lives in `/devshop/kit/scripts/preship/` (devshop
infrastructure). The Playwright **convention** (where to put
fault-injection specs, what hook pattern triggers them) is documented
in `kit/docs/guide/latency-feedback.md` — which is devshop-side too,
but projects consume it through pre-ship invocation.

The script does NOT ship a template spec at `template/apps/web/e2e/`
in v0; the SKILL.md amendment carries the recipe inline (15-line spec
pattern). Promoting to template baseline is deferred until at least
two projects have shipped fault-injection specs and the recipe is
proven stable.

**Rationale:** Avoids template churn until the pattern is dogfooded.
Keeps v0 scope at "make the gate exist + invocable" rather than
"ship the recipe template".

---

## In scope

- `kit/scripts/preship/fault-injected-qa.sh` with subcommands:
  - `detect-surfaces --spec <path> [--root <dir>] [--diff-range <range>]`
  - `verify-harness --slugs <s1,s2,...> --root <dir>`
  - `run --feature <name> --spec <path> [--root <dir>] [--diff-range <range>]`
- `.claude/skills/devshop/pre-ship/SKILL.md` — Gate 9 amendment block
  inserted after the Core-user-story section, before User-state matrix.
  Includes outcome table, detection summary, and inline
  fault-injection spec recipe.
- `kit/tests/preship-fault-injected-qa.bats` — bats coverage for
  detection (spec-table + grep fallback), harness verification, run
  orchestration (scope-exempt-pass path, blocked path).
- `kit/docs/guide/latency-feedback.md` — rewrite lines 402 + 596 from
  conditional ("per kit/TODOS.md § fault-injected-qa-gate") to
  imperative present-tense pointing at the shipped script.
- `kit/TODOS.md` — delete the `fault-injected-qa-gate` row (lines
  441-453).
- `PLAN.md` — delete row #76 (`fault-injected-qa-gate`).

## Out of scope

- Template-shipped example fault-injection spec (D6 — deferred until
  dogfooded across 2+ projects).
- Project-side test harness changes (lalista, etc.) — those happen
  when the first project pre-ships under the new gate; the script
  itself is opt-in via spec table or call-site presence.

## Files to create / modify

| Path                                                          | Action |
| ------------------------------------------------------------- | ------ |
| `kit/scripts/preship/fault-injected-qa.sh`                    | new    |
| `.claude/skills/devshop/pre-ship/SKILL.md`                    | edit   |
| `kit/tests/preship-fault-injected-qa.bats`                    | new    |
| `kit/docs/guide/latency-feedback.md`                          | edit   |
| `kit/TODOS.md`                                                | edit (delete row) |
| `PLAN.md`                                                     | edit (delete row) |

## Tests

bats suite covers:

- `detect-surfaces`: spec-table primary returns A2 rows; missing table
  falls back to grep; both empty → exits with `n/a` line; mixed
  table-with-non-A2 returns empty (suppresses grep)
- `verify-harness`: missing spec files → exit non-zero with comma
  list; all present → exit 0
- `run`: orchestrates detect + verify-harness + emits final outcome
  line; smoke-tests the scope-exempt `pass` and `blocked` paths (no
  Playwright invocation needed — those paths short-circuit before
  runner spawn).
- `run`: `pass` and `findings (N)` outcomes covered via the
  `PLAYWRIGHT_BIN` env-var stub — `PLAYWRIGHT_BIN=/bin/true` for the
  pass path, `PLAYWRIGHT_BIN=/bin/false` for the findings path. No
  headed Chromium needed. Per-surface JSON output + outcome
  aggregation are exercised end-to-end via the stub.

A full Playwright run with real `useOptimisticMutation` surfaces (live
banner rendering, click-trial actionability) is still deferred to first
live project use — the stub covers the script's orchestration code; it
doesn't cover the harness recipe in SKILL.md itself.

## Task order

1. Write `fault-injected-qa.sh` (detect-surfaces + verify-harness + run).
2. Write `preship-fault-injected-qa.bats`.
3. Run bats locally — fix any drift.
4. Amend `pre-ship/SKILL.md` Gate 9 with the sub-step block.
5. Rewrite `latency-feedback.md` cross-refs.
6. Delete TODOS row + PLAN row.
7. Commit on the worktree with `-c devshop.docsReviewed="..."`.

## Acceptance

- `bash kit/scripts/preship/fault-injected-qa.sh detect-surfaces
  --spec specs/fault-injected-qa-gate/spec.md` → exits 0 with
  `pass (no Tier A2 surfaces in scope)` line (this spec declares no A2 surfaces).
- A synthetic spec containing a `## Surface mapping` table with one
  A2 row → `detect-surfaces` emits the slug.
- A synthetic A2 detection with no matching harness file →
  `verify-harness` exits non-zero with the slug in the message.
- `pnpm exec bats kit/tests/preship-fault-injected-qa.bats` → all
  tests pass.
