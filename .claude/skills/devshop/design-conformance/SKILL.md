---
name: ak-design-conformance
version: 1.0.0
description: |
  Treat DESIGN.md as a contract, not a style guide. Extracts normative claims
  (explicit tokens, canonical copy examples, component contracts, imperative
  rules), then verifies each against the implementation — grep for code-level
  claims, LLM-judge for copy claims, finding rejected otherwise.
  Covers axes /design-review (gstack) does NOT: voice/copy doctrine drift,
  explicit-value conformance, canonical-example matching. Complementary, not
  redundant — they check different things.
  Invoked as Gate `design-conformance` (ak) inside /ak-pre-ship, between
  `design-review` and `qa`. Emits `n/a` when DESIGN.md is absent.
  Use when asked to "run design conformance" or "check DESIGN.md compliance".
  (devshop)
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - AskUserQuestion
---

# Design Conformance

Treats DESIGN.md as a contract. Verifies that normative claims — explicit
token values, canonical copy examples, imperative component rules, motion
scale — are actually honored by the implementation.

`/design-review` (gstack) already covers visual hierarchy, typography
consistency, color harmony, spacing rhythm, interaction states, and AI-slop
patterns. This skill covers the orthogonal axes `/design-review` skips:

| Axis                                                     | `/design-review` | `/ak-design-conformance` |
| -------------------------------------------------------- | ---------------- | ------------------------ |
| Visual hierarchy / spacing / color                       | ✅               | —                        |
| AI-slop pattern detection                                | ✅               | —                        |
| **Voice / canonical copy example matching**              | ❌               | ✅                       |
| **Explicit token values (e.g. "bg is `#FDFAF6`")**       | —                | ✅                       |
| **Component contract claims (e.g. "Button min-h 44px")** | ❌               | ✅                       |
| **Motion-scale adherence (named durations)**             | ❌               | ✅                       |
| **Imperative "must / should / always / never" rules**    | ❌               | ✅                       |

## When it runs

Invoked by `/ak-pre-ship` as Gate `design-conformance` (ak). Scope detection:

- **`n/a`** — project has no `DESIGN.md` at repo root. Skill emits no finding;
  pipeline advances.
- **Runs** — `DESIGN.md` exists. Regardless of whether the PR touches UI —
  a backend refactor can still contradict a DESIGN.md claim (e.g. an edge-
  function error message that violates the voice doctrine).

## How it works

The skill delegates the heavy lifting to `kit/scripts/preship/design-conformance.sh`
so the mechanics are testable via bats without an LLM. The skill is the
contract + orchestration layer.

### Step 1 — Extract normative claims from DESIGN.md

Spawn a tightly-prompted LLM extraction against DESIGN.md. The prompt is
strict — it rejects aspirational prose and only extracts claims a reviewer
could objectively judge as violated:

- Explicit values (e.g. "background is `#FDFAF6`", "min touch target 44px")
- Canonical examples (e.g. voice example "say leche. it handles the rest.")
- Imperative rules (use of "must" / "should" / "always" / "never")
- Component contracts (declared class names, prop values, layout rules)

Output: `specs/<feature>/design-claims.json` — array of `{id, type,
description, evidence_path, severity}` records. `severity` is weighted by
claim strength (explicit-value misses = `high`; aspirational drift = `low`).

```bash
bash kit/scripts/preship/design-conformance.sh extract-claims \
  --design DESIGN.md \
  --out   "specs/$FEATURE/design-claims.json"
```

If the claims file already exists and DESIGN.md hasn't changed since the
last run (`sha256sum -c design-claims.sha256`), reuse the cached claims —
no LLM call. Diffs to `design-claims.json` between runs require the
dismissalLog adversarial check to confirm the delta is intentional (Phase 3
scaffolding).

### Step 2 — Verify each claim against the implementation

For each claim, apply the appropriate verification strategy:

- **`explicit_value`** — `grep -r` the codebase for the exact value. Missing
  → finding. Found in the wrong place (e.g. a hex value hardcoded in a
  component that should pull from tokens) → finding.
- **`canonical_example`** — LLM-compare every user-facing string in the PR
  diff against the canonical example's voice rubric. Drift → finding.
- **`imperative_rule`** — LLM judgment; prompt contains the rule text + the
  diff + asks for "does the diff violate this rule?"
- **`component_contract`** — `grep` / static analysis for the declared prop
  / class / attribute.

```bash
bash kit/scripts/preship/design-conformance.sh verify-claims \
  --claims "specs/$FEATURE/design-claims.json" \
  --out    "specs/$FEATURE/design-conformance-report.md"
```

Severity guidance:

- `high` — explicit-value miss, imperative-rule violation, canonical
  example contradiction
- `medium` — component contract non-conformance
- `low` — aspirational drift (prompt likely over-extracted; defer unless
  reviewer promotes)

### Step 3 — Emit gate outcome + Dismissals

- **`pass`** — all claims verified; no findings surfaced.
- **`findings (N) fixed`** — findings surfaced, skill fixed what it could
  inline (code-level hex/token fixes), committed, re-verified.
- **`findings (N) pending`** — findings surfaced that need human judgment
  (voice/copy rewrites).
- **`n/a`** — no DESIGN.md.

`review.md § Gate design-conformance` MUST include a `## Dismissals`
section per the Phase 3 contract (default body `None`; bulleted list
with per-bullet `rationale:` if the skill chose to dismiss findings).
Adversarial review runs only on non-`None` bodies.

## Entry point

```bash
bash kit/scripts/preship/design-conformance.sh run \
  --feature "$FEATURE" \
  --design  DESIGN.md
```

`run` orchestrates extract → verify → gate outcome. Invoked by pre-ship
with `$FEATURE` derived from the current branch.

## Forward-compatibility

- Phase 4 (Finding Router — deferred) extends `rationale:` dismissals with
  `disposition:`. This skill's Dismissals section uses `rationale:` today,
  which extends naturally.
- If extraction noise proves too high in practice, the escape hatch is to
  tune the extraction prompt in `preship-design-conformance.sh` (not to
  add markers in project DESIGN.md files — project authors shouldn't
  burden their design doctrine with framework-specific formatting).

## Tests

`kit/tests/preship-design-conformance.bats` — covers claim extraction (mocked
LLM), verification strategies per claim type, `n/a` when DESIGN.md absent,
finding emission with severity weighting, Dismissals section shape.
