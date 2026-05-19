---
name: ak-check-docs-and-tests
version: 2.0.0
description: |
  Audit-time docs + tests review. Computes commit range from the latest
  ## Audit N section in specs/<feature>/review.md, dispatches /ak-docs-review
  and /ak-tests-review as parallel Agent sub-invocations with per-file
  sinks under specs/<feature>/gates/, concatenates into a new ## Audit N
  section with structured findings.
  Two canonical audit moments: pre-polish (Gate 5 inside /ak-pre-ship) and
  post-polish (Phase 5.8 inside /ak-build). Manual operator invocation also
  supported. Idempotent on unchanged HEAD.
  Use when asked to "audit docs and tests", "run docs+tests audit", or as
  part of /ak-pre-ship Gate 5 / /ak-build Phase 5.8. (devshop)
allowed-tools:
  - Agent
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
the range from the latest `## Audit N` section in `review.md`, dispatches
`/ak-docs-review` and `/ak-tests-review` as parallel `Agent` calls with
per-file sinks under `specs/<feature>/gates/audit-N-{docs,tests}.md`, and
concatenates them into a new `## Audit N` section with structured findings +
bypass-trailer review.

Adversarial Layer 2 fires here, not per-commit. Per-commit fires only Layer 1
(deterministic file-existence math) — Sonnet judgment is concentrated at named
audit moments where docs and tests have actually been written, producing
higher-signal findings at lower cost. See `CLAUDE.md § Non-Negotiables` —
"Adversarial Layer 2 reviews fire at audit moments, not per commit" — for
the steady-state convention.

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

### Step 3: Invoke sub-skills in parallel with per-file sinks

Both sub-skills (`/ak-docs-review` and `/ak-tests-review`) are pure
read-only analysis against the same `$RANGE`. They have no ordering
dependency on each other. Dispatch them as **two parallel `Agent` tool
calls in a single tool-use turn** — each Agent invocation is a fresh
context that runs one sub-skill and writes its findings to a per-file
sink. The orchestrator concatenates the sinks into the `## Audit N`
section in Step 4.

**Per-file sinks** (the parse contract for Step 4):

- Docs findings → `$FEATURE_DIR/gates/audit-$AUDIT_N-docs.md`
- Tests findings → `$FEATURE_DIR/gates/audit-$AUDIT_N-tests.md`

Create the `gates/` directory if it doesn't exist: `mkdir -p
"$FEATURE_DIR/gates"`. The directory is checked into git alongside the
rest of `specs/<feature>/` — it carries first-class audit-trail content.

**Dispatch** — one tool-use turn, two `Agent` calls:

```
Agent {
  description: "Audit docs (Audit $AUDIT_N)",
  subagent_type: "general-purpose",
  prompt: """
    Invoke /ak-docs-review via the Skill tool with:
      --range $RANGE
      --feature-dir $FEATURE_DIR

    Capture the sub-skill's structured findings (per its § Output format).
    Write them VERBATIM to $FEATURE_DIR/gates/audit-$AUDIT_N-docs.md as
    your final action before returning.

    Return a one-line summary: `high=H medium=M low=L`.
  """
}

Agent {
  description: "Audit tests (Audit $AUDIT_N)",
  subagent_type: "general-purpose",
  prompt: """
    Invoke /ak-tests-review via the Skill tool with:
      --range $RANGE
      --feature-dir $FEATURE_DIR

    Capture the sub-skill's structured findings (per its § Output format).
    Write them VERBATIM to $FEATURE_DIR/gates/audit-$AUDIT_N-tests.md as
    your final action before returning.

    Return a one-line summary: `high=H medium=M low=L`.
  """
}
```

Why per-file sinks instead of agent-return values: the agent's return
value lives only in the orchestrator's context. If a parallel pass had
both agents writing to the same `review.md` file directly, the second
writer would clobber the first. Per-file sinks make each agent's write
target unambiguous and let the orchestrator concatenate atomically in
Step 4. The pattern mirrors `/ak-build § Phase 3`'s per-gate sinks
(`specs/<feature>/gates/<gate-name>.md`) — same convention.

Both sub-skills are repo-aware via `$GIT_ROOT` (`/devshop` vs
`/workspace`); the orchestrator does not detect repo — it delegates that
to the sub-skills.

If either Agent invocation returns an error indicating the sub-skill
exited non-zero from a setup error (not a finding — a real error like
"range invalid" or "no diff"), abort the audit with that error printed.
Do not append a partial `## Audit N` section.

