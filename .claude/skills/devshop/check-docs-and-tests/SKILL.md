---
name: ak-check-docs-and-tests
version: 1.0.0
description: |
  Audit-time docs + tests review. Computes commit range from the latest
  ## Audit N section in specs/<feature>/review.md, invokes /ak-docs-review
  and /ak-tests-review in sequence, appends a new ## Audit N section with
  structured findings.
  Two canonical audit moments: pre-polish (Gate 5 inside /ak-pre-ship) and
  post-polish (Phase 5.8 inside /ak-build). Manual operator invocation also
  supported. Idempotent on unchanged HEAD.
  Use when asked to "audit docs and tests", "run docs+tests audit", or as
  part of /ak-pre-ship Gate 5 / /ak-build Phase 5.8. (devshop)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
  - AskUserQuestion
---

# Check Docs and Tests

Audit-time orchestrator that runs both Layer 2 reviews (docs and tests) over a
single commit range and records the findings in `specs/<feature>/review.md`.
This is the operator's single entry point for the audit moment — it computes
the range from the latest `## Audit N` section in `review.md`, invokes
`/ak-docs-review` and `/ak-tests-review` in sequence, and appends a new
`## Audit N` section with structured findings + bypass-trailer review.

Adversarial Layer 2 fires here, not per-commit. Per-commit fires only Layer 1
(deterministic file-existence math) — Sonnet judgment is concentrated at named
audit moments where docs and tests have actually been written, producing
higher-signal findings at lower cost. See `/devshop/kit/ROADMAP.md § Move
adversarial Layer 2 reviews from per-commit to audit-time` for the full
rationale.

## When to invoke

Three triggers:

- **Inside `/ak-pre-ship` Gate 5** (audit-1, pre-polish): work is done, before
  polish/review begins. This is when docs and tests get written for the
  change. Findings written to `## Audit 1`.
- **Inside `/ak-build` Phase 5.8** (audit-2, post-polish, after PR-B lands):
  polish iterations on top of pre-ship. Audits the diff between Audit 1 and
  HEAD; anything that changed must be reflected in updated docs/tests.
  Findings written to `## Audit 2`.
- **Manual operator** (any time): same mechanic. Idempotent on unchanged HEAD;
  re-running before HEAD changes is a no-op.

## Inputs

- (none required) — defaults to feature-dir auto-detection.
- `--feature-dir <path>` — explicit override. Used when the parent skill
  (`/ak-build`, `/ak-pre-ship`) already knows the feature dir.
- `--range <SHA>..HEAD` — explicit range override. Rare — usually
  auto-computed from the latest `## Audit N` section.
- `--label <pre-polish | post-polish | manual>` — caller-supplied subhead
  text for the new section. Defaults to `manual` if absent.

## Behavior

### Step 1: Resolve feature dir

In order of preference:

1. If invoked from `/ak-build` or `/ak-pre-ship`, the parent passes
   `--feature-dir` as an arg. Use it.
2. Else: derive from current branch name. Strip the type prefix
   (`feat/`, `fix/`, `chore/`, etc.) and map to `specs/<name>/`.
   Example: `feat/auth-improvements` → `specs/auth-improvements/`.
3. Else: use `AskUserQuestion` to ask the operator for the feature dir.
4. If the resolved feature dir doesn't exist: scaffold an empty
   `specs/<name>/review.md` stub (just the title `# Review — <name>`) so
   the appender step has a target to append to.
5. If the current branch is `main`: error out and exit non-zero with
   "audit is feature-level; check out the feature branch first." Audits
   never run on main.

### Step 2: Compute range

Read the latest `## Audit N:` section header from `review.md` and use its
`<!-- audited-at: <SHA> -->` HTML-comment marker to derive the range:

- If `review.md` has no `## Audit N:` sections → range = `origin/main..HEAD`,
  `audit_n = 1`.
- Else → take the latest section's `<SHA>` → range = `<SHA>..HEAD`,
  `audit_n = N + 1`.
- If `<SHA>` doesn't exist in the current commit graph (history rewritten
  by rebase) → fall back to `origin/main..HEAD`, and add an HTML-comment
  note to the new section: `<!-- rebased: prior audit at <missing-SHA>
invalidated -->`.
- If `<SHA>` == HEAD (already audited) → no-op. Print
  `✓ already audited at <SHA>`. Exit 0. Do not invoke sub-skills, do not
  append a new section.

