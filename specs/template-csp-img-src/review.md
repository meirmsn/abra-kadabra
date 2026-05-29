# Review — template-csp-img-src

## Audit 1: pre-polish (2026-05-28)

<!-- audited-at: dce3a27d23c314cf3dbb9c0546f530d0c74e0697 -->
<!-- range: b174a11..HEAD -->

findings: high=0 medium=1 low=0

> Range note: the orchestrator's default `origin/main..HEAD` was polluted — `origin/main` (1d343bf) advanced past this branch's merge-base (b174a11), so that direction surfaced 1d343bf's unrelated changes (the same commit responsible for the known pre-existing bats failure, filed in kit/TODOS.md) as phantom deletions. The audit was scoped to the true feature range `b174a11..HEAD` (merge-base..HEAD), isolating the 7 CSP-feature files.

### Docs findings

- [medium] commit 4d33ca1 (template/apps/web/next.config.ts) — template-touching commit carries no `**Existing projects:**` migration block. Low-stakes (comment-only header edit; template ships no CSP block, so nothing to migrate). The squash-surface hygiene reviewer (`/ak-merge-devshop` Phase 0.4.5) requires the block since the squash diff touches `template/**`; satisfy it there with the "no migration needed" variant.
- [low] kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 2 — adequacy VERIFIED (substantive: spread-IIFE computes origin once, emits both connect-src + img-src, load-bearing don't-delete comment). Informational, not a defect.
- [low] kit/docs/guide/{README,conventions,supabase-ssr-boilerplate}.md + template header — coherence VERIFIED (heading rename repointed everywhere; new anchor slug matches; zero stale old-anchor refs repo-wide). Informational, not a defect.

### Tests findings

- (none) — pure docs/boilerplate range; no executable surface (no kit/scripts, kit/hooks, or SKILL.md), no test files, no skip/only, no bypass trailers. The one `.ts` touched (template next.config.ts) is a comment-only JSDoc edit. Pattern 2 TS excerpt is illustrative markdown prose, not executable. Pre-existing bats failure in util-product-update-blurb.bats is from 1d343bf (origin/main, outside the feature range) — classified pre-existing/unrelated.

### Bypass trailer audit

- (none) — no Docs-Coverage-Bypass, Tests-Coverage-Bypass, or CLAUDE-MD-Bypass trailers in range.

---

## Audit 2: merge (2026-05-28)

<!-- audited-at: e20702708323b6346d2d32ec6a40e343ad81c4df -->
<!-- range: 1d343bf1d98b624fce5c15d30dba5af8ac03be53..e20702708323b6346d2d32ec6a40e343ad81c4df -->

findings: high=0 medium=1 low=2

> Phase 1.1 merge audit (`/ak-merge-devshop`). Range is the true feature delta: the branch was merged onto `origin/main` (1d343bf), so `1d343bf..e207027` isolates the 7 CSP-feature source files (BUILD-LOG.md, PLAN.md, kit/ROADMAP.md, kit/docs/guide/{README,conventions,supabase-ssr-boilerplate}.md, template/apps/web/next.config.ts) plus the spec/ audit scaffolding. The merge commit e207027 brings in no foreign source/test files. The single medium is the **already-resolved** propagation-block carried over from Audit 1 — resolved in the squash body per spec D4, not a new finding.

### Docs findings

- [medium] template/apps/web/next.config.ts — diff touches `template/**` but no per-commit body carries an `**Existing projects:**` migration block. **ALREADY RESOLVED** (carryover from Audit 1, not new): the block lives in the `/ak-merge-devshop` squash commit body (composed + operator-approved), the correct resolution per spec Decision D4. Phase 0.4.5's squash-surface hygiene reviewer is the surface that enforces and satisfies it. Re-surfaced only because the docs reviewer re-runs the same template-touch heuristic; no action required.
- [low] kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 2 — coverage + adequacy VERIFIED. Heading rename, `**Why:**` Storage/http-origin prose extension, spread-IIFE refactor (one trimmed `supabaseUrl` reused across `connect-src` + `img-src`), and load-bearing "do NOT delete it as redundant" inline comment all present + self-coherent. Informational, not a defect.
- [low] kit/docs/guide/{README,conventions}.md + bookkeeping — coherence VERIFIED. README routing-index row repointed to the new anchor with updated trigger/summary; conventions.md `### CSP` sub-section + matching `[CSP](#csp)` TOC entry placed correctly; no stale old-anchor refs repo-wide. Tracker closure correct per § Closing TODO/ROADMAP entries when a fix ships (BUILD-LOG entry added, PLAN row removed, ROADMAP v0 entry deleted). Informational, not a defect.

### Tests findings

- (none) — pure docs/boilerplate range; no executable surface (zero kit/scripts, kit/hooks, SKILL.md, *.bats, *.test.*, *.spec.* in the diff). The one `.ts` touched (template next.config.ts) is a comment-only JSDoc header edit. Pattern 2 TS excerpt is illustrative markdown prose, not executable. Merge commit e207027 brings no foreign code/test files. Pre-existing bats failure (from 1d343bf on origin/main) is outside feature authorship, filed in kit/TODOS.md — pre-existing/unrelated, not a regression.

### Bypass trailer audit

- (none) — no Docs-Coverage-Bypass, Tests-Coverage-Bypass, CLAUDE-MD-Bypass, or Hygiene-Override trailers in range.

---

## Gate-by-gate results

_Devshop gate set: 6 dispatched + 13 pre-composed carve-outs. Gate 5 (docs-and-tests-review) is the `## Audit 1` section above._

## Gate 1: docs-check
- Result: pass

Verified the docs change is self-coherent and matches spec scope (D1–D4). This is a docs/boilerplate change; every behavior change IS a doc update, all in this diff.

- **No dangling cross-references.** `grep` for the OLD anchor `pattern-2-csp-connect-src-builder-handles-both-httpswss-and-httpws` across all `*.md` returns ZERO hits — fully retired. The NEW anchor `pattern-2-csp-connect-src-and-img-src-builders-derive-from-the-supabase-origin` appears in exactly two places, both correct: the boilerplate's own `## Contents` TOC (line 10) and the README.md routing-index row (line 70). Old prose ("connect-src ... builder handles BOTH", "handles BOTH https...") returns zero hits anywhere (md + ts).
- **New anchor matches the heading slug.** Heading `## Pattern 2: CSP \`connect-src\` and \`img-src\` builders derive from the Supabase origin` (line 113) → GitHub-slugifies (lowercase, drop backticks + colon, spaces→hyphens) to `pattern-2-csp-connect-src-and-img-src-builders-derive-from-the-supabase-origin`. Exact match to both references.
- **New `### CSP` sub-section reachable from conventions.md TOC.** TOC entry `[CSP](#csp)` at line 56 → `### CSP` heading at line 726. Slug `csp` matches. Placed correctly between `### Responsive + Theme` (718) and `### PWA` (731), per D3 / spec § Gotchas.
- **README.md routing-index row points at the correct new anchor** (line 70) and updates the trigger column (adds `"img-src"`, "Supabase Storage images") + summary ("Both derive from `$NEXT_PUBLIC_SUPABASE_URL`") to cover the new img-src case. Matches spec D3 + README routing intent.
- **Scope match vs spec.md.** All four In-scope items present: (1) Pattern 2 IIFE now computes one trimmed `supabaseUrl`, spreads `connect-src` + `img-src` from it, old standalone `"img-src 'self' data: blob:"` line removed (grep confirms gone); (2) D2 load-bearing inline block-comment present; (3) `**Why:**` prose extended for the img-src/Storage case; (4) new `### CSP` convention sub-section; (5) template `next.config.ts` `// Does NOT:` header updated to "`connect-src` + `img-src` builders". No out-of-scope additions (no media-src in the snippet, no actual CSP block added to template).

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

## Gate 2d: fast-job-local (bats)

- Result: pass-with-note

Ran `bats kit/tests/` at HEAD. 1526 tests planned, **1525 pass / 1 fail**.

The single failure — test 1247 "Phase 6 audit comment posts concise summary
(no quality-gates table)" in `util-build-phase58-audit-parser.bats` — is
**pre-existing on /devshop main and unrelated to this diff**. Caused by
commit `1d343bf` ("drop PR gate comment"), which changed project-mode Phase 6
to post no comment but left this test asserting the removed wording. The test
reads the canonical `/devshop/.claude/skills/devshop/build/SKILL.md` path, so
it reflects main's state regardless of branch. This diff touches no test, no
script, no SKILL.md — confirmed via `git diff origin/main...HEAD --name-only`.

Filed for a dedicated test-only fix in `kit/TODOS.md` on branch
`chore/file-phase6-audit-test-stale` (commit `4d42af6`). Operator acknowledged
and chose to proceed.

## Dismissals

- test 1247 (Phase 6 audit-comment): dismissed as pre-existing/unrelated.
  rationale: introduced by 1d343bf (not on this branch); this diff touches no
  test/script/SKILL; filed in kit/TODOS.md for a separate fix.

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

- Result: pass

Scope: the only executable code in `git diff origin/main...HEAD` is the CSP-builder
snippet in `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 2`. Everything else
in the diff is markdown prose, a `template/apps/web/next.config.ts` header-comment
edit, and spec/tasks tracking files — no code to simplify there.

Judged the refactor of the inline IIFE from `((): string => ...)()` (single
`connect-src` string) to `...((): string[] => ...)()` (array-spread returning
`connect-src` + `img-src`):

- **Reuse:** Correct and minimal. `supabaseUrl` is computed once (with the Pattern 1
  `.trim()` landing once) and consumed by both directives; `supabaseWs` is derived
  once and used once. No duplicated env reads, no duplicated trim, no dead bindings.
  This is exactly the DRY goal the change states ("origin stays in lockstep").

- **Array-spread vs. const-lift:** Considered hoisting `supabaseUrl`/`supabaseWs`
  above the headers object and referencing them in two plain string entries (dropping
  the IIFE). Rejected as worse for this artifact: the snippet is a paste-in *fragment*
  of a `headers()` return value's `value: [...]` literal with no enclosing scope shown.
  A const-lift would force the bindings into an outer scope the excerpt doesn't depict,
  splitting the env-derivation away from the directives that use it and making the
  copy-paste boilerplate harder to drop in. The spread-of-IIFE keeps derivation and
  consumption co-located — the right shape here. Spread-of-IIFE is idiomatic TS for
  "emit N related array entries from shared local state," not over-clever.

- **Clarity / over-cleverness:** None found. The regex `^http(s?):\/\/` → `ws$1://`
  is unchanged from origin/main (pre-existing, already-reviewed). Comments are
  load-bearing (explain why the appended `${supabaseUrl}` on `img-src` is not
  redundant) and accurate; not noise.

Snippet is already clean — no fix recommended.

## Dismissals

None

## Gate 6: /review
- Result: pass

<evidence>

Ran the /review critical pass + adversarial lens against `git diff origin/main...HEAD`
in devshop self-mode (read-only — telemetry/config/AskUserQuestion ceremony and
fix-first behavior skipped per gate contract). Diff is docs/boilerplate, ~30 changed
lines across 5 files (PLAN.md, kit/docs/guide/README.md, conventions.md,
supabase-ssr-boilerplate.md, template/apps/web/next.config.ts). Specialist dispatch
auto-skips (DIFF_LINES < 50). The only "code" is the Pattern 2 CSP-builder snippet.

### Scope check: CLEAN
- Intent (spec D1–D4): fold an `img-src` Supabase-origin derivation into the Pattern 2
  IIFE; add a `### CSP` convention sub-section; touch up the template `// Does NOT:`
  pointer. Propagation handled in the squash body, not as a code task.
- Delivered: exactly those three edits, plus the consequent README routing-table +
  Contents-anchor + PLAN.md row text updates (anchor/heading renamed Pattern 2 →
  "connect-src and img-src builders"). No out-of-scope changes, no missing requirements.

### Security review (the gate's primary scrutiny questions)

1. Does appending `${supabaseUrl}` to `img-src` widen the policy via an
   attacker-controlled env var? NO.
   - `NEXT_PUBLIC_SUPABASE_URL` is an operator-set build/server env var, not
     user-controlled input. Same trust posture as the PRE-EXISTING `connect-src` use
     of the identical var (the old IIFE already inlined `${supabaseUrl}` +
     `${supabaseWs}`). This change introduces no new trust boundary.
   - An adversary who could control that var could already poison `connect-src`
     (REST + WebSocket — a strictly stronger primitive than `img-src`). So `img-src`
     adds no incremental blast radius.
   - The token is a bare origin (host-source), so it permits exactly the one Supabase
     origin across all paths — correct for Storage objects, no over-broadening.

2. Is the no-`https:` base reasoning sound? YES.
   - CSP scheme matching is strict: a `https:` scheme-source matches only `https://`
     origins, never `http://host.docker.internal:<port>` / `http://127.0.0.1:<port>`.
     The canonical base (`'self' data: blob:`) carries no `https:` token, so the
     appended bare `${supabaseUrl}` is genuinely the ONLY token covering BOTH the dev
     `http` local-stack origin AND the prod `https` Supabase origin. The block-comment's
     "load-bearing / do not delete as redundant" claim is accurate under this base, and
     the parenthetical caveat (if a project's base carries a broad `https:` token, only
     the dev `http` origin is new behavior) is also correct.

### Correctness / structural review
- Array-spread restructure is sound: `...((): string[] => {...})()` spreads two strings
  into the surrounding `value: [...]` array, later `.join('; ')`'d into the header. The
  old single-element `((): string => ...)()` form and the standalone
  `"img-src 'self' data: blob:"` line are BOTH removed in the diff — no duplicate
  `img-src` directive results. Verified against the post-edit block
  (supabase-ssr-boilerplate.md:124-156).
- `.trim()` whitespace defense (lalista PR 26 `%0A`-injection guard) is preserved and
  now computed ONCE and reused for both directives — an improvement over duplicating the
  read; removes drift risk between the two directives' origins.
- Empty-env edge case (`NEXT_PUBLIC_SUPABASE_URL` unset → trailing space in the
  directive value) is pre-existing `connect-src` behavior, harmless (CSP tokens are
  whitespace-split), and not introduced by this diff. Not a finding.

### Prose / mislead-an-implementer review
- Pattern 2 `**Why:**` extension, the `### CSP` convention sub-section
  (conventions.md:726-730), the README routing-table row, and the template
  `// Does NOT:` pointer are all factually accurate and mutually consistent. No claim
  would mislead an implementer copying the boilerplate. `media-src` is correctly scoped
  as conditional ("only if you serve Storage video") in the convention note and
  correctly OMITTED from the canonical snippet (avoids cargo-culting an unused directive).
- README anchor was updated in lockstep with the renamed heading
  (`#pattern-2-csp-connect-src-and-img-src-builders-derive-from-the-supabase-origin`) —
  no broken intra-doc link.

### Tests
- No executable surface (fenced markdown excerpt; comment-only template touch-up). No
  bats test asserts Pattern 2's directive text, so the edit changes no test outcome —
  consistent with spec § Tests. Not a finding.

### Adversarial pass (Claude, self): no additional issues
Edge cases / failure modes / silent-corruption paths considered — attacker-controlled
env var (ruled out: operator-set, weaker than existing connect-src use), duplicate
directive (ruled out: old line removed), scheme-match gap (the fix's whole point),
whitespace injection (trim preserved). Nothing found.

## Dismissals
None
</evidence>

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; this diff is docs/boilerplate only. Security boundary is the pre-commit hook gauntlet itself.)

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

- Result: pass

<evidence>

Scope: changed docs/config in `git diff origin/main...HEAD` — `kit/docs/guide/README.md`, `kit/docs/guide/conventions.md`, `kit/docs/guide/supabase-ssr-boilerplate.md`, `template/apps/web/next.config.ts`. (Non-checked changes: `PLAN.md`, `specs/template-csp-img-src/*` — bookkeeping, out of convention-gate scope.)

n/a items (no matching files in diff):
- SKILL.md frontmatter — no SKILL.md changed.
- Shell-script structure — no `kit/scripts/**` / hooks changed.
- Bats test files for new scripts — no new scripts.

**Anchor slug — heading renamed, all three references agree.** Pattern 2 heading is now `## Pattern 2: CSP `connect-src` and `img-src` builders derive from the Supabase origin`. GitHub slug derives to `pattern-2-csp-connect-src-and-img-src-builders-derive-from-the-supabase-origin` (verified against the GitHub slug algorithm: lowercase, strip backticks/colon, spaces→hyphens). Both pointers match exactly:
- in-file TOC (`supabase-ssr-boilerplate.md:10`): `…#pattern-2-csp-connect-src-and-img-src-builders-derive-from-the-supabase-origin`
- README routing row (`README.md:70`): same anchor.
- Heading (`supabase-ssr-boilerplate.md:113`): produces that slug.
No stale `#pattern-2-csp-connect-src-builder-handles-both-httpswss-and-httpws` references remain (grep clean).

**Routing index — correct placement, no new row needed.** The CSP `next.config.ts`-edit routing row already exists (README.md:70, the Pattern 2 row) and was correctly updated to add the `"img-src"` / Supabase-Storage-images keyword triggers and the new anchor. The `### CSP` sub-section in conventions.md does NOT need its own README routing row: README treats conventions.md as a whole-doc entry (README.md:129) and maintains no per-`###` rows for its sibling sub-sections (`### Responsive + Theme`, `### PWA`, `### Code Structure` all lack README rows). The `### CSP` sub-section is correctly discoverable via conventions.md's own `## Contents` TOC: entry present at conventions.md:56 (`- [CSP](#csp)`), anchor `#csp` matches `### CSP` (conventions.md:728).

**conventions.md § CSP prose follows sibling bold-led-bullet style.** Both bullets use the `- **Bold lead** — prose` shape of `### Responsive + Theme` / `### PWA`: `- **Every CSP directive that must reach Supabase derives from `$NEXT_PUBLIC_SUPABASE_URL`** — …` and `- **A `https:` token alone is insufficient** — …`. Cross-ref to `§ Pattern 2` present and resolves.

**next.config.ts header preserves // What / // Why / // Does NOT shape.** All three header tags intact (lines 1, 3, 8). Touch-up confined to the `// Does NOT:` block: `the Pattern 2 `connect-src` builder` → `the Pattern 2 `connect-src` + `img-src` builders`; the `§ Pattern 2` pointer unchanged and still resolves. No functional change.

**Pattern 2 body / TOC consistency.** Supabase boilerplate `## Contents` TOC line (supabase-ssr-boilerplate.md:10) matches the renamed heading text verbatim; `**Why:**` prose extended for the img-src case in sibling-consistent style.

</evidence>

## Dismissals

None

---

## Phase 3 → 4 advance log

### 2026-05-29T05:18:29Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs (docs-only diff)
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T05:18:29Z -->

### 2026-05-29T05:18:29Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T05:18:29Z -->

### 2026-05-29T05:18:29Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants run in Gate 2d
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T05:18:29Z -->

### 2026-05-29T05:18:29Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T05:18:29Z -->