### Step 4: Concatenate sinks into `## Audit N` section

Read both per-file sinks (`$FEATURE_DIR/gates/audit-$AUDIT_N-docs.md` and
`$FEATURE_DIR/gates/audit-$AUDIT_N-tests.md`) and append a new section to
`review.md` using the template in § Audit section format spec below.
Append (don't replace) — prior `## Audit N` sections stay as historical
record.

The sink files stay on disk after concatenation — they're committed in
Step 5 alongside the `review.md` append, providing a durable per-domain
audit-trail (a crashed-mid-concatenate resume re-reads them rather than
re-invoking the Agent calls). Idempotence: if the sink files already
exist and HEAD hasn't moved (Step 7's idempotence guard), Step 3's
Agent dispatch is skipped — Step 4 reads existing sinks instead.

The "pre-polish" / "post-polish" / "manual" subhead text comes from
`--label`. Conventionally:

- `/ak-pre-ship` Gate 5 → `--label pre-polish`
- `/ak-build` Phase 5.8 → `--label post-polish`
- Operator invocation → `--label manual` (default if `--label` absent)

Audit date is today's date (`date +%Y-%m-%d`).

### Step 5: Commit the appended section + sinks

The audit record must land as a git commit so future runs see the
`<!-- audited-at: <SHA> -->` stamp at HEAD (Step 7's idempotence
contract depends on it) and so post-merge `git checkout main` doesn't
trip on a dirty working tree. Codified from home-os PR #10 (2026-05-13)
where the appended section sat uncommitted, blocked `gh pr merge
--delete-branch`'s local cleanup, and the operator had to discard the
audit-trail append to recover.

Procedure:

1. **Dirty-tree refusal.** Run `git status --porcelain` and inspect.
   The orchestrator may have inherited an unrelated dirty tree from
   the parent — silently capturing those changes would corrupt the
   audit commit. The only paths legal in the working tree at this
   step are `$FEATURE_DIR/review.md` (which Step 4 just appended to),
   the two `$FEATURE_DIR/gates/audit-$AUDIT_N-{docs,tests}.md` sinks
   that Step 3's Agent dispatch wrote, plus the empty-stub scaffold
   from Step 1 if it was just created.
   If `git status --porcelain` reports any other path: surface a
   `UNCOMMITTED:` line listing each foreign path, skip the commit,
   and exit 0. The caller routes the recovery (`/ak-build § Phase
5.8` halts on it; manual operators clean by hand). Do NOT
   `git stash` or `git restore` — both destroy operator work
   silently. Mirrors Phase 5.9's commit-or-no-op rule.
2. **Stage the audit file + the per-domain sinks.** `git add
   "$FEATURE_DIR/review.md" "$FEATURE_DIR/gates/audit-$AUDIT_N-docs.md"
   "$FEATURE_DIR/gates/audit-$AUDIT_N-tests.md"` — never `git add -A` /
   `git add .`. The scope of this commit is exactly three paths:
   `review.md` (the appended `## Audit N` section) plus the two
   per-domain sinks that Step 3's Agent dispatch wrote.
3. **Compose the message.** Subject:
   `docs(<feature>): Audit N (<label>) — findings: high=H medium=M low=L`
   (single line, ≤ 72 chars; truncate `<feature>` if needed to stay
   under). Body:

   ```
   Range: <RANGE>
   Stamp: <HEAD_SHA>
   ```

   No further prose — the appended `## Audit N` section in
   `review.md` is the audit-trail; the commit message only needs
   pointer metadata.

