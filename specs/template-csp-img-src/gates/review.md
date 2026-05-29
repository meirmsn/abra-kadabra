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