Parser one-liners (use these — they're the parse contract):

```bash
LATEST_SHA=$(grep -oP '(?<=<!-- audited-at: )[a-f0-9]+' "$FEATURE_DIR/review.md" | tail -1)
AUDIT_N=$(grep -cP '^## Audit \d+' "$FEATURE_DIR/review.md")
AUDIT_N=$((AUDIT_N + 1))
HEAD_SHA=$(git rev-parse HEAD)
```

If `--range` was passed explicitly, skip auto-computation and use it
verbatim. If `--range` was passed but a no-op idempotence check still
applies (latest audit's SHA == HEAD), respect the no-op anyway — explicit
range doesn't override the idempotence guard.

### Step 3: Invoke sub-skills

Sequential, not parallel. Order matters: docs first, tests second — keeps
log output and the appended findings in a stable order.

1. Invoke `/ak-docs-review` via the Skill tool. Pass `--range $RANGE` and
   `--feature-dir $FEATURE_DIR`. The sub-skill writes structured findings
   to `/tmp/docs-review-findings.md`.
2. Invoke `/ak-tests-review` via the Skill tool with the same args. The
   sub-skill writes its findings to `/tmp/tests-review-findings.md`.

Both sub-skills are repo-aware via `$GIT_ROOT` (`/devshop` vs
`/workspace`); the orchestrator does not detect repo — it delegates that
to the sub-skills.

If either sub-skill exits non-zero from a setup error (not a finding —
a real error like "range invalid" or "no diff"), abort the audit with
that error printed. Do not append a partial `## Audit N` section.

### Step 4: Append `## Audit N` section

Read both tempfiles and append a new section to `review.md` using the
template in § Audit section format spec below. Append (don't replace) —
prior `## Audit N` sections stay as historical record.

The "pre-polish" / "post-polish" / "manual" subhead text comes from
`--label`. Conventionally:

- `/ak-pre-ship` Gate 5 → `--label pre-polish`
- `/ak-build` Phase 5.8 → `--label post-polish`
- Operator invocation → `--label manual` (default if `--label` absent)

Audit date is today's date (`date +%Y-%m-%d`).

### Step 5: Halt-or-continue

Inspect the totals across both domains:

- **Any high-severity findings** → print all high-severity findings to
  stdout, exit non-zero. The caller (`/ak-pre-ship` Gate 5, `/ak-build`
  Phase 5.8, or operator) decides next steps.
- **Only medium / low findings** → exit 0. Findings are recorded in
  `## Audit N`; no halt.
- **0/0/0** → exit 0 with `Audit N: clean — no findings.` printed.

The orchestrator does NOT auto-fix findings. Sub-skills don't either.

### Step 6: Idempotence

Re-running the skill before HEAD changes is a no-op. Specifically: Step 2
checks whether the latest `## Audit N` section's `<!-- audited-at -->`
SHA equals HEAD; if so, print `✓ already audited at <SHA>` and exit 0
WITHOUT invoking sub-skills or appending a section.

This is the same idempotence shape `/ak-build` Phase 5.8.5 uses today on
`test-review-followup.md`; the model is preserved on the new single-file
`review.md` `## Audit N` parser.

## Audit section format spec

This is the exact template appended to `review.md` in Step 4. It IS the
parse contract — Step 2 of subsequent runs greps the HTML-comment markers
to derive the next range.

```markdown
## Audit N: <pre-polish | post-polish | manual> (YYYY-MM-DD)

<!-- audited-at: <HEAD_SHA> -->
<!-- range: <RANGE> -->

findings: high=<H> medium=<M> low=<L>

### Docs findings

- [<sev>] <file>:<line> — <one-line summary>

### Tests findings

- [<sev>] <file>:<line> — <one-line summary>

### Bypass trailer audit

- <commit SHA> Docs-Coverage-Bypass: "<reason>" — VERIFIED|DEFER|ESCALATE
- <commit SHA> Tests-Coverage-Bypass: "<reason>" — VERIFIED|DEFER|ESCALATE
```

Notes on the template:

- `N` is the integer from Step 2's `AUDIT_N`.
- The HTML-comment markers (`<!-- audited-at: ... -->`,
  `<!-- range: ... -->`) render invisibly in any Markdown view but are
  unambiguous and greppable. Do not "improve" them into visible
  Markdown — they're load-bearing for the parser.
- If a sub-skill emitted zero findings in its domain, the corresponding
  `### Docs findings` or `### Tests findings` subsection still appears
  with a single line: `- (none)`.
- If no bypass trailers were harvested in the range, the
  `### Bypass trailer audit` subsection still appears with `- (none)`.
- If Step 2 detected a missing prior SHA (rebase), insert
  `<!-- rebased: prior audit at <missing-SHA> invalidated -->` between
  the `<!-- range: ... -->` line and the findings count line.

## Cross-skill invariants

- The orchestrator is repo-aware via `$GIT_ROOT` (`/devshop` vs
  `/workspace`) and **delegates that detection to the sub-skills** — it
  does not branch on repo itself.
- Both sub-skills run **sequentially** (not parallel) — keeps logs
  readable and the appended findings ordered docs-then-tests.
- The HTML-comment markers `<!-- audited-at: ... -->` and
  `<!-- range: ... -->` are the parse contract. They must render
  invisibly in Markdown views and stay greppable by the orchestrator on
  subsequent runs.
- The orchestrator never reads or writes individual finding bodies — it
  copies them through from the sub-skills' tempfiles into the section.
  Sub-skills own their finding format.

## Behavior summary

- **Idempotent**: same HEAD → same audit. Re-runs are safe.
- The orchestrator does NOT auto-fix findings. Sub-skills don't either.
- Halt only on high-severity. Medium and low surface but don't block.
- Caller decides what happens after halt — this skill exits and reports.