4. **Commit.** `git commit -F /tmp/audit-commit-message.txt`. Do not
   pass `--no-verify`; the file-pairing pre-commit hooks (Layer 1)
   have no surface match for `specs/<feature>/review.md` so they
   carve out automatically, and committing under the gauntlet keeps
   audit commits indistinguishable from any other commit in
   pre-commit telemetry.
5. **Print the SHA.** Echo `✓ audit committed at <new HEAD SHA>` so
   the caller and tracker can record the bump.

If the commit fails (pre-commit hook rejects, network glitch, etc.):
print the hook output verbatim, leave the staged file staged, and
exit non-zero. The caller surfaces the failure; the operator either
fixes the underlying issue and re-runs, or discards (`git restore
--staged`). Do NOT loop or retry — a failure here means something
the orchestrator can't reason about happened, and silent retry would
mask the signal.

### Step 6: Halt-or-continue

Inspect the totals across both domains:

- **Any high-severity findings** → print all high-severity findings to
  stdout, exit non-zero. The caller (`/ak-pre-ship` Gate 5, `/ak-build`
  Phase 5.8, or operator) decides next steps.
- **Only medium / low findings** → exit 0. Findings are recorded in
  `## Audit N`; no halt.
- **0/0/0** → exit 0 with `Audit N: clean — no findings.` printed.

The orchestrator does NOT auto-fix findings. Sub-skills don't either.

### Step 7: Idempotence

Re-running the skill before HEAD changes is a no-op. Specifically: Step 2
checks whether the latest `## Audit N` section's `<!-- audited-at -->`
SHA equals HEAD; if so, print `✓ already audited at <SHA>` and exit 0
WITHOUT invoking sub-skills, appending a section, or committing.

Because Step 5 commits the section under the same HEAD it stamped,
idempotence holds tightly: the freshly-committed `audited-at: <SHA>`
equals the new HEAD. If Step 5 was skipped (dirty-tree refusal), the
stamp points at a SHA _behind_ HEAD on disk — the next run treats
that as a fresh range and re-audits from the prior stamp. This is
the intended recovery path.

Same idempotence shape as `/ak-build` Phase 5.8.5: read the latest
`## Audit N` section's `<!-- audited-at -->` stamp from `review.md`
(single-file model).

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
- Both sub-skills run **in parallel** as two `Agent` tool calls in one
  tool-use turn. Each writes its findings to a per-file sink under
  `$FEATURE_DIR/gates/audit-$AUDIT_N-{docs,tests}.md`; the orchestrator
  concatenates the sinks into `## Audit N § Docs findings` and `##
  Audit N § Tests findings` in stable docs-then-tests order during
  Step 4. Sub-skill ordering is enforced by the concatenation step,
  not by sequential dispatch.
- The HTML-comment markers `<!-- audited-at: ... -->` and
  `<!-- range: ... -->` are the parse contract. They must render
  invisibly in Markdown views and stay greppable by the orchestrator on
  subsequent runs.
- The orchestrator never reads or writes individual finding bodies — it
  copies them through from the per-file sinks into the section. Sub-skills
  own their finding format.

## Behavior summary

- **Idempotent**: same HEAD → same audit. Re-runs are safe.
- The orchestrator does NOT auto-fix findings. Sub-skills don't either.
- The orchestrator DOES commit the appended `## Audit N` section
  (Step 5). The audit-trail is a first-class repo artifact.
- Dirty-tree refusal in Step 5: if the working tree contains anything
  beyond the audit file, skip the commit and emit `UNCOMMITTED:` so
  the caller routes recovery — never `git stash` or `git restore`.
- Halt only on high-severity. Medium and low surface but don't block.
- Caller decides what happens after halt — this skill exits and reports.
