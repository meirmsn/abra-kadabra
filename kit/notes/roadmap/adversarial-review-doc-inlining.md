# Adversarial Reviewer — Doc-Inlining Architecture

**Status:** RFC. **Authored:** 2026-05-01. **Successor to:** ad-hoc doc-inlining choices accumulated in `kit/scripts/adversarial-review.sh` between commits `c750698`, `953e9a1`, and `3694dc3`.

**Audience:** anyone modifying the adversarial reviewer's prompt or context-build, or anyone designing the docs hierarchy that the reviewer judges against. Self-contained — does not assume prior conversation context.

---

## TL;DR

Today the adversarial reviewer's commit-time doc check (`docsReviewed` for devshop, `docsFreshnessProject` for project) inlines doc bodies in an ad-hoc mix: full bodies for some, `head -N` truncation for others, headers-only for the rest, plus cross-repo inlining of project CLAUDE.md into the devshop reviewer for no clear reason. The recent rule 4(e) addition (commit `953e9a1`) pushed Sonnet's response past the 90s per-attempt timeout, which exposed the asymmetric design. This RFC proposes a unified model: **two reviewers (one structure), top-level docs always FULL, deeper docs as flat-catalog `## ` headers, selective expansion via routing for commit-time, tool-use grep for pre-ship.** Sharpen rule 4(a) so the bypass author names _specific edits_ per affected doc and the reviewer verifies via grep-on-diff. Drop cross-repo inlining and `head -N` arbitrary cuts. Phase 1 (low-risk tightening) is ready to execute as described in § Phase 1 below.

---

## Context — why this exists

`kit/scripts/adversarial-review.sh` runs as a sub-claude invocation from inside husky pre-commit hooks (see `kit/docs/guide/hooks.md § 2`). It evaluates bypass reasons for commit guards. For the `docsReviewed` check-type (fires when any devshop file is staged), it builds a CONTEXT block of inlined doc bodies + a static PROMPT with rules 1-13, sends to Claude, parses PASS/FAIL.

In commit `953e9a1` (2026-05-01) we added rule 4(e) (Addition drift sweep) and the `GUIDES_TO_INCLUDE` selective-inlining map. The new rule made the reviewer's reasoning load heavier — Sonnet 4.6 reliably exceeded the 90s per-attempt timeout (3 retries × 90s = ~5min cycle to "API unavailable" fallback). User had to set `DEVSHOP_ADVERSARIAL_MODEL_OVERRIDE=haiku` to land follow-up commits.

Commit `3694dc3` (2026-05-01) addressed the immediate symptom — bumped `COMMIT_TIMEOUT` from 90 to 180s, fixed a latent backtick bug in rule 13, expanded the reviewer's project-side context (added project OVERVIEW.md/ARCHITECTURE.md/per-package READMEs to the `docsFreshnessProject` case). But that didn't address the underlying inconsistency in the inlining model. This RFC does.

---

## Current state, measured (snapshot 2026-05-01)

### Doc inventory

```
/devshop                                  /workspace
─────────────────────────────────         ─────────────────────────────────
CLAUDE.md            30.9 KB              CLAUDE.md            20.9 KB     (Tier 1)
README.md             4.3 KB              README.md             3.7 KB
kit/docs/                                 OVERVIEW.md           6.1 KB     (Tier 2 — added 3694dc3)
  MODEL.md            5.7 KB              ARCHITECTURE.md      14.7 KB     (Tier 2 — added 3694dc3)
  OVERVIEW.md        17.7 KB              PLAN.md / BUILD-LOG.md / TODOS.md /
  FAQ.md             13.2 KB              METRICS.md / PRODUCT-ROADMAP.md
  CHANGELOG.md
                                          apps/web/README.md              (Tier 3 — added 3694dc3)
kit/docs/guide/                           packages/core/README.md
  architecture.md                         packages/ui/README.md
  conventions.md                          supabase/functions/README.md
  hooks.md             (the long one)
  ops.md / security.md / workflow.md
  notifications.md
  + 3 deep references (supabase-ssr-boilerplate, macos-host-setup, local-supabase-compose-isolation)
```

### What `docsReviewed` (devshop) inlines today

`adversarial-review.sh:65-122`. Mixed strategy:

| Doc                             | Inline mode        | Size                                           |
| ------------------------------- | ------------------ | ---------------------------------------------- | ---------------- |
| `kit/docs/MODEL.md`             | FULL               | 5.7 KB / ~1.4k tok                             |
| `kit/docs/OVERVIEW.md`          | FULL               | 17.7 KB / ~4.4k tok                            |
| `/devshop/CLAUDE.md`            | head 100 lines     | ~14 KB (file is 30.9 KB total — captures ~40%) |
| `/workspace/CLAUDE.md`          | head 100 lines     | ~14 KB (file is 20.9 KB — captures ~70%)       |
| `/devshop/README.md`            | head 60 lines      | ~4 KB                                          |
| `kit/docs/guide/*.md` (8 files) | `## ` headers only | ~5.5 KB                                        |
| `kit/docs/FAQ.md`               | `## ` headers only | ~0.6 KB                                        |
| Diff: `--stat` + `--cached      | head 300`          | variable                                       | ~5-15 KB typical |

Plus the `GUIDES_TO_INCLUDE` map (added in `953e9a1`) selectively expands `kit/docs/guide/{hooks,architecture,security}.md` to FULL when the staged diff matches a routing entry.

**Static PROMPT block** (rules 1-13): 12.2 KB / ~3k tokens.

**Total runtime CONTEXT (excluding diff):** ~68 KB / ~17k tokens.

**Total full prompt (with diff):** ~85-95 KB / ~20-24k tokens for a typical commit.

### What `docsFreshnessProject` (project) inlines today

`adversarial-review.sh:163-205`. Different strategy:

| Doc                          | Inline mode                 | Size                               |
| ---------------------------- | --------------------------- | ---------------------------------- |
| `/workspace/CLAUDE.md`       | head 200 lines              | full file is 20.9 KB so ~all of it |
| `/workspace/METRICS.md`      | head 200 lines              | variable                           |
| `/workspace/OVERVIEW.md`     | head 150 lines (opt-in)     | 6.1 KB total — full                |
| `/workspace/ARCHITECTURE.md` | head 150 lines (opt-in)     | 14.7 KB total — most               |
| Per-package READMEs          | head 80 lines each (opt-in) | variable                           |

Trigger fires only on specific code surfaces (new `page.tsx`, new `posthog.capture()`, etc. — see `check-docs-coverage-project.sh` for the full trigger map). Doesn't review on arbitrary devshop changes the way `docsReviewed` does for devshop.

### Asymmetries identified

1. **Cross-repo inlining is unidirectional.** `docsReviewed` (devshop reviewer) inlines `/workspace/CLAUDE.md` head-100. `docsFreshnessProject` (project reviewer) does NOT inline any devshop doc. The reverse direction was probably correct from the start (project changes don't affect devshop), but the forward direction has no clear rationale: devshop changes should land in `/devshop/CLAUDE.md` or `/devshop/template/CLAUDE.md`, never in a specific project's CLAUDE.md.

2. **`head -N` is fragile.** Sections at the bottom of long files get silently truncated. `/devshop/CLAUDE.md` § Gotchas is exactly the section a reviewer most needs and is most likely past line 100.

3. **Full-body vs headers-only is inconsistent.** MODEL.md and OVERVIEW.md (kit/docs/) are FULL. guide/\* and FAQ.md are headers-only. There's no principle behind which gets which — it's accumulated from commit-by-commit decisions.

4. **Two check-types, two structures.** `docsReviewed` reviews any devshop change broadly; `docsFreshnessProject` reviews only specific project triggers. The naming reinforces the asymmetry (`...Reviewed` vs `...Freshness`). Future maintainers face two parallel context-build paths.

5. **The reviewer's claim-verification is weak.** Rule 4(a) requires per-doc affected/not-affected, but doesn't require the bypass author to _name what specifically changed_ in each affected doc. The reviewer trusts the claim; can spot-check from the diff but isn't told to.

---

## Architecture — locked decisions

The following are decided based on the design discussion summarized in this RFC. Open questions are listed in § Open questions below.

### 1. Two reviewers, one structure

Single check-type `docsReviewed` (rename of current). Branches inside `adversarial-review.sh` based on `$GIT_ROOT`:

- `/devshop` → reads only devshop docs
- `/workspace` → reads only project docs

Same prompt rules apply to both. Same context-build code path. Only the inlined doc set differs.

(Optional: keep two distinct check-type names `docsReviewedDevshop` / `docsReviewedProject` for clarity in logs. Open question — see § Open questions.)

### 2. Always-FULL inline for top-level docs

The reviewer always gets full bodies of:

**Devshop side:**

- `/devshop/CLAUDE.md` (orientation map — `§ Where Things Happen`, `§ Gotchas` are load-bearing)
- `/devshop/kit/docs/OVERVIEW.md` (system overview)
- `/devshop/kit/docs/MODEL.md` IF kept separate (see open question 1; if folded into OVERVIEW.md, drop)

**Project side:**

- `/workspace/CLAUDE.md` (orientation map)
- `/workspace/OVERVIEW.md` (product overview)
- `/workspace/ARCHITECTURE.md` (system architecture)

These are the maps. Reviewers need them on every review. Sizes (today) total ~68 KB devshop / ~42 KB project — workable.

### 3. Always flat-catalog (`## ` headers) for the rest

For each doc in:

- Devshop: `kit/docs/guide/*.md`, `kit/docs/FAQ.md`, `kit/docs/CHANGELOG.md`
- Project: any future `guide/*` directory + per-package READMEs

Inline only `## ` (and optionally `### `) headings. Reviewer sees what exists without paying for the bodies. This is the discovery / TOC layer.

Implementation: same shape as today's `GUIDE_HEADERS` in `adversarial-review.sh:78` — `for f in <docs>; do echo "--- $(basename "$f") ---"; grep -n '^##' "$f" | head -20; done`.

### 4. Selective full-body expansion via routing

When the staged diff touches a code area whose reference doc is a deeper guide, inline that guide's full body. Generalize today's `GUIDES_TO_INCLUDE` map (`adversarial-review.sh:402-427`) to cover all docs, not just `kit/docs/guide/`.

Devshop routing examples (already implemented post-`953e9a1`):

- `kit/scripts/commit-hooks/`, `kit/hooks/`, `kit/scripts/preship/`, `template/.husky/`, `.claude/settings.json` → `guide/hooks.md` (FULL)
- `template/`, `kit/manifest.txt`, `init-devshop.sh`, `kit/scripts/sync/` → `guide/architecture.md § File lifecycle`
- `.devcontainer/`, `init-firewall.sh` → `guide/security.md` (FULL)

Project routing examples (to be authored):

- New `apps/web/app/**/page.tsx` → relevant section of `apps/web/README.md` (if exists)
- Migration changes → `ARCHITECTURE.md § Data` section
- (etc. — depends on whether project grows a `guide/` directory; see open question 2)

### 5. Top-level docs are themselves TOCs

The top-level always-FULL docs (CLAUDE.md, OVERVIEW.md, ARCHITECTURE.md) maintain explicit cross-references to deeper docs as part of their content. Example: `/devshop/kit/docs/OVERVIEW.md § What the Guide Covers` already does this — names each guide/\* doc and what it covers.

For projects, lift `/workspace/CLAUDE.md § Where Things Happen` to also link to deeper docs (e.g., `OVERVIEW.md § Auth`, `ARCHITECTURE.md § Authentication`, `apps/web/README.md § Routes`) where they exist.

This makes the reviewer's mental model: "read the top-level, decide which deeper doc covers the change, optionally consult routing-map full body or grep on demand." Reviewer with grep tool (future, pre-ship only) can navigate from there.

### 6. Drop cross-repo inlining

Devshop reviewer reads only devshop docs. Project reviewer reads only project docs.

Rationale: devshop changes should land in `/devshop/CLAUDE.md` or `/devshop/template/CLAUDE.md` (which scaffolds new projects), never in a specific project's CLAUDE.md. The current inlining of `/workspace/CLAUDE.md` head-100 into `docsReviewed` was probably "more context can't hurt" reflex; not load-bearing.

Implementation: delete the `PROJECT_CLAUDE` and `PROJECT_README` lines from the `docsReviewed` case in `adversarial-review.sh:83-84`.

### 7. Drop `head -N` truncation

Replace with one of:

- **FULL body** for top-level docs (per § 2)
- **Flat-catalog headers** for everything else (per § 3)

`head -N` is fragile (sections at the bottom get cut), arbitrary (why 100? why 200?), and gives a false sense of completeness. If a doc grows past the cap, that's a signal to split the doc (e.g., move § Gotchas to a separate file), not to truncate it silently in review.

For `/devshop/CLAUDE.md` specifically (currently 30.9 KB / ~7.7k tokens FULL): accept the cost for now. Watch for size drift; split into `CLAUDE.md` + `GOTCHAS.md` when it crosses ~50 KB.

### 8. Sharpen rule 4(a) — name specific edits, verify via grep-on-diff

Current rule 4(a):

> Per-doc enumeration: explicit affected/not-affected assessment for each of the 7 reference docs — MODEL.md, OVERVIEW.md, guide/{workflow,conventions,hooks,security,ops,architecture}.md, FAQ.md. Naming a doc generically ('checked all docs') without per-doc assessment FAILS.

(Note: "7 reference docs" lists 9 — fix in same edit.)

Sharpened rule 4(a):

> Per-doc enumeration: for each of the reference docs (devshop: CLAUDE.md, MODEL.md or Concept-folded OVERVIEW.md, OVERVIEW.md, guide/\* + FAQ.md as named in the inlined catalog; project: CLAUDE.md, OVERVIEW.md, ARCHITECTURE.md, per-package READMEs as named in the catalog), the reason MUST state either NOT-AFFECTED or AFFECTED. For each AFFECTED doc, the reason MUST name (a) the specific section the edit lives in, AND (b) the specific edit (added bullet, new row, changed sentence — the distinctive phrase that will appear in the diff). The reviewer MUST verify each named edit by searching the staged diff (grep semantic) for the cited phrase. A claim of "updated to add X" where X is not visible in the staged diff FAILS.

This is a prompt-only change. No tool-use. The diff is already in the prompt; the reviewer is just instructed to verify rather than trust.

### 9. Tool-use grep — pre-ship only, deferred

Reserved for `dismissalLog` check-type (called by pre-ship router-shim, not commit-time). Pre-ship pipeline already runs many gates serially with their own LLM calls; an extra tool-use round-trip is negligible. Equip the reviewer with a `grep <pattern> <doc-path>` tool; it can verify cross-doc claims by querying current state on disk rather than what was inlined.

Branch on `case "$CHECK_TYPE" in dismissalLog) ... ;; esac` in the model invocation. Commit-time check-types (docsReviewed, dirtyTreeReason, etc.) keep the no-tool, fast path.

This is deferred — not part of Phase 1.

### 10. Out-of-band coherence sweep — separate work, deferred

Periodic gate (e.g., weekly cron via `/schedule`) that reads all docs and asks the reviewer to flag contradictions across them. Catches silent drift between separate commits (which commit-time review can't see). Out of scope for this RFC; track as a separate roadmap item.

---

## Open questions

These are decisions that should be made before Phase 2-3 implementation but don't block Phase 1.

### 1. Does devshop's MODEL.md fold into OVERVIEW.md?

`MODEL.md` is the conceptual/philosophical doc — what the dev-shop is, why these structural choices, how it differs from a template/monorepo. `OVERVIEW.md` is the structural/system doc — workspace layout, event flow, file map.

Options:

- **(a) Fold** — add a section at the top of OVERVIEW.md. Section name: not "Model" (too jargon-overloaded — could mean data model, mental model, ML model). Better: **"Concept"** or **"What this is and why it exists"**. Lean: Concept.
- **(b) Keep separate** — MODEL.md stays as a fourth top-level devshop doc. Asymmetric (project doesn't have one) but honest — devshop is a tool whose existence needs explanation.

If folded, the always-FULL set on devshop side is CLAUDE.md + OVERVIEW.md (with Concept section embedded). If kept separate, it's CLAUDE.md + MODEL.md + OVERVIEW.md.

### 2. Does the project repo grow a `guide/` directory?

Devshop has `kit/docs/guide/` for deep references. Project doesn't. Per-package READMEs partially substitute but don't cover cross-cutting topics (e.g., "How auth works end-to-end").

Option (a): add `/workspace/guide/` as needed. Then routing maps + flat-catalog become symmetric.

Option (b): keep project deep references inline in OVERVIEW.md / ARCHITECTURE.md, expand them as needed. Smaller doc surface, harder to cross-reference granularly.

Lean: do (b) for now, add `guide/` only when ARCHITECTURE.md's growth demands it.

### 3. Doc structural templates

Rule 4(a) as sharpened (§ 8) requires the bypass author to name "the specific edit (added bullet, new row, changed sentence)". For that to be a meaningful constraint, docs need predictable structure — every guide/\* section follows "What it is / How it works / Extending" or similar.

Where do the templates live? Likely `kit/docs/guide/conventions.md § Doc Templates`. When are they authored? Before Phase 4.

### 4. Naming the unified check-type

Three options:

- **`docsReviewed`** (single check-type, branches internally on `$GIT_ROOT`). Cleanest API; logs less self-explanatory.
- **`docsReviewedDevshop` / `docsReviewedProject`** (two check-types, same code path). Logs are clearer; two entries in `get_model_for_check_type`.
- **`docsReviewed` (devshop) + `docsFreshnessProject` (project)** — current state. Inconsistent.

Lean: **option 1** (single check-type, branch internally). The branch is a 5-line `case` statement; the API surface stays minimal.

### 5. Reviewer enforcement of doc structural templates

Once doc templates exist (open question 3), should the reviewer enforce that AFFECTED-doc edits _fit the template_? I.e., a new guide/\* section must have "What it is / How it works / Extending" subsections.

Lean: yes, but as a soft check (warn, don't block) initially. Promote to hard check after a few weeks of dogfooding.

---

## Sequencing — Phases

### Phase 1: Cheap wins, no structural changes (LOW RISK — ready to execute)

Deliverables on a single PR:

1. **Drop cross-repo inlining** — delete `PROJECT_CLAUDE` and `PROJECT_README` from `adversarial-review.sh:83-84` in the `docsReviewed` case. Update the CONTEXT block at line 89-122 to remove the corresponding `=== CLAUDE.md (project) ===` and `=== README.md ===` sections.

2. **Sharpen rule 4(a)** per § 8 above. Update prompt at `adversarial-review.sh:540`. Fix the "7 reference docs" miscount while editing.

3. **Tighten the prompt per the simplifications already proposed (carries over from earlier discussion):**
   - Combine rules 1-3 into one line ("Reason must be specific, factually accurate per the context, and address actual risk. Generic placeholders fail.")
   - Tighten rule 4(e) (~150 words → ~80 words; replace exhaustive structural-unit list with shorter version, drop redundant body-enumeration second time, terse the header-only-vs-full-body paragraph)
   - Move historical-notes carve-out to a single line at end of rule 4 (currently duplicated in 4(d) and 4(e))
   - Tighten framing line ("You are a commit guard auditor. Reject bypass reasons by default.")
   - Trim rule 4(b) "Layout mentions alone..." redundancy with the right-level enumeration just above it
   - Trim rule 12's opt-in paragraph repetition

4. **Replace `head -N` for top-level docs with FULL body.** Specifically:
   - `docsReviewed`: `/devshop/CLAUDE.md` head 100 → FULL. (Accept the ~7.7k token cost; it's the orientation map.) Keep `/devshop/kit/docs/MODEL.md` and `/devshop/kit/docs/OVERVIEW.md` FULL (already are).
   - `docsFreshnessProject`: `/workspace/CLAUDE.md` head 200 → FULL. `/workspace/OVERVIEW.md` head 150 → FULL. `/workspace/ARCHITECTURE.md` head 150 → FULL. Per-package READMEs head 80 → FULL.
   - `docsReviewed`: `/devshop/README.md` head 60 → FULL (small file, no reason to truncate).

**Estimated impact:**

- Static prompt: -800 to -1000 tokens (from prompt simplifications)
- Runtime CONTEXT: net -10 to -20 KB (drop cross-repo gives ~25 KB back; FULL replaces head-N adds ~10-15 KB)
- Reviewer rigor: up (rule 4(a) sharpened, claims now verifiable)
- Latency: down (smaller prompt + simpler rules → faster Sonnet)

**Test plan:**

- Add bats cases extending `kit/tests/util-adversarial-review-guides.bats`:
  - Verify `docsReviewed` prompt no longer contains `=== CLAUDE.md (project) ===` (cross-repo inline gone)
  - Verify rule 4(a) prompt text mentions "name the specific edit" + "verify by searching the staged diff"
  - Verify FULL body inline produces `/devshop/CLAUDE.md` content past line 100 (sentinel string in Gotchas section)
- Run real `docsReviewed` invocation interactively to confirm Sonnet completes within 90s on representative prompts (we may be able to _lower_ `COMMIT_TIMEOUT` back to 90s post-cleanup; flag for verification).

**Bypass reason for the commit's own `docsReviewed` check:** see template at end of this RFC under § Bypass reason template.

### Phase 2: Unify the two check-types

1. Rename `docsFreshnessProject` to `docsReviewed` (or keep separate names, see open question 4) with shared context-build code path.

2. Refactor `adversarial-review.sh` to have one `case "$GIT_ROOT" in /devshop) ... ;; /workspace) ... ;; esac` block inside the `docsReviewed` arm, replacing the current two separate `case "$CHECK_TYPE"` arms.

3. Update `commit-guard.sh` (devshop) and `check-docs-coverage-project.sh` (project) to call the unified check-type.

4. Update `kit/docs/guide/hooks.md`'s § 2 bypass table to reflect the unified check-type names.

### Phase 3: Generalize the routing map

1. Extend `GUIDES_TO_INCLUDE` to cover project-side routes (when project grows a `guide/` directory or when ARCHITECTURE.md sections become large enough to warrant selective inlining).

2. Add a project-side equivalent: `PROJECT_GUIDES_TO_INCLUDE` (or unified map keyed off `$GIT_ROOT`).

3. Add `## ` headers flat-catalog inline for project-side too (currently absent).

### Phase 4: Doc structural templates + soft-enforcement

1. Author `kit/docs/guide/conventions.md § Doc Templates` defining structural conventions for guide/\* sections, per-package READMEs, etc.

2. Migrate existing docs to fit the templates (one PR per doc category).

3. Add reviewer rule (soft warning initially, promote to hard fail later) that AFFECTED-doc edits should fit the section's template.

### Phase 5: Tool-use grep for `dismissalLog`

1. Equip the `dismissalLog` reviewer with a `grep <pattern> <doc-path>` tool.

2. Add prompt instruction: "before passing a dismissal, verify the cited spec/doc claim by greping current state on disk."

3. Branch on `case "$CHECK_TYPE" in dismissalLog) <use tool-equipped path> ;; esac`. Commit-time check-types keep the no-tool fast path.

### Phase 6: Out-of-band coherence sweep

Separate roadmap item; described briefly in § 10 above.

---

## Phase 1 — ready-to-execute checklist

Concrete steps for a fresh session to execute Phase 1 without further design discussion:

1. **Read this RFC end to end.** Then read `/devshop/kit/scripts/adversarial-review.sh` end to end (currently ~620 lines; be aware lines may have shifted since 2026-05-01).

2. **Verify current state matches snapshot:**
   - `wc -c /devshop/CLAUDE.md` should still be ~30 KB (within 20% of 30,981).
   - `grep -n 'PROJECT_CLAUDE\|PROJECT_README' /devshop/kit/scripts/adversarial-review.sh` should show inlines in the `docsReviewed` case.
   - Static PROMPT block size: `awk 'NR>=525,/^FAIL: <what is wrong/' /devshop/kit/scripts/adversarial-review.sh | wc -c` should be ~12,200.

3. **Branch:** `git -C /devshop checkout -b feat/adversarial-review-doc-inlining-phase-1`.

4. **Make the edits per § Phase 1 above.** Order: prompt simplifications first (§ Phase 1 item 3) → rule 4(a) sharpening (item 2) → drop cross-repo (item 1) → FULL replace head-N (item 4). Each as a separate logical hunk.

5. **Run bats tests** after each hunk: `/devshop/kit/tests/lib/bats-core/bin/bats /devshop/kit/tests/util-adversarial-review*.bats`. Existing 23 tests must still pass.

6. **Add new bats cases per Phase 1 test plan.** Extend `util-adversarial-review-guides.bats`. Should grow to ~13-14 tests.

7. **Run a real `docsReviewed` interactively** to confirm Sonnet completes within the prior 90s budget on a representative commit:

   ```
   timeout 120 bash /devshop/kit/scripts/adversarial-review.sh docsReviewed "<test reason>" 2>&1
   ```

   Time the call. If <60s, **also lower `COMMIT_TIMEOUT` back to 90s** (it was 90 → 180 in `3694dc3`; cleanup may make 90 sufficient again). Watch for one cycle of real commits before locking the lower value.

8. **Commit.** Bypass reason template below. Use `DEVSHOP_ADVERSARIAL_MODEL_OVERRIDE=haiku` for the commit's own review IF Sonnet still times out post-cleanup; otherwise let Sonnet review.

9. **Push, ff-merge to main, push origin main.** Devshop has no PRs.

---

## Bypass reason template

For the Phase 1 commit's own `docsReviewed` check. Adapt as the actual diff lands.

```
Per-doc enumeration:
- /devshop/CLAUDE.md: NOT AFFECTED. (Reviewer-prompt cleanup is internal to adversarial-review.sh; doesn't change Claude's behavior in workspaces, gotchas, or env vars.)
- /devshop/kit/docs/MODEL.md: NOT AFFECTED. No conceptual model change.
- /devshop/kit/docs/OVERVIEW.md: NOT AFFECTED. No directory-tree or event-flow change.
- /devshop/kit/docs/guide/hooks.md: AFFECTED + UPDATED. Section: § 2 'Husky pre-commit (during git commit)' bypass table — updated to reflect rule 4(a) sharpening; § 'Convention adherence (CONVENTIONS_TO_INCLUDE inlining)' parallel subsection 'Guide-body inlining (GUIDES_TO_INCLUDE)' updated to mention rule 4(a) name-specific-edits requirement. Distinctive phrase to grep in diff: 'name the specific edit'.
- /devshop/kit/docs/guide/{workflow,conventions,security,ops,architecture}.md: NOT AFFECTED.
- /devshop/kit/docs/FAQ.md: NOT AFFECTED.

Cross-file coherence: hooks.md is the only reference doc staged. No cross-file claims to verify.

Rename/delete drift (rule 4(d)): no files renamed, moved, or deleted. Trivially satisfied.

Addition drift (rule 4(e)): no new structural units. Rule and prompt content modifications are documented inline within the existing § 'Convention adherence' / § 'Guide-body inlining' subsections. Trivially satisfied.

Cite the RFC: kit/notes/roadmap/adversarial-review-doc-inlining.md § Phase 1.
```

---

## Open issues to resolve before Phase 2

- Decide open question 1 (MODEL.md fold).
- Decide open question 4 (single check-type vs two-with-shared-code).
- Validate Phase 1's actual latency numbers with empirical Sonnet timings on a sample of real commits (target: median <60s; p95 <90s; lower `COMMIT_TIMEOUT` accordingly).
- Confirm there are no callers of the bypass-flag names we'd break — `git config --get devshop.docsReviewed` is read in `commit-guard.sh:139`. If we keep the flag name, no callers to update. If we rename to `docsReviewed{Devshop,Project}`, update `commit-guard.sh` and any docs that cite the flag.

## Files modified by this RFC's Phase 1

- `/devshop/kit/scripts/adversarial-review.sh` — context-build + prompt edits
- `/devshop/kit/docs/guide/hooks.md` — § 2 table (bypass key naming) + § Convention adherence subsection (rule 4(a) sharpened text mention)
- `/devshop/kit/tests/util-adversarial-review-guides.bats` — new bats cases per test plan

## Reference files (for fresh session orientation)

- This RFC: `/devshop/kit/notes/roadmap/adversarial-review-doc-inlining.md`
- The script: `/devshop/kit/scripts/adversarial-review.sh`
- The hook docs: `/devshop/kit/docs/guide/hooks.md` (§ 2 for the bypass table; § "Convention adherence (CONVENTIONS_TO_INCLUDE inlining)" / "Guide-body inlining (GUIDES_TO_INCLUDE)" for the parallel inlining-mechanism docs)
- Tests: `/devshop/kit/tests/util-adversarial-review.bats` + `/devshop/kit/tests/util-adversarial-review-guides.bats`
- Trigger: `/devshop/kit/scripts/commit-hooks/commit-guard.sh:139` (where `docsReviewed` is invoked) and `/devshop/kit/scripts/commit-hooks/check-docs-coverage-project.sh` (where `docsFreshnessProject` is invoked)
- Recent commits: `953e9a1` (rule 4(e) + GUIDES_TO_INCLUDE), `3694dc3` (timeout fix + project Tier 2/3 hierarchy + reviewer context extension)
